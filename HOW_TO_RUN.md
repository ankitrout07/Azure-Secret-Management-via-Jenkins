# How to Run the Project

This guide walks you through setting up and running the Azure Secret Management via Jenkins project end-to-end.

---

## **Prerequisites**

Before you start, ensure you have:

- **Ubuntu 20.04 LTS** or higher (for Vault and Jenkins Agent)
- **Azure Subscription** with an active Service Principal
- **Jenkins Server** (already running)
- **Git** installed on your machine
- **sudo access** on the Ubuntu machine

---

## **Step 1: Clone the Repository**

```bash
git clone https://github.com/ankitrout07/Azure-Secret-Management-via-Jenkins.git
cd Azure-Secret-Management-via-Jenkins
```

---

## **Step 2: Set Up Vault**

### **2.1 Run the Vault Setup Script**

```bash
chmod +x scripts/vault-setup.sh
sudo bash scripts/vault-setup.sh
```

This script will:
- Add HashiCorp repository to apt
- Install Vault
- Create Vault systemd service
- Set up basic configuration

### **2.2 Start the Vault Service**

```bash
sudo systemctl start vault
sudo systemctl enable vault  # Enable on boot
sudo systemctl status vault  # Verify it's running
```

### **2.3 Initialize Vault**

```bash
export VAULT_ADDR='http://127.0.0.1:8200'

# Initialize Vault (generates unseal keys and root token)
vault operator init -key-shares=5 -key-threshold=3
```

**Save the output!** You'll need:
- **Unseal Keys** (at least 3 to unseal)
- **Root Token** (for initial setup)

### **2.4 Unseal Vault**

```bash
# Use at least 3 of the 5 unseal keys
vault operator unseal <KEY_1>
vault operator unseal <KEY_2>
vault operator unseal <KEY_3>

# Verify Vault is unsealed
vault status
```

Output should show:
```
Sealed: false
✓ Vault is unsealed
```

### **2.5 Login to Vault**

```bash
vault login <ROOT_TOKEN>
```

---

## **Step 3: Configure Vault for Azure Secrets**

### **3.1 Enable KV-V2 Secrets Engine**

```bash
vault secrets enable -version=2 -path=internal kv
```

### **3.2 Store Azure Service Principal Credentials**

Replace with your actual Azure credentials:

```bash
vault kv put internal/azure-creds \
  client_id="<YOUR_AZURE_CLIENT_ID>" \
  client_secret="<YOUR_AZURE_CLIENT_SECRET>" \
  subscription_id="<YOUR_AZURE_SUBSCRIPTION_ID>" \
  tenant_id="<YOUR_AZURE_TENANT_ID>"
```

### **3.3 Verify the Secret is Stored**

```bash
vault kv get internal/azure-creds
```

You should see the stored credentials.

---

## **Step 4: Configure AppRole Authentication**

### **4.1 Enable AppRole Auth Method**

```bash
vault auth enable approle
```

### **4.2 Create Jenkins Policy**

```bash
# Create the policy from the file
vault policy write jenkins-policy vault/policies/jenkins-policy.hcl

# Verify the policy
vault policy list
vault policy read jenkins-policy
```

### **4.3 Create AppRole for Jenkins**

```bash
vault write auth/approle/role/jenkins-role \
  token_ttl=1h \
  token_max_ttl=4h \
  policies="jenkins-policy"
```

### **4.4 Get Role ID and Generate Secret ID**

```bash
# Get Role ID (save this)
vault read auth/approle/role/jenkins-role/role-id

# Generate Secret ID (save this - it's one-time use initially)
vault write -f auth/approle/role/jenkins-role/secret-id
```

---

## **Step 5: Set Up Jenkins Agent**

### **5.1 Run the Agent Init Script**

```bash
chmod +x agent/setup/agent-init.sh
sudo bash agent/setup/agent-init.sh
```

This installs:
- Java 17 (Jenkins requirement)
- Terraform
- Creates jenkins-agent user

### **5.2 Configure Jenkins Agent in Jenkins Web UI**

1. Open Jenkins at `http://<JENKINS_IP>:8080`
2. Navigate to **Manage Jenkins → Nodes and Clouds → New Node**
3. Name: `terraform-runner`
4. Labels: `terraform-runner`
5. Remote root directory: `/home/jenkins-agent`
6. Launch method: **Launch agents via SSH**
7. Host: `<AGENT_IP_OR_HOSTNAME>`
8. Credentials: Use SSH key pair

### **5.3 Store AppRole Credentials in Jenkins**

1. Go to **Manage Jenkins → Credentials → System → Global credentials (unrestricted)**
2. Click **Add Credentials**
3. Kind: `Vault App Role Credential Provider`
4. Role ID: `<ROLE_ID_FROM_STEP_4.4>`
5. Secret ID: `<SECRET_ID_FROM_STEP_4.4>`
6. ID: `vault-approle-id`
7. Save

### **5.4 Install Vault Plugin in Jenkins**

1. Navigate to **Manage Jenkins → Plugins → Available plugins**
2. Search for **"HashiCorp Vault"**
3. Install **HashiCorp Vault** plugin
4. Restart Jenkins

---

## **Step 6: Create/Update the Jenkins Pipeline**

### **6.1 Create a New Pipeline Job**

1. Click **New Item** in Jenkins
2. Name: `vault-terraform-deploy`
3. Type: **Pipeline**
4. Click **OK**

### **6.2 Add Pipeline Configuration**

In the pipeline section, select **Pipeline script from SCM**:
- SCM: **Git**
- Repository URL: `https://github.com/ankitrout07/Azure-Secret-Management-via-Jenkins.git`
- Branch: `main`
- Script path: `jenkins/Jenkinsfile`

**OR** paste the Jenkinsfile content directly under **Pipeline → Script**.

### **6.3 Point to Correct Vault Address**

Update the `VAULT_ADDR` in the Jenkinsfile to match your Vault server:

```groovy
environment {
    VAULT_ADDR = 'http://<YOUR_VAULT_IP>:8200'
}
```

---

## **Step 7: Run the Pipeline**

### **7.1 Trigger the Pipeline**

1. Go to your Jenkins job: `vault-terraform-deploy`
2. Click **Build Now**

### **7.2 Monitor the Build**

1. Click on the build number (e.g., `#1`)
2. Click **Console Output** to see logs

Expected output:
```
Job assigned to Agent: terraform-runner
terraform --version
Secrets securely injected from Vault.
Initializing the backend...
Running plan within a Terraform working directory...
```

---

## **Step 8: Verify Success**

### **8.1 Check Vault Audit Logs**

```bash
vault audit list
vault audit enable file file_path=/opt/vault/logs/audit.log
# Then view logs
tail -f /opt/vault/logs/audit.log
```

You should see entries like:
```
auth_method=approle request_path=auth/approle/login response=success
auth_method=kv_v2 request_path=internal/data/azure-creds response=success
```

### **8.2 Check Jenkins Build Logs**

In Jenkins Console Output, verify:
```
✓ Secrets securely injected from Vault
✓ Terraform init completed
✓ Terraform plan succeeded
```

### **8.3 Verify Azure Resources**

```bash
# Check if resource group was created
az group list --query "[?name=='rg-vault-jenkins-project']"
```

---

## **Troubleshooting**

### **Vault Not Unsealing**
```bash
# Check Vault status
sudo systemctl status vault

# View Vault logs
sudo tail -100 /var/log/syslog | grep vault
```

### **Jenkins Agent Connection Failed**
```bash
# Check SSH connectivity to agent
ssh jenkins-agent@<AGENT_IP>

# Verify Terraform is installed
terraform --version
```

### **Authentication Failed - AppRole**
```bash
# Verify AppRole is enabled
vault auth list

# Test AppRole login manually
vault write -f auth/approle/role/jenkins-role/secret-id
vault write auth/approle/login role_id="<ROLE_ID>" secret_id="<SECRET_ID>"
```

### **Terraform Cannot Access Azure**
```bash
# Verify credentials are in Vault
vault kv get internal/azure-creds

# Test Azure login manually
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID
```

---

## **Project Workflow Summary**

```
┌─────────────────┐
│  Jenkins Job    │
│   Triggered     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ AppRole Auth to │
│     Vault       │
└────────┬────────┘
         │
         ▼
┌──────────────────────┐
│ Request Azure Creds  │
│ from Vault (KV-V2)   │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Inject Secrets as    │
│ Environment Variables│
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Terraform Uses Creds │
│ to Deploy to Azure   │
└────────┬─────────────┘
         │
         ▼
┌──────────────────────┐
│ Secrets Purged from  │
│ Memory After Job     │
└──────────────────────┘
```

---

## **Security Best Practices**

1. **Rotate Secrets Periodically**: Update Azure credentials in Vault every 90 days
2. **Monitor Vault Audit Logs**: Review who accessed what and when
3. **Restrict AppRole Access**: Use IP whitelisting in policies (future improvement)
4. **Enable TLS**: Use HTTPS for Vault in production (configure in vault.hcl)
5. **Seal Vault on Shutdown**: Run `vault operator seal` before server maintenance
6. **Delete Sensitive Logs**: Remove Jenkins build logs containing secret references

---

## **Next Steps**

- Set up automated secret rotation
- Enable Vault High Availability (HA)
- Configure backup and disaster recovery
- Implement log aggregation and monitoring
- Create environment-specific policies (dev/staging/prod)

---

## **Support**

For issues or questions, check:
- [Vault Documentation](https://www.vaultproject.io/docs)
- [Vault Jenkins Plugin](https://plugins.jenkins.io/hashicorp-vault-plugin/)
- Repository Issues: `https://github.com/ankitrout07/Azure-Secret-Management-via-Jenkins/issues`
