#!/bin/bash
# scripts/vault-setup.sh - Automated Vault Installation & Service Setup

# 1. Add HashiCorp Repo
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 2. Install Vault
sudo apt update && sudo apt install vault -y

# 3. Setup Systemd Service
sudo cp vault/config/vault.service /etc/systemd/system/vault.service
sudo systemctl daemon-reload

# 4. Create Basic Config for Local Dev
sudo mkdir -p /etc/vault.d
sudo tee /etc/vault.d/vault.hcl <<EOF
ui            = true
disable_mlock = true # Allow memory lock (recommended for non-swap environments)
storage "file" {
  path = "/opt/vault/data"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
EOF

# 5. Permission Management
sudo mkdir -p /opt/vault/data
sudo chown -R vault:vault /opt/vault/data /etc/vault.d
sudo chmod 640 /etc/vault.d/vault.hcl

echo "Vault installed and service registered. Start it with: sudo systemctl start vault"