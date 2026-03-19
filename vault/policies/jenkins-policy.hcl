# Allow Jenkins to read the Azure Service Principal credentials
path "internal/data/azure-creds" {
  capabilities = ["read"]
}

# Allow Jenkins to list secrets in the internal path
path "internal/metadata/azure-creds" {
  capabilities = ["list", "read"]
}