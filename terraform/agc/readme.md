# Application Gateway for Containers (BYO) with an Existing AKS Cluster

Terraform (`azapi` provider) builds the Azure side. Helm installs the ALB Controller. You write your own Gateway and HTTPRoute, and a Tomcat pod is used as the test application.

---

## 1. What "BYO" means here

In **BYO (Bring Your Own)**, you create the Application Gateway for Containers (AGC) yourself, and the ALB Controller in the cluster only *connects* to it.

| Layer | Tool | Responsibility |
|---|---|---|
| Azure resources | Terraform with the `azapi` provider | Resource group, delegated subnet, AGC, frontend, subnet association, managed identity, role assignments, federated credential |
| Controller | Helm (run from the CLI, not from Terraform) | Installs the ALB Controller in namespace `azure-alb-system` |
| Kubernetes objects | `kubectl` | Test application, your own Gateway, your own HTTPRoute |

Because the AGC already exists, you **do not create** the `ApplicationLoadBalancer` custom resource. That resource belongs to the managed model (see section 7).

Assumption: the AKS cluster already exists, with the **OIDC issuer** and **workload identity** enabled.

---

## 2. Connection flow

**Traffic flow (what users hit):**

1. A client calls the public **frontend FQDN** of the AGC.
2. The AGC data plane, which lives in the dedicated **delegated subnet**, receives the request.
3. AGC matches the request against the routing rules and forwards it **directly to pod IPs** in the AKS network. It does not go through the node or the controller.
4. The Tomcat pod answers.

**Configuration flow (how routing rules reach the AGC):**

1. You apply the Gateway and HTTPRoute with `kubectl`.
2. The ALB Controller sees them and decides which AGC to program, based on the Gateway annotation and address.
3. The controller's Kubernetes service account token is exchanged through **workload identity federation** for an Azure token, acting as the user-assigned managed identity (UAMI).
4. Using that identity, the controller calls Azure and writes the listeners, routes, and backends into the AGC.

Key point: user traffic never passes through the controller. The controller only handles configuration, so if it breaks, existing routing keeps working, but changes stop being applied.

---

## 3. Names and values that must match

Most problems in this setup come from a name that does not line up. Keep this table next to you.

| Where it is defined | Where it must be used | Notes |
|---|---|---|
| AGC resource ID (Terraform output) | Gateway annotation `alb.networking.azure.io/alb-id` | Full resource ID, not the name |
| Frontend name (Terraform), for example `fe-tomcat` | Gateway `spec.addresses` value | Name only, case-sensitive, not the FQDN |
| UAMI **client ID** (Terraform output) | Helm value `albController.podIdentity.clientID` | Client ID, not the principal/object ID |
| `azure-alb-system` namespace and `alb-controller-sa` service account | Federated credential subject: `system:serviceaccount:azure-alb-system:alb-controller-sa` | Must match exactly |
| AKS OIDC issuer URL | Federated credential issuer | Read from the cluster |
| GatewayClass `azure-alb-external` | Gateway `spec.gatewayClassName` | Must exist and be accepted |
| Gateway name and namespace | HTTPRoute `parentRefs` | HTTPRoute must be in the same namespace unless allowed otherwise |
| Service name and port | HTTPRoute `backendRefs` | Service port, not the container port |
| Listener `hostname` (if set) | HTTPRoute `hostnames` and the `Host` header used in tests | A mismatch makes requests fail to match |

Note: use your own real names consistently. In this project the AGC is `agc-byo` in resource group `rg-agc-byo`, the frontend is `fe-tomcat`, and the application runs in a namespace you choose (for example `tomcat-app`). The Gateway, HTTPRoute, Service, and Deployment must all be in that same namespace.

---

## 4. Access requirements

### 4.1 Person or pipeline running Terraform

| Scope | Role | Why |
|---|---|---|
| Subscription or target resource groups | Contributor | Create the resource group, AGC, frontend, association, identity |
| Same scope | User Access Administrator or Role Based Access Control Administrator | Terraform creates role assignments, which Contributor alone cannot do |
| AKS VNet | Subnet write permission (included in Contributor) | Add the delegated AGC subnet |
| AKS cluster | Cluster User role, plus rights inside the cluster | Fetch kubeconfig, install Helm charts, create namespaces |

