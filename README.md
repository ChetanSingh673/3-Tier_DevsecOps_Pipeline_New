# 3-Tier DevSecOps Blog Platform — Setup Guide

This README collects useful commands and links to install common DevOps, CI/CD, and security tooling on Ubuntu systems. It has been cleaned up, organized, and corrected for clarity. Always review commands for your environment and needs.

> **Note:** Replace all `<VERSION>`, `<your-server-ip>`, `<jenkins-ip>`, `<sonar-ip-address>`, and similar placeholders with your actual values.

## End-to-End Deployment Flow

![Architecture Diagram](End-to-End_Deployment_Flow.png)

---

## Architecture

```bash
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Frontend   │────▶│   Backend    │────▶│  PostgreSQL   │
│   (React +   │◀────│  (Node.js +  │◀────│              │
│    Nginx)    │     │   Express)   │     │              │
│   Port 80    │     │  Port 5000   │     │  Port 5432   │
└──────────────┘     └──────────────┘     └──────────────┘
```

## Project Structure

3-Tier_DevsecOps_Pipeline_New/
├── frontend/                # React (Vite) frontend
│   ├── src/                 # React components & pages
│   ├── nginx.conf           # Nginx config for serving the app
│   └── package.json
├── backend/                 # Node.js Express API
│   ├── src/                 # Routes, DB connection
│   └── package.json
├── deploy/                  # EC2 deployment scripts
│   ├── setup.sh             # One-click EC2 setup script
│   └── jerney-nginx.conf    # Nginx reverse proxy config
└── README.md

## Table of Contents

