#!/bin/bash
set -e
echo "creating user...."
useradd -ms /bin/bash azureuser && \
echo "azureuser ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
passwd -d azureuser 
su - azureuser
sudo mkdir /azagent && cd /azagent

# Download Azure Pipelines agent
echo "downloading package....."
sudo curl -LsS https://download.agent.dev.azure.com/agent/4.259.0/vsts-agent-linux-x64-4.259.0.tar.gz -o agent.tar.gz

#changing the user permissions
sudo chown -R $(whoami):$(whoami) . &&  chmod -R u+rwX .
tar -xzf agent.tar.gz && sudo rm agent.tar.gz

#install dependencies
echo "install dependencies"
sudo ./bin/installdependencies.sh

chmod +x ./config.sh ./run.sh ./env.sh ./bin/Agent.Listener

# Variables (replace with Key Vault/secure injection in production)
AZP_URL="https://dev.azure.com/parshchakurkar"
AZP_TOKEN="your token here"
AZP_POOL="Default"
AZP_AGENT_NAME=linuxagent

# Configure agent
./config.sh --unattended \
  --url "$AZP_URL" \
  --auth pat \
  --token "$AZP_TOKEN" \
  --pool "$AZP_POOL" \
  --agent "$AZP_AGENT_NAME" \
  --acceptTeeEula \
  --replace

# Install and start as service
sudo ./svc.sh install
sudo ./svc.sh start

echo "done....."
