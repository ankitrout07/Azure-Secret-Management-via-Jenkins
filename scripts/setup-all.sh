#!/bin/bash
# scripts/setup-all.sh - Master Orchestration for Vault-Jenkins Project

set -e

echo "===================================================="
echo "   SECRET MANAGEMENT SETUP: VAULT + JENKINS"
echo "===================================================="

# 1. Installation & Service Setup
echo "--- Step 1: Installing Vault & Registering Service ---"
bash scripts/vault-setup.sh

echo "--- Starting Vault Service ---"
sudo systemctl start vault
sleep 2

# 2. Check Vault Status
echo "--- Step 2: Checking Vault Status ---"
STATUS=$(vault status -format=json 2>/dev/null || true)

# Handle Uninitialized Vault
if [[ $(echo "$STATUS" | grep -c '"initialized": false') -eq 1 ]]; then
    echo "Vault is NOT initialized."
    echo "Running 'vault operator init'..."
    INIT_OUT=$(vault operator init)
    echo "----------------------------------------------------"
    echo "CRITICAL: SAVE THESE KEYS SECURELY!"
    echo "$INIT_OUT"
    echo "----------------------------------------------------"
    echo "Press ENTER once you have saved the keys above."
    read
else
    echo "Vault is already initialized."
fi

# Handle Sealed Vault
STATUS=$(vault status -format=json 2>/dev/null || true)
if [[ $(echo "$STATUS" | grep -c '"sealed": true') -eq 1 ]]; then
    echo "Vault is SEALED. You must unseal it now."
    echo "Please run 'vault operator unseal' 3 times in a separate terminal."
    echo "Waiting for unseal..."
    while [[ $(vault status -format=json 2>/dev/null | grep -c '"sealed": true') -eq 1 ]]; do
        sleep 5
        echo "Still sealed... (Check your other terminal)"
    done
    echo "Vault UNSEALED!"
else
    echo "Vault is already unsealed."
fi

# 3. Internal Configuration
echo "--- Step 3: Configuring Vault Internals ---"
echo "Please enter your VAULT_ROOT_TOKEN to proceed:"
read -s ROOT_TOKEN
export VAULT_TOKEN="$ROOT_TOKEN"
export VAULT_ADDR="http://127.0.0.1:8200"

bash scripts/vault-config.sh

# 4. Seed Azure Secrets
echo "--- Step 4: Seeding Azure Secrets ---"
echo "Enter Azure Client ID:"
read ARM_CLIENT_ID
echo "Enter Azure Client Secret:"
read -s ARM_CLIENT_SECRET
echo "Enter Azure Subscription ID:"
read ARM_SUBSCRIPTION_ID
echo "Enter Azure Tenant ID:"
read ARM_TENANT_ID

vault kv put internal/azure-creds \
    client_id="$ARM_CLIENT_ID" \
    client_secret="$ARM_CLIENT_SECRET" \
    subscription_id="$ARM_SUBSCRIPTION_ID" \
    tenant_id="$ARM_TENANT_ID"

echo "===================================================="
echo "   PROJECT SETUP COMPLETE!"
echo "===================================================="
echo "1. Open Jenkins and install 'HashiCorp Vault' Plugin."
echo "2. Add a 'Vault App Role' Credential."
echo "3. Use the RoleID and SecretID displayed above."
echo "4. Trigger your Jenkins pipeline!"
echo "===================================================="
