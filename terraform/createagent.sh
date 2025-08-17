#!/bin/bash
set -e

# Variables (replace with Key Vault/secure injection in production)
AZP_URL="https://dev.azure.com/parshchakurkar"
AZP_TOKEN="CmIhlzEzlYrNv0J4NdceWipKJ6ZLuZYg6N4VG4BnhziSDDW2ABGVJQQJ99BHACAAAAAAAAAAAAASAZDO4yiZ "
AZP_POOL="Default"
AZP_AGENT_NAME=linuxagent

# Install dependencies
sudo apt-get update
sudo apt-get install -y curl tar git

# Create agent directory
mkdir /azp && cd /azp

# Download Azure Pipelines agent
curl -LsS https://download.agent.dev.azure.com/agent/4.259.0/vsts-agent-osx-x64-4.259.0.tar.gz -o agent.tar.gz
tar -xzf agent.tar.gz && rm agent.tar.gz

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
