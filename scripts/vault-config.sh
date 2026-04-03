#!/bin/bash
# scripts/vault-config.sh - Automated Vault Internal Configuration

# Prerequisites: 
# 1. Vault must be running and unsealed.
# 2. VAULT_TOKEN must be set or you must be logged in as root.

export VAULT_ADDR='http://127.0.0.1:8200'

echo "--- Initializing Vault Configuration ---"

# 1. Enable KV-V2 Secrets Engine
echo "Step 1: Enabling KV-V2 Secrets Engine at 'internal/'"
vault secrets enable -path=internal kv-v2 || echo "KV engine already enabled or failed."

# 2. Enable AppRole Auth Method
echo "Step 2: Enabling AppRole Authentication"
vault auth enable approle || echo "AppRole already enabled or failed."

# 3. Apply Jenkins Policy
echo "Step 3: Applying Jenkins Policy"
vault policy write jenkins-policy vault/policies/jenkins-policy.hcl

# 4. Create Jenkins Role
echo "Step 4: Creating Jenkins AppRole"
vault write auth/approle/role/jenkins-role \
    secret_id_ttl=10m \
    token_num_uses=10 \
    token_ttl=20m \
    token_max_ttl=30m \
    policies="jenkins-policy"

# 5. Retrieve RoleID and SecretID (Example for user)
echo "-----------------------------------------------"
echo "Vault Configuration Complete!"
echo "-----------------------------------------------"
echo "To integrate with Jenkins, you need these IDs:"
echo ""
ROLE_ID=$(vault read -field=role_id auth/approle/role/jenkins-role/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/jenkins-role/secret-id)

echo "Role ID: $ROLE_ID"
echo "Secret ID: $SECRET_ID"
echo ""
echo "IMPORTANT: Save these in Jenkins 'Manage Credentials' -> 'Vault App Role'!"
echo "-----------------------------------------------"
echo "Now seed your Azure secrets with this command:"
echo "vault kv put internal/azure-creds client_id='...' client_secret='...' subscription_id='...' tenant_id='...'"
