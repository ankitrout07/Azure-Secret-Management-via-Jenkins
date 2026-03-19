#!/bin/bash
# scripts/vault-setup.sh - Automated Vault Installation

# 1. Add HashiCorp Repo
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 2. Install Vault
sudo apt update && sudo apt install vault -y

# 3. Create Basic Config for Local Dev
sudo mkdir -p /etc/vault.d
sudo tee /etc/vault.d/vault.hcl <<EOF
ui            = true
storage "file" {
  path = "/opt/vault/data"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
EOF

sudo mkdir -p /opt/vault/data
sudo chown -R vault:vault /opt/vault/data