### 4.2 UAMI used by the ALB Controller

| Role | Scope | Why it is needed |
|---|---|---|
| AppGw for Containers Configuration Manager | AGC resource group | Read and write AGC configuration: listeners, routes, backends |
| Network Contributor | AGC subnet | Permission to join the delegated subnet, needed for the association |
| Reader | AKS node resource group (`MC_*`) | Discover the cluster networking so backends can be programmed |

### 4.3 Why a UAMI is needed

- The controller is just a pod, and a pod has no Azure identity by default. To change the AGC it must call Azure APIs as an identity with the right permissions.
- A user-assigned managed identity has **no secret** to store, rotate, or leak.
- **Workload identity federation** lets Microsoft Entra ID trust the cluster's OIDC issuer, so the controller's service account can exchange its token for an Azure token as the UAMI.
- A user-assigned identity can be created and given roles **before** the controller exists, which fits Terraform ordering and survives controller reinstalls.
- Least privilege: the identity can only touch the AGC resource group, the AGC subnet, and read the node resource group.

Without it, the Gateway never becomes `Programmed`, and the controller logs show 403 or token errors.

---

## 5. Prerequisites

- Azure CLI, Terraform, Helm 3.8 or later, kubectl.
- AKS with OIDC issuer and workload identity enabled. If not, enable both with `az aks update`.
- Free address space in the AKS VNet for a **/24 or larger** subnet used by nothing else.
- Resource providers registered: `Microsoft.ServiceNetworking`, `Microsoft.ContainerService`, `Microsoft.Network`, `Microsoft.ManagedIdentity`.
- Test container image that matches the **CPU architecture of your nodes** (see section 9, issue 6).

---

## 6. Step-by-step: configure AGC with AKS

### Step 1: Log in
Sign in with the Azure CLI and select the subscription that holds the AKS cluster.

### Step 2: Read the existing AKS cluster in Terraform
Use the `azapi` data lookup for the managed cluster. You need two values from it: the **OIDC issuer URL** (for the federated credential) and the **node resource group name** (for the Reader role).

### Step 3: Create the AGC resources with Terraform (`azapi_resource`)
Create these resources, in this order of dependency:

| Resource type | Purpose | Point to take care of |
|---|---|---|
| Resource group | Holds the AGC and identity | Keep separate from the node resource group |
| Subnet (inside the AKS VNet) | Dedicated AGC subnet | Delegate to `Microsoft.ServiceNetworking/trafficControllers`, /24 or larger, nothing else inside, different from the node subnet |
| `trafficControllers` | The AGC itself | Its resource ID becomes the `alb-id` annotation |
| `trafficControllers/frontends` | Gives the public FQDN | Its name becomes the Gateway `addresses` value |
| `trafficControllers/associations` | Links the AGC to the subnet | Association type `subnets`. One subnet can belong to only one AGC |

### Step 4: Create the identity, roles, and federation with Terraform
1. Create the user-assigned managed identity.
2. Assign the three roles from section 4.2 at the right scopes. Role assignment names must be GUIDs.
3. Create the federated credential with: the AKS OIDC issuer, audience `api://AzureADTokenExchange`, and subject `system:serviceaccount:azure-alb-system:alb-controller-sa`.
4. Export these outputs: AGC resource ID, frontend name, frontend FQDN, and UAMI client ID.

### Step 5: Apply Terraform and wait
Run init, plan, and apply. Then **wait a few minutes**. Role assignments and the federated credential take time to propagate, and installing the controller too early causes 403 errors.

### Step 6: Connect to the cluster
Fetch credentials with `az aks get-credentials` and confirm the nodes are visible.

### Step 7: Install the ALB Controller with Helm (CLI, not in Terraform)
Install the chart `alb-controller` from the Microsoft Container Registry OCI location with these settings:

| Setting | Value |
|---|---|
| Release name | `alb-controller` |
| Namespace | `azure-alb-system` (create it) |
| Chart version | A pinned, current stable version (check the latest release; do not leave it floating) |
| `albController.namespace` | `azure-alb-system` |
| `albController.podIdentity.clientID` | UAMI **client ID** from Terraform |

Use `helm upgrade --install` so the same command works for installs and updates.

### Step 8: Verify the controller
- Two pods in `azure-alb-system` should be `Running` and `1/1`: the controller and the bootstrap pod.
- `kubectl get gatewayclass` should list `azure-alb-external` with `ACCEPTED = True`.

### Step 9: Deploy the test application
Create a namespace, a Deployment for Tomcat, and a Service. Take care with:
- The Service port (what the HTTPRoute references) versus the container port (8080).
- The official Tomcat image has an empty `webapps` folder, so `/` returns 404 unless the default apps are copied in at startup.
- A readiness probe is needed, because AGC only routes to **Ready** pods.
- The image must match the node CPU architecture.

### Step 10: Create your Gateway and HTTPRoute
Details of each field are in section 7. In short:
- The Gateway carries the AGC ID annotation, the frontend address, the GatewayClass, and a listener.
- The HTTPRoute references the Gateway in `parentRefs` and the Service in `backendRefs`.
- The Gateway file holds a placeholder for the AGC ID. Replace it with the Terraform output before applying (either by editing the file or by substituting it at apply time). The ID cannot be known before Terraform creates the AGC, which is the only reason for the substitution.

### Step 11: Verify and test
Follow section 8.

---

## 7. Annotations and Gateway fields explained

| Field | What it does | Value in this setup |
|---|---|---|
| `alb.networking.azure.io/alb-id` (annotation) | Tells the controller **which AGC** to program | Full resource ID of the Terraform-created AGC |
| `spec.addresses` with type `alb.networking.azure.io/alb-frontend` | Tells the controller **which frontend inside that AGC** to attach the listener to | The frontend name, for example `fe-tomcat` |
| `spec.gatewayClassName` | Selects the controller that handles this Gateway | `azure-alb-external` |
| `spec.listeners` | Port, protocol, and optional hostname that AGC listens on | HTTP on port 80 for the test |
| `listeners[].hostname` | If set, only requests with a matching `Host` header match | Leave out for simple testing, or send the same `Host` header in your tests |
| `listeners[].allowedRoutes` | Which namespaces may attach routes | `Same` namespace only |

How they work together: the annotation picks the AGC, and the address picks the frontend. The Gateway ends up bound to AGC then frontend, and the **frontend's FQDN** is what you call.

### Annotations that must NOT be used in BYO

| Annotation | Belongs to | Why it is wrong here |
|---|---|---|
| `alb.networking.azure.io/alb-namespace` | Managed model | Points to an `ApplicationLoadBalancer` resource that does not exist in BYO |
| `alb.networking.azure.io/alb-name` | Managed model | Same reason |

If these are present, the Gateway status shows a message that the `ApplicationLoadBalancer` resource was not found, and the Gateway is never programmed.

### BYO versus managed

| | BYO (this guide) | Managed |
|---|---|---|
| Who creates the AGC | Terraform | The ALB Controller, from the `ApplicationLoadBalancer` resource |
| Gateway annotations | `alb-id` plus the frontend address | `alb-namespace` plus `alb-name` |
| `ApplicationLoadBalancer` resource | Not created | Required |
| Config Manager role scope for the UAMI | AGC resource group | AKS node resource group |
| Subnet | The Terraform subnet and association | A separate delegated subnet, association made by the controller |

### What happens if you create an `ApplicationLoadBalancer` and attach the Gateway to it
You switch to the managed model, and with this setup it will most likely fail:
1. The controller creates a **second AGC**, and your Terraform AGC sits unused but still costs money.
2. The delegated subnet is **already associated** with the Terraform AGC. One subnet can serve only one AGC, so you would need a second delegated subnet.
3. The UAMI has Config Manager only on the AGC resource group, so the controller would hit authorization errors on the node resource group.
4. Terraform no longer owns the AGC, which defeats the point of infrastructure as code.

Only switch deliberately. If you do, remove the Terraform AGC and association and move the Config Manager role to the node resource group.

---

## 8. Testing the HTTPRoute paths

1. **Check route status.** The HTTPRoute should show `Accepted=True` and `ResolvedRefs=True`. A `False` message names the problem, such as a wrong Service name, port, or namespace.
2. **Get the FQDN.** Either from Terraform's frontend FQDN output, from the Azure frontend, or from the Gateway status addresses. The Gateway address is empty until the Gateway is `Programmed=True`.
3. **Call the paths with curl.** Tomcat's default apps give real paths: `/`, `/docs/`, `/examples/`, and a sample servlet under `/examples/`. Use a trailing slash on `/docs/` and `/examples/`, otherwise Tomcat answers with a 302 redirect (normal Tomcat behavior).
4. **If the listener has a hostname**, send that value in the `Host` header, otherwise nothing matches.
5. **Run a negative test**, such as `/nope` or a path outside your route, to prove the match rules do the work.

How to read the result:

| Response | Meaning |
|---|---|
| 200 from Tomcat | Route matched, traffic reached the pod |
| 404 with a Tomcat-styled error page | AGC routed correctly, but Tomcat has no app at that path |
| 404 with an empty or plain body from AGC | No route matched. Check path match type and hostnames |
| 502 or 503 | Route matched, but the Service has no ready endpoints or AGC cannot reach the pod IPs |

Custom prefixes: if the route matches `/app`, the request reaches Tomcat still as `/app/...`, and Tomcat has no such context, so it returns its own 404. Either deploy the application under that context path, or add a **URLRewrite** filter with a `ReplacePrefixMatch` to `/` so the prefix is stripped.

To watch requests arrive, follow the pod logs in one terminal and run curl in another. Use `--tail=0` to show only new lines. Press `Ctrl + C` to leave `kubectl logs -f`. It only stops the stream and does not affect the pod. Without `-f`, use `--tail` or `--since` and the command returns immediately.

---

## 9. Troubleshooting (issues we hit and how they were solved)

### Issue 1: Gateway says `ApplicationLoadBalancer resource "alb-infra/alb-test" ... was not found`
- **Cause:** the Gateway was first created with the managed annotations (`alb-namespace`, `alb-name`).
- **Fix:** remove them. Use only `alb-id` plus the `addresses` frontend name. Check that no stray `ApplicationLoadBalancer` exists with `kubectl get applicationloadbalancer -A`, and delete any left over from testing.

### Issue 2: Gateway status looks stale (`observedGeneration` is lower than `metadata.generation`)
- **Meaning:** you corrected the Gateway (generation moved on), but the status still shows the controller's result from the old version. The old error message no longer applies.
- **Cause:** the controller is not reconciling, because it is down, crashing, or failing with authorization errors.
- **Fix:** check the controller pods and logs, restart the controller deployment, and if it stays stale, delete and re-apply the Gateway so it starts fresh at generation 1.

### Issue 3: Gateway shows "Waiting for controller"
- **Meaning:** no controller has claimed the Gateway yet.
- **Checks, in order:**
  1. Are the two pods in `azure-alb-system` running and `1/1`?
  2. Does `kubectl get gatewayclass` list `azure-alb-external` as accepted?
  3. Does `helm list -n azure-alb-system` show the release as deployed?
  4. Does the Gateway's `gatewayClassName` match the class exactly?
- **Common mistake:** pasting `kubectl delete gateway ...` and `kubectl apply ...` on one line. Kubectl then treats extra words as object names. Run them as separate commands.

### Issue 4: Controller logs show errors

