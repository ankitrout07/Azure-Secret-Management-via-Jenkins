This project, **"Secret Management with HashiCorp Vault,"** is the transition from "it works" to "it's production-secure." 

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
1.  **Install Vault:** Add the HashiCorp repo and install the `vault` binary on your Ubuntu machine.
2.  **Systemd Service:** Create a `/etc/systemd/system/vault.service` file so Vault starts automatically on boot and runs in the background.
3.  **Initialization:** Run `vault operator init` to generate your **Unseal Keys** and **Root Token**. 
    * *Note: Save these securely; you cannot recover them.*
4.  **Unsealing:** Use the keys to unseal the vault so it can start encrypting/decrypting data.

---

### **Phase 2: Secret Architecture (Vault Internal)**
Now you define how and where the Azure secrets live.
1.  **Enable KV Engine:** Enable the Key-Value (KV-V2) engine at a specific path (e.g., `internal/`).
2.  **Store Azure Secrets:** Put your Azure Service Principal (Client ID, Secret, Tenant, Subscription) into a path like `internal/azure-creds`.
3.  **Create ACL Policy:** Write an HCL policy (`jenkins-policy.hcl`) that strictly grants `read` access to that specific path and nothing else.

---

### **Phase 3: The Handshake (AppRole Configuration)**
This is the most critical part for automation.
1.  **Enable AppRole:** Turn on the AppRole authentication method.
2.  **Define the Role:** Create a role named `jenkins-role` and attach the `jenkins-policy` to it.
3.  **Generate Credentials:** * Pull the **Role ID** (static).
    * Generate a **Secret ID** (dynamic/renewable).
    * *These two values are what you will give to Jenkins.*

---

### **Phase 4: Jenkins Integration (The Bridge)**
1.  **Install Plugin:** Install the **HashiCorp Vault Plugin** in Jenkins.
2.  **Add Credentials:** In Jenkins "Manage Credentials," add a new credential of type **Vault App Role Credential**. 
    * Input your `Role ID` and `Secret ID` here.
3.  **Configure System:** In "Configure System," point Jenkins to your Vault URL (e.g., `http://127.0.0.1:8200`).

---

### **Phase 5: The Pipeline (Execution)**
1.  **Write Jenkinsfile:** Create a pipeline using the `withVault` block. 
2.  **Map Variables:** Map the Vault keys (`client_id`, `client_secret`) to Environment Variables (`ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`).
3.  **Terraform Run:** Inside the same block, run `terraform plan` or `apply`. Terraform will automatically pick up these `ARM_` variables from the environment.

---

### **Phase 6: Validation (Audit & Cleanup)**
1.  **Verify Masking:** Check the Jenkins console output to ensure the secrets appear as `****`.
2.  **Audit Logs:** Check the Vault audit logs on your Ubuntu machine to verify that the `jenkins-role` was the one that accessed the secrets.

### **The "Definition of Done" for Project 4**
* [ ] Vault is running as a systemd service.
* [ ] Azure secrets are NOT stored in the Jenkins UI.
* [ ] Jenkins authenticates using AppRole.
* [ ] Terraform successfully deploys an Azure resource using variables injected by Vault.

**Would you like to start with Phase 1 and the specific systemd configuration for your Ubuntu server?**# Azure-Secret-Management-via-Jenkins