* [Prerequisites](#prerequisites)
* [System Update & Common Packages](#system-update--common-packages)
* [Java](#java)
* [Jenkins](#jenkins)
* [Docker](#docker)
* [Trivy](#trivy-vulnerability-scanner)
* [Prometheus](#prometheus)
* [Node Exporter](#node-exporter)
* [Grafana](#grafana)
* [Jenkins Plugins to Install](#jenkins-plugins-to-install)
* [Jenkins Credentials to Store](#jenkins-credentials-to-store)
* [Jenkins Tools Configuration](#jenkins-tools-configuration)
* [Jenkins System Configuration](#jenkins-system-configuration)
* [EKS ALB Ingress Kubernetes Setup Guide](#eks-alb-ingress-kubernetes-setup-guide)
* [Monitor Kubernetes with Prometheus](#monitor-kubernetes-with-prometheus)
* [Installing Argo CD](#installing-Argo-CD-on-the-eks-cluster)
* [AWS Secrets Manager Configuration with External Secrets Operator](#aws-secrets-manager-configuration-with-external-secrets-operator)
* [Notes and Recommendations](#notes-and-recommendations)

---

### Ports to Enable in Security Group

| Service | Port |
| :--- | :--- |
| HTTP | 80 |
| HTTPS | 443 |
| SSH | 22 |
| Jenkins | 8080 |
| SonarQube | 9000 |
| Prometheus | 9090 |
| Node Exporter | 9100 |
| Grafana | 3000 |
---

## Prerequisites
---

This guide assumes an Ubuntu/Debian-like environment and sudo privileges.

---
## System Update & Common Packages

```bash
sudo apt update -y
sudo apt upgrade -y
```
**First**: refresh the package list

**Second**: install available updates

```bash
# Common tools

sudo apt install -y bash-completion wget git zip unzip curl jq net-tools build-essential ca-certificates apt-transport-https gnupg fontconfig
```
---
**Reload bash completion if needed:**
```bash
source /etc/bash_completion
```
`bash-completion` is a package that makes TAB auto-completion work better in the Linux terminal. After installing bash-completion you can press TAB button for auto-completion. For example, cd /etc/apa + TAB → cd /etc/apache2/.

# Install latest Git:

```bash
sudo add-apt-repository ppa:git-core/ppa
sudo apt update
sudo apt install git -y
```

---

# Java
---
Install OpenJDK 21:

```bash
# OR OpenJDK 21
sudo apt install -y openjdk-21-jdk
```
Verify:
```bash
java --version
```
```ssh
readlink -f $(which java)
/usr/lib/jvm/java-21-openjdk-amd64/bin/java
```
**Note:** In the jenkins tool configuration we need to use in Java_Home= /usr/lib/jvm/java-21-openjdk-amd64

---
# Jenkins
Official docs: [https://www.jenkins.io/doc/book/installing/linux/](https://www.jenkins.io/doc/book/installing/linux/)
```bash
sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc]" \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null
```
```bash
sudo apt update
sudo apt install jenkins
sudo systemctl enable --now jenkins
sudo systemctl start jenkins
sudo systemctl status jenkins
```
Initial admin password:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
Then open: [http://your-server-ip:8080](http://your-server-ip:8080)

**Note**: Jenkins requires a compatible Java runtime. Check the Jenkins documentation for supported Java versions.

---
# Docker
Official docs: [https://docs.docker.com/engine/install/ubuntu/](https://docs.docker.com/engine/install/ubuntu/)
```bash
# Add Docker's official GPG key:
sudo apt update
sudo apt install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt update

# Install the Docker packages.
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add user to docker group (log out / in or newgrp to apply)
sudo usermod -aG docker $USER
newgrp docker
docker ps
```

If Jenkins needs Docker access:

```bash
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

Check Docker status:
```bash
sudo systemctl status docker
```
---

# Trivy (Vulnerability Scanner)
Docs: [https://trivy.dev/docs/latest/getting-started/installation/](https://trivy.dev/docs/latest/getting-started/installation/)
```bash
sudo apt-get install wget apt-transport-https gnupg lsb-release
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
sudo apt-get update
sudo apt-get install -y trivy


trivy --version
```
---

# Prometheus
Official downloads: [https://prometheus.io/download/](https://prometheus.io/download/)

**Generic install steps:**

```bash
# Create a prometheus user
sudo useradd --system --no-create-home --shell /usr/sbin/nologin prometheus

wget -O prometheus.tar.gz "https://github.com/prometheus/prometheus/releases/download/v3.5.0/prometheus-3.5.0.linux-amd64.tar.gz"
tar -xvf prometheus.tar.gz
cd prometheus-*/

sudo mkdir -p /data /etc/prometheus
sudo mv prometheus promtool /usr/local/bin/
sudo mv consoles/ console_libraries/ /etc/prometheus/
sudo mv prometheus.yml /etc/prometheus/prometheus.yml

sudo chown -R prometheus:prometheus /etc/prometheus /data
```

**Systemd service** (`sudo vim /etc/systemd/system/prometheus.service`):
```bash
[Unit]
Description=Prometheus
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=on-failure
RestartSec=5s
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/data \
  --web.console.templates=/etc/prometheus/consoles \
  --web.console.libraries=/etc/prometheus/console_libraries \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
```

# Enable & start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus
```

Access: [http://ip-address:9090](http://ip-address:9090)

---

# Node Exporter
Docs: [https://prometheus.io/download/#node_exporter](https://prometheus.io/download/#node_exporter)

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin node_exporter

wget -O node_exporter.tar.gz "https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz"
tar -xvf node_exporter.tar.gz
sudo mv node_exporter-*/node_exporter /usr/local/bin/
rm -rf node_exporter*
```

Systemd service: (`sudo vim /etc/systemd/system/node_exporter.service`)

```bash
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
Restart=on-failure
ExecStart=/usr/local/bin/node_exporter --collector.logind

[Install]
WantedBy=multi-user.target
```

# Enable & start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter
```

# Prometheus scrape config:

Add to `sudo vim /etc/prometheus/prometheus.yml:`

```bash
  - job_name: "node_exporter"
    static_configs:
      - targets: ["<ip-address>:9100"]

  - job_name: "jenkins"
    metrics_path: /prometheus
    static_configs:
      - targets: ["<jenkins-ip>:8080"]
```

Validate config:

```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl restart prometheus
```
---

# Grafana
Docs: [https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/](https://grafana.com/docs/grafana/latest/setup-grafana/installation/debian/)

```bash
sudo apt-get install -y apt-transport-https software-properties-common wget

sudo mkdir -p /etc/apt/keyrings/
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null

echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install -y grafana

sudo systemctl daemon-reload
sudo systemctl enable --now grafana-server
sudo systemctl start grafana-server
sudo systemctl status grafana-server
```

Access: [http://ip-address:3000](http://ip-address:3000)

Create the Prometheus Datasource: [http://promethues-ip:9090](http://promethues-ip:9090)

---

# Dashboard id
* Node_Exporter 1860 Docs: https://grafana.com/grafana/dashboards/1860-node-exporter-full/
* jenkins 9964 Docs: https://grafana.com/grafana/dashboards/9964-jenkins-performance-and-health-overview/
* kubernetes 17119 Docs: https://grafana.com/grafana/dashboards/18283-kubernetes-dashboard/

# Jenkins Plugins to Install
* NodeJS
* Email Extension Template Plugin
* Pipeline: Stage View Plugin
* SonarQube Scanner for Jenkins
* Prometheus metrics plugin
* Docker API Plugin
* Docker Commons Plugin
* Docker Pipeline
* Docker plugin
* docker-build-step

# SonarQube Docker Container Run for Analysis

```bash
docker run -d --name sonarqube \
  -p 9000:9000 \
  -v sonarqube_data:/opt/sonarqube/data \
  -v sonarqube_logs:/opt/sonarqube/logs \
  -v sonarqube_extensions:/opt/sonarqube/extensions \
  sonarqube:lts-community
```
# Jenkins Credentials to Store
| Purpose | ID | Type | Notes
| :--- | :--- | :--- | :--- |
|Email | email-creds | Username/app | App Password |	
SonarQube | sonar-token | Secret text | From SonarQube application
Docker Hub | dockerhub-creds | Secret text | From your Docker Hub profile
GitHub | github-creds | Username/app | git hub token 

Webhook example:
`http://<jenkins-ip>:8080/sonarqube-webhook/`

**Note:** Create the webhook in the SonarQube

# Jenkins Tools Configuration
* JDK
* SonarQube Scanner installations [sonar-scanner]
* NodeJS
* Docker installations

# Jenkins System Configuration
**SonarQube servers:**
* Name: sonar-server
* URL: http://:9000
* Credentials: Add from Jenkins credentials

# Extended E-mail Notification:
* SMTP server: smtp.gmail.com
* SMTP Port: 465
* Use SSL
* Default user e-mail suffix: @gmail.com

# E-mail Notification:
* SMTP server: smtp.gmail.com
* Default user e-mail suffix: @gmail.com
* Use SMTP Authentication: Yes
* User Name: example@gmail.com
* Password: Use credentials
* Use TLS: Yes
* SMTP Port: 587
* Reply-To Address: example@gmail.com

---

## Now See the configuration pipeline of the jenkins
## EKS ALB Ingress Kubernetes Setup Guide 
## EKS cluster setup and ALB Ingress Kubernetes Setup Guide

This guide covers the installation and setup for AWS CLI, kubectl, eksctl, and helm, and creating/configuring an EKS cluster with AWS Load Balancer Controller.

---
# 1. AWS CLI Installation
Refer: [AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
```bash
sudo apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```
---
# 2. kubectl Installation
Refer: [kubectl Installation Guide](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
```bash
sudo apt-get update
# apt-transport-https may be a dummy package; if so, you can skip that package
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg

# If the folder `/etc/apt/keyrings` does not exist, it should be created before the curl command, read the note below.
# sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg # allow unprivileged APT programs to read this keyring

# This overwrites any existing configuration in /etc/apt/sources.list.d/kubernetes.list
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list   # helps tools such as command-not-found to work correctly

sudo apt-get update
sudo apt-get install -y kubectl bash-completion

# Enable kubectl auto-completion
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -F __start_kubectl k' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
```
---
# 3. eksctl Installation
Refer: [eksctl Installation Guide](https://docs.aws.amazon.com/eks/latest/eksctl/installation.html)
```bash
# for ARM systems, set ARCH to: `arm64`, `armv6` or `armv7`
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"

# (Optional) Verify checksum
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check

tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz

sudo install -m 0755 /tmp/eksctl /usr/local/bin && rm /tmp/eksctl

# Install bash completion
sudo apt-get install -y bash-completion

# Enable eksctl auto-completion
echo 'source <(eksctl completion bash)' >> ~/.bashrc
echo 'alias e=eksctl' >> ~/.bashrc
echo 'complete -F __start_eksctl e' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
```
---
# 4. Helm Installation
Refer: [Helm Installation Guide](https://helm.sh/docs/intro/install/)
```bash
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm bash-completion

# Enable Helm auto-completion
echo 'source <(helm completion bash)' >> ~/.bashrc
echo 'alias h=helm' >> ~/.bashrc
echo 'complete -F __start_helm h' >> ~/.bashrc

# Apply changes immediately
source ~/.bashrc
```

# 5. AWS CLI Configuration
```bash
aws configure
aws configure list
```
Create the User and apply the policy on it "AdministratorAccess"

# 6. Create EKS Cluster and Nodegroup
```bash
eksctl create cluster --name chetan-cluster2026 --region ap-south-1 --version 1.33 --node-type t3.medium --nodes 2  --nodes-min 2 --nodes-max 4 --node-volume-size 30 --zones ap-south-1a,ap-south-1b
```

# 7. Update kubeconfig
```bash
aws eks update-kubeconfig --name chetan-cluster2026 --region ap-south-1
```

# 8. Associate IAM OIDC Provider
```bash
eksctl utils associate-iam-oidc-provider --cluster chetan-cluster2026 --approve
```

# 9. Create IAM Policy for AWS Load Balancer Controller

New policy link: [AWS EKS LBC Policy](https://docs.aws.amazon.com/eks/latest/userguide/lbc-manifest.html)

```bash
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.13.3/docs/install/iam_policy.json

aws iam create-policy \
  --policy-name AWSLoadBalancerControllerIAMPolicy \
  --policy-document file://iam_policy.json
```

# 10. Create IAM Service Account

Replace <ACCOUNT_ID> with your AWS account ID.
```bash
eksctl create iamserviceaccount \
  --cluster=chetan-cluster2026 \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::<ACCOUNT_ID>:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --region ap-south-1 \
  --approve
```

# 11. Install AWS Load Balancer Controller via Helm
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update eks

helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=chetan-cluster2026 \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set region=ap-south-1 \
  --version 1.13.3
```

**Optional:** List available versions:
```bash
helm search repo eks/aws-load-balancer-controller --versions
helm list -A
```

**Verify installation:**
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

## Monitor Kubernetes with Prometheus

**Install Node Exporter using Helm:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl create namespace prometheus-node-exporter
helm install prometheus-node-exporter prometheus-community/prometheus-node-exporter --namespace prometheus-node-exporter
```
Add to `/etc/prometheus/prometheus.yml:`
```bash
  - job_name: 'k8s'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['node1Ip:9100']
```

Docs: [https://grafana.com/grafana/dashboards/17119-kubernetes-eks-cluster-prometheus/](https://grafana.com/grafana/dashboards/17119-kubernetes-eks-cluster-prometheus/) ID FOR EKS 17119

Validate config:
```bash
promtool check config /etc/prometheus/prometheus.yml
sudo systemctl restart  prometheus.service
```

████████████████████████████████████████████████████████████████████████████████████████

# Installing Argo CD on the eks cluster
Docs: [https://www.eksworkshop.com/docs/automation/gitops/argocd/access_argocd](https://www.eksworkshop.com/docs/automation/gitops/argocd/access_argocd)

Docs: [https://github.com/argoproj/argo-helm](https://github.com/argoproj/argo-helm)

# Argocd installation via helm chart
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```
```bash
kubectl create namespace argocd 
helm install argocd argo/argo-cd --namespace argocd
kubectl get all -n argocd 
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}' 
```
# To get the loadbalancer of the argocd alb url

Username: admin
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
---

████████████████████████████████████████████████████████████████████████████████████████

# AWS Secrets Manager Configuration with External Secrets Operator

Kubernetes manifests for syncing database credentials from AWS Secrets Manager into Kubernetes Secrets using the External Secrets Operator (ESO) with IRSA authentication.

* External Secrets Operator installed in the cluster
```bash
sudo helm repo add external-secrets https://charts.external-secrets.io
sudo helm repo update
sudo helm install external-secrets external-secrets/external-secrets --namespace external-secrets --create-namespace --set installCRDs=true
```

* Install EBS CSI Controller
```bash
aws iam attach-role-policy \
--role-name <NodeInstanceRoleName> \
--policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
```
```bash
# Commnad to check if csi and controller driver is installed or not
sudo kubectl get pods -n kube-system | grep ebs-csi
```
If using a KMS customer-managed key, add kms:Decrypt permission on the KMS key ARN

**Files**
|File	| Description
| :--- | :--- |
service-account.yaml |	ServiceAccount annotated with the IAM role ARN for IRSA
cluster-secret-store.yaml	| ClusterSecretStore connecting ESO to AWS Secrets Manager in ap-south-1
external-secret.yaml |	ExternalSecret that syncs prod/db-credentials into a Kubernetes Secret

# Setup

**1. Create the secret in AWS Secrets Manager**
```bash
sudo aws secretsmanager create-secret \
  --name prod/db-credentials \
  --region ap-south-1 \
  --secret-string '{"POSTGRES_USER":"chetan_user","POSTGRES_PASSWORD":"chetan1234","POSTGRES_DB":"chetan_db"}'
```
```bash
# verify the secret
aws secretsmanager describe-secret \
  --secret-id prod/db-creds \
  --region ap-south-1
```
**2. Enable OIDC provider for the EKS cluster**
```bash
# Check if OIDC is already associated
aws eks describe-cluster --name my-cluster --region ap-south-1 \
  --query "cluster.identity.oidc.issuer" --output text

# If not, create the OIDC provider
eksctl utils associate-iam-oidc-provider \
  --cluster my-cluster \
  --region ap-south-1 \
  --approve
```
**3. Create the IAM policy**
```bash
aws iam create-policy \
  --policy-name ESO-SecretsManager-Policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        "Resource": "arn:aws:secretsmanager:ap-south-1:<ACCOUNT_ID>:secret:prod/db-credentials-*"
      }
    ]
  }'
```

**4. Create the IAM role with trust policy**
```bash
# Get your OIDC provider ID
OIDC_ID=$(aws eks describe-cluster --name my-cluster --region ap-south-1 \
  --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)

# Create the role
aws iam create-role \
  --role-name ESO-SecretsManager-Role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/oidc.eks.ap-south-1.amazonaws.com/id/'$OIDC_ID'"
        },
        "Action": "sts:AssumeRoleWithWebIdentity",
        "Condition": {
          "StringEquals": {
            "oidc.eks.ap-south-1.amazonaws.com/id/'$OIDC_ID':sub": "system:serviceaccount:external-secrets:external-secrets-sa",
            "oidc.eks.ap-south-1.amazonaws.com/id/'$OIDC_ID':aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  }'

# Attach the policy to the role
aws iam attach-role-policy \
  --role-name ESO-SecretsManager-Role \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/ESO-SecretsManager-Policy
```

**5. Update placeholders**

In service-account.yaml, replace:

<ACCOUNT_ID> — your AWS account ID
<ESO_IAM_ROLE_NAME> — the IAM role name created for ESO
In external-secret.yaml, update:

namespace — the namespace where your application runs
remoteRef.key — if your secret name differs from prod/db-credentials

**6. Verify ESO**
```bash
# Check the ClusterSecretStore status
kubectl get clustersecretstore aws-secrets-manager

# Check the ExternalSecret sync status
kubectl get externalsecret -n three-tier db-credentials

# Verify the Kubernetes Secret was created
sudo kubectl get secret -n three-tier db-credentials -o jsonpath='{.data.POSTGRES_USER}' | base64 -d
sudo kubectl get secret -n three-tier db-credentials -o jsonpath='{.data.POSTGRES_DB}' | base64 -d
sudo kubectl get secret -n three-tier db-credentials -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d

```

**6. Verify PostgresDB**
```bash
sudo kubectl exec -it blog-db-0 -n three-tier -- sh

/ # psql -U chetan_user -d chetan_db
psql (16.15)
Type "help" for help.

chetan_db=# \conninfo
You are connected to database "chetan_db" as user "chetan_user" via socket in "/var/run/postgresql" at port "5432".

chetan_db=# \dt
            List of relations
 Schema |   Name   | Type  |    Owner
--------+----------+-------+-------------
 public | comments | table | chetan_user
 public | posts    | table | chetan_user
(2 rows)


chetan_db=# select * from comments;
 id | post_id | author |  content   |         created_at
----+---------+--------+------------+----------------------------
  1 |       1 | Chetan | Nice One!! | 2026-10-15 09:02:40.110416
(1 row)

chetan_db=# select * from posts;
 id |           title           |   content   | author | emoji |         created_at         |         updated_at
----+---------------------------+-------------+--------+-------+----------------------------+----------------------------
  1 | This is the first comment | Hello World | Chetan | ✨    | 2026-10-15 09:02:21.644363 | 2026-10-15 09:02:21.644363
(1 row)
```


# Delete the EKS Cluster

```bash
eksctl delete cluster --name chetan-cluster2026 --region ap-south-1 
```