| Log message | Cause | Fix |
|---|---|---|
| `AuthorizationFailed` or 403 | A UAMI role is missing, or has not propagated | Confirm all three role assignments and scopes, wait, restart the controller |
| `AADSTS70021` or no matching federated identity | Federated credential subject or issuer is wrong | Subject must be exactly `system:serviceaccount:azure-alb-system:alb-controller-sa`, issuer must be the AKS OIDC URL |
| Token or workload identity errors | Workload identity is not enabled on AKS | Enable OIDC issuer and workload identity on the cluster |
| `ImagePullBackOff` on controller pods | Nodes cannot reach `mcr.microsoft.com` | Check outbound access, firewall, and routes |
| Wrong identity used | Object (principal) ID used instead of client ID in Helm | Use the **client ID** |

### Issue 5: Gateway not `Programmed`, but the controller is healthy
- Wrong AGC ID in the annotation.
- Frontend name in `addresses` does not match the Azure frontend (case-sensitive). List the frontends of the AGC to confirm the real name.
- A "resource update is pending" message for a minute or two is normal while AGC applies configuration.

### Issue 6: Pod fails with `exec /bin/sh: exec format error`
- **Meaning:** the image CPU architecture does not match the node architecture.
- **Typical cause:** the image was pulled on an Apple Silicon Mac (which defaults to arm64), re-tagged, and pushed to the registry, while the AKS nodes are amd64.
- **Diagnose:** list nodes with the architecture label, and inspect the image manifest in the registry for its platforms.
- **Fix, in order of preference:**
  1. Import the official multi-architecture image **directly into the registry on the server side** (`az acr import` with `--force` to overwrite the bad tag). This keeps all architectures and bypasses your laptop.
  2. Pull or build explicitly for the node platform (`linux/amd64`, or `linux/arm64` for ARM node pools) before pushing.
  3. For a quick test, use the public multi-architecture Tomcat image straight from the public registry.
- Set the image pull policy to `Always` so a cached wrong-architecture image is not reused, and pin the pod to the right architecture with a node selector if the cluster has mixed pools. If you get `ImagePullBackOff`, attach the registry to AKS.

### Issue 7: Cannot find the FQDN
- Gateway status addresses, but only after the Gateway is programmed.
- The AGC frontend in Azure (its FQDN property).
- The Terraform frontend FQDN output.

### Issue 8: Request returns 404, 502, or 503
See the table in section 8. A Tomcat-styled 404 means routing works. A plain 404 from AGC means no route matched. 502 or 503 means no ready endpoints: check the Service endpoints, the readiness probe, and network reachability from the AGC subnet to the pod network.

### Issue 9: Requests do not match when the listener has a hostname
Send the same hostname in the `Host` header, or remove the hostname from the listener for simple testing. If the HTTPRoute also has hostnames, they must be compatible with the listener's hostname.

### Other Terraform-side notes
- `PrincipalNotFound` right after creating the identity is an Entra replication delay. Re-run apply.
- The subnet must be delegated, /24 or larger, and unused by other resources. It must differ from the node subnet.
- Pin the `azapi` provider to a major version and check for a newer GA API version for `Microsoft.ServiceNetworking` before relying on the one in your code.

---

## 10. Cleanup (order matters)

1. Delete the HTTPRoute, Gateway, and test application first, so the controller stops reconciling.
2. Uninstall the Helm release and delete the `azure-alb-system` namespace.
3. Run Terraform destroy last.

Deleting the Azure resources before the Kubernetes objects leaves the controller retrying against resources that no longer exist.

---

## 11. Quick reference

| Item | Value |
|---|---|
| GatewayClass | `azure-alb-external` |
| Controller namespace | `azure-alb-system` |
| Controller service account | `alb-controller-sa` |
| Gateway annotation (BYO) | `alb.networking.azure.io/alb-id` with the AGC resource ID |
| Gateway address type | `alb.networking.azure.io/alb-frontend` with the frontend name |
| Annotations to avoid in BYO | `alb.networking.azure.io/alb-namespace`, `alb.networking.azure.io/alb-name` |
| Subnet delegation | `Microsoft.ServiceNetworking/trafficControllers` |
| Minimum subnet size | /24 |
| Federated credential audience | `api://AzureADTokenExchange` |
| UAMI roles | Configuration Manager (AGC RG), Network Contributor (AGC subnet), Reader (node RG) |