#!/bin/bash
# agent/setup/agent-init.sh - Prep Worker Node

# 1. Install Java 17 (Required)
sudo apt update && sudo apt install openjdk-17-jre-headless -y

# 2. Install Terraform (So the Agent can execute your TF files)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform -y

# 3. Create Jenkins User
sudo useradd -m -d /home/jenkins-agent -s /bin/bash jenkins-agent
sudo mkdir -p /home/jenkins-agent/.ssh
sudo chmod 700 /home/jenkins-agent/.ssh