This project, **"Secret Management with HashiCorp Vault,"** is the transition from "it works" to "it's production-secure." 

### **🚀 Quick Start (One Command Setup)**
If you want to automate the entire installation, configuration, and secret-seeding process on your Ubuntu machine, run:
```bash
bash scripts/setup-all.sh
```
This script will guide you through:
- Installing Vault & Systemd Service.
- Initializing and Unsealing the Vault.
- Configuring AppRole and Policies.
- Seeding your Azure Credentials.

---

In your previous projects, you likely stored credentials directly in Jenkins as "Secret Text." This project replaces that static, persistent model with a **Zero-Trust** approach where secrets are ephemeral (they exist only during the job) and dynamic.

### **The "Why" Behind the Project**
1.  **Eliminate Secret Sprawl:** Instead of Azure credentials living in Jenkins, Terraform, and developer machines, they live in **one** central, encrypted source (Vault).
2.  **Blast Radius Reduction:** If your Jenkins server is compromised, an attacker finds a `RoleID` and a `SecretID` that are useless without the other, or a token that expires in minutes. They don't get your permanent Azure root keys.
3.  **Auditability:** Every time Jenkins requests a secret, Vault logs the exact timestamp and the "Identity" that requested it. You get a full audit trail for compliance.

---

### **The Technical Architecture**

The workflow follows a **Machine-to-Machine (M2M)** handshake called **AppRole**:

| Step | Action | Logic |
| :--- | :--- | :--- |
| **1. Authenticate** | Jenkins presents its **RoleID** and **SecretID** to Vault. | Think of this as a "Service Account" login. |
| **2. Issue Token** | Vault validates the IDs and gives Jenkins a **short-lived token**. | This token usually expires as soon as the Jenkins job ends. |
| **3. Authorize** | Vault checks the **Policy** attached to that token. | "Can this job read `internal/azure-creds`? Yes." |
| **4. Inject** | The Vault Plugin injects the secrets as **Environment Variables**. | `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`, etc., are now available to Terraform. |
| **5. Execute** | Terraform runs, uses the variables, and completes the deploy. | Terraform doesn't even know Vault exists; it just sees the variables. |
| **6. Purge** | The Jenkins job finishes, and the secrets vanish from memory. | The "Zero-Footprint" goal is achieved. |

---

### **Project Deliverables**
To call this project "Complete," we will build:
* **A Hardened Vault Instance:** Running on Ubuntu with a restricted systemd service.
* **The KV-V2 Secrets Engine:** A version-controlled store for your Azure Service Principal.
* **The AppRole Auth Backend:** The bridge between Jenkins and Vault.
* **Scoped Policies:** HCL files that define "Least Privilege" (e.g., Jenkins can *read* Azure secrets but cannot *delete* them).
* **A Secure Jenkins Pipeline:** A `Jenkinsfile` that uses the `withVault` wrapper to pull secrets on-the-fly.

### **Senior Engineer Tip**
In this project, we aren't just "storing a password." We are building an **Identity Broker**. If you ever need to rotate your Azure credentials, you update them in **one place** (Vault), and every Jenkins pipeline globally is instantly updated without touching a single `Jenkinsfile`.

**Where should we start?** 1.  **The Infrastructure:** Installing and configuring Vault on your Ubuntu machine.
2.  **The Logic:** Writing the Policies and AppRole configurations.
3.  **The Integration:** Setting up the Jenkins Plugin and Pipeline.


---

Building this project follows a logical flow from **Infrastructure** (Vault setup) to **Security Logic** (Policies/Auth) and finally **CI/CD Integration** (Jenkins).

Here is the step-by-step roadmap to build **Project 4**.


----------------------------------------


### **Phase 1: The Foundation (Vault Host Setup)**
Before Jenkins can talk to Vault, the Vault server must be stable and accessible.
1.  **Install Vault & Service:** Run `bash scripts/vault-setup.sh`. This installs Vault and registers the `vault.service`.
2.  **Start Vault:** `sudo systemctl start vault`.
3.  **Initialization (Manual):** Run `vault operator init`. 
    *   **CRITICAL:** Save the 5 Unseal Keys and the Root Token in a secure location (e.g., a physical safe or a team password manager).
4.  **Unsealing (Manual):** Run `vault operator unseal` 3 times using 3 different keys to "open" the vault for use.
5.  **Log In:** `export VAULT_TOKEN="your-root-token"` then `vault login $VAULT_TOKEN`.

---

### **Phase 2 & 3: Automated Logic (Vault Internal)**
We have automated the KV engine, Policies, and AppRole setup.
1.  **Run Config Script:** `bash scripts/vault-config.sh`.
2.  **Capture IDs:** The script will output a **Role ID** and a **Secret ID**. Keep these for Phase 4.
3.  **Seed Secrets:** Use the command provided at the end of the script to store your actual Azure Service Principal details.

---

### **Phase 4: Jenkins Integration (The Bridge)**
1.  **Install Plugin:** Install the **HashiCorp Vault Plugin** in Jenkins.
2.  **Add Credentials:** In Jenkins "Manage Credentials," add a new credential of type **Vault App Role Credential**. 
    *   Input the `Role ID` and `Secret ID` gathered in Phase 2.
    *   Set the ID as `vault-approle-id` (referenced in the `Jenkinsfile`).
3.  **Configure System:** In "Configure System" -> "Vault", set the URL to `http://<your-vault-ip>:8200`.

---

### **Phase 5: The Pipeline (Execution)**
1.  **Write Jenkinsfile:** Use the provided [Jenkinsfile](jenkins/Jenkinsfile).
2.  **Run Job:** Trigger the Jenkins job. It will:
    *   Authenticate via AppRole.
    *   Pull Azure secrets from `internal/azure-creds`.
    *   Inject them into the environment.
    *   Run `terraform plan` successfully.

---

### **Phase 6: Validation (Audit & Cleanup)**
1.  **Verify Masking:** Check Jenkins logs; secrets should be `****`.
2.  **Workspace Cleanup:** The `post { always { deleteDir() } }` block ensures no secrets remain on the agent disk.

### **The "Definition of Done" for Project 4**
* [x] Vault is running as a systemd service.
* [x] Azure secrets are NOT stored in the Jenkins UI.
* [x] Jenkins authenticates using AppRole.
* [x] Terraform successfully deploys an Azure resource using variables injected by Vault.

---
# Azure-Secret-Management-via-Jenkins
