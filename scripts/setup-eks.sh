#!/bin/bash

set -e

# ============================================================
# EKS AUTOMATION CONFIGURATION
# ============================================================

CLUSTER_NAME="chetan-cluster2026"
AWS_REGION="ap-south-1"
K8S_VERSION="1.33"

NODE_TYPE="t3.medium"
NODES=2
NODES_MIN=2
NODES_MAX=4
NODE_VOLUME_SIZE=30

LBC_POLICY_NAME="AWSLoadBalancerControllerIAMPolicy"
LBC_POLICY_FILE="/tmp/iam_policy.json"

LBC_CHART_VERSION="1.13.3"
LBC_VERSION="v2.13.3"

# ============================================================
# FUNCTIONS
# ============================================================

install_package() {
    local PACKAGE=$1

    if dpkg -s "$PACKAGE" >/dev/null 2>&1; then
        echo "✓ $PACKAGE already installed"
    else
        echo "Installing $PACKAGE..."
        sudo apt-get install -y "$PACKAGE"
    fi
}

add_bashrc_line() {
    local LINE="$1"

    grep -qxF "$LINE" ~/.bashrc 2>/dev/null || echo "$LINE" >> ~/.bashrc
}

# ============================================================
# 1. SYSTEM UPDATE
# ============================================================

echo "============================================================"
echo "1. Updating system"
echo "============================================================"

sudo apt-get update

install_package unzip
install_package curl
install_package ca-certificates
install_package gnupg
install_package apt-transport-https
install_package bash-completion

# ============================================================
# 2. AWS CLI
# ============================================================

echo "============================================================"
echo "2. Installing AWS CLI"
echo "============================================================"

if command -v aws >/dev/null 2>&1; then
    echo "✓ AWS CLI already installed"
    aws --version
else
    cd /tmp

    rm -f awscliv2.zip

    curl -fsSL \
      "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
      -o awscliv2.zip

    rm -rf aws

    unzip -q awscliv2.zip

    sudo ./aws/install

    rm -rf aws awscliv2.zip

    aws --version
fi

# ============================================================
# 3. KUBECTL
# ============================================================

echo "============================================================"
echo "3. Installing kubectl"
echo "============================================================"

if command -v kubectl >/dev/null 2>&1; then
    echo "✓ kubectl already installed"
    kubectl version --client
else

    sudo mkdir -p -m 755 /etc/apt/keyrings

    curl -fsSL \
      "https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key" |
      sudo gpg --dearmor \
      -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

    echo \
      'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' |
      sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null

    sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update

    sudo apt-get install -y kubectl bash-completion

    kubectl version --client
fi

# Kubectl completion
add_bashrc_line 'source <(kubectl completion bash)'
add_bashrc_line 'alias k=kubectl'
add_bashrc_line 'complete -F __start_kubectl k'

# ============================================================
# 4. EKSCTL
# ============================================================

echo "============================================================"
echo "4. Installing eksctl"
echo "============================================================"

if command -v eksctl >/dev/null 2>&1; then
    echo "✓ eksctl already installed"
    eksctl version
else

    cd /tmp

    ARCH="amd64"
    PLATFORM="$(uname -s)_${ARCH}"

    curl -fsSL \
      "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz" \
      -o eksctl.tar.gz

    tar -xzf eksctl.tar.gz

    sudo install -m 0755 eksctl /usr/local/bin/eksctl

    rm -f eksctl eksctl.tar.gz

    eksctl version
fi

# eksctl completion
add_bashrc_line 'source <(eksctl completion bash)'
add_bashrc_line 'alias e=eksctl'
add_bashrc_line 'complete -F __start_eksctl e'

# ============================================================
# 5. HELM
# ============================================================

echo "============================================================"
echo "5. Installing Helm"
echo "============================================================"

if command -v helm >/dev/null 2>&1; then
    echo "✓ Helm already installed"
    helm version
else

    curl -fsSL \
      https://packages.buildkite.com/helm-linux/helm-debian/gpgkey |
      gpg --dearmor |
      sudo tee /usr/share/keyrings/helm.gpg >/dev/null

    echo \
      "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" |
      sudo tee /etc/apt/sources.list.d/helm-stable-debian.list >/dev/null

    sudo apt-get update

    sudo apt-get install -y helm

    helm version
fi

# Helm completion
add_bashrc_line 'source <(helm completion bash)'
add_bashrc_line 'alias h=helm'
add_bashrc_line 'complete -F __start_helm h'

# ============================================================
# 6. AWS CONFIGURATION CHECK
# ============================================================

echo "============================================================"
echo "6. Checking AWS credentials"
echo "============================================================"

if aws sts get-caller-identity >/dev/null 2>&1; then

    echo "✓ AWS credentials are already configured"

else

    echo "AWS credentials are not configured."
    echo "Running: aws configure"
    echo ""

    aws configure
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account \
    --output text)

echo "AWS Account ID: $AWS_ACCOUNT_ID"

echo ""
aws configure list

# ============================================================
# 7. CREATE EKS CLUSTER
# ============================================================

echo "============================================================"
echo "7. Creating EKS cluster"
echo "============================================================"

if eksctl get cluster \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION" >/dev/null 2>&1; then

    echo "✓ EKS cluster already exists"

else

    eksctl create cluster \
      --name "$CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --version "$K8S_VERSION" \
      --node-type "$NODE_TYPE" \
      --nodes "$NODES" \
      --nodes-min "$NODES_MIN" \
      --nodes-max "$NODES_MAX" \
      --node-volume-size "$NODE_VOLUME_SIZE" \
      --zones "${AWS_REGION}a,${AWS_REGION}b"
fi

# ============================================================
# 8. UPDATE KUBECONFIG
# ============================================================

echo "============================================================"
echo "8. Updating kubeconfig"
echo "============================================================"

aws eks update-kubeconfig \
    --name "$CLUSTER_NAME" \
    --region "$AWS_REGION"

kubectl get nodes

# ============================================================
# 9. ASSOCIATE OIDC PROVIDER
# ============================================================

echo "============================================================"
echo "9. Associating IAM OIDC provider"
echo "============================================================"

eksctl utils associate-iam-oidc-provider \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --approve

# ============================================================
# 10. AWS LOAD BALANCER CONTROLLER IAM POLICY
# ============================================================

echo "============================================================"
echo "10. Creating AWS Load Balancer Controller IAM Policy"
echo "============================================================"

if aws iam get-policy \
    --policy-arn \
    "arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${LBC_POLICY_NAME}" \
    >/dev/null 2>&1; then

    echo "✓ IAM policy already exists"

else

    curl -fsSL \
      "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${LBC_VERSION}/docs/install/iam_policy.json" \
      -o "$LBC_POLICY_FILE"

    aws iam create-policy \
      --policy-name "$LBC_POLICY_NAME" \
      --policy-document "file://${LBC_POLICY_FILE}"

    echo "✓ IAM policy created"
fi

# ============================================================
# 11. AWS LOAD BALANCER CONTROLLER SERVICE ACCOUNT
# ============================================================

echo "============================================================"
echo "11. Creating AWS Load Balancer Controller Service Account"
echo "============================================================"

eksctl create iamserviceaccount \
    --cluster="$CLUSTER_NAME" \
    --namespace=kube-system \
    --name=aws-load-balancer-controller \
    --attach-policy-arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${LBC_POLICY_NAME}" \
    --override-existing-serviceaccounts \
    --region="$AWS_REGION" \
    --approve

# ============================================================
# 12. ADD EKS HELM REPOSITORY
# ============================================================

echo "============================================================"
echo "12. Adding EKS Helm repository"
echo "============================================================"

helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true

helm repo update

# ============================================================
# 13. INSTALL AWS LOAD BALANCER CONTROLLER
# ============================================================

echo "============================================================"
echo "13. Installing AWS Load Balancer Controller"
echo "============================================================"

if helm status aws-load-balancer-controller \
    -n kube-system >/dev/null 2>&1; then

    echo "✓ AWS Load Balancer Controller already installed"

else

    helm install aws-load-balancer-controller \
      eks/aws-load-balancer-controller \
      -n kube-system \
      --set clusterName="$CLUSTER_NAME" \
      --set serviceAccount.create=false \
      --set serviceAccount.name=aws-load-balancer-controller \
      --set region="$AWS_REGION" \
      --version "$LBC_CHART_VERSION"
fi

# ============================================================
# 14. EBS CSI DRIVER IAM SERVICE ACCOUNT
# ============================================================

echo "============================================================"
echo "14. Creating EBS CSI Driver IAM Service Account"
echo "============================================================"

eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster "$CLUSTER_NAME" \
    --region "$AWS_REGION" \
    --attach-policy-arn \
    arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve \
    --override-existing-serviceaccounts

# ============================================================
# 15. ADD EBS CSI HELM REPOSITORY
# ============================================================

echo "============================================================"
echo "15. Adding EBS CSI Helm repository"
echo "============================================================"

helm repo add aws-ebs-csi-driver \
    https://kubernetes-sigs.github.io/aws-ebs-csi-driver \
    2>/dev/null || true

helm repo update

# ============================================================
# 16. INSTALL EBS CSI DRIVER
# ============================================================

echo "============================================================"
echo "16. Installing EBS CSI Driver"
echo "============================================================"

if helm status aws-ebs-csi-driver \
    -n kube-system >/dev/null 2>&1; then

    echo "✓ EBS CSI Driver already installed"

else

    helm install aws-ebs-csi-driver \
      aws-ebs-csi-driver/aws-ebs-csi-driver \
      -n kube-system \
      --set controller.serviceAccount.create=false \
      --set controller.serviceAccount.name=ebs-csi-controller-sa
fi

# ============================================================
# 17. FINAL VERIFICATION
# ============================================================

echo ""
echo "============================================================"
echo "17. FINAL VERIFICATION"
echo "============================================================"

echo ""
echo "===== EKS CLUSTER ====="
kubectl get nodes

echo ""
echo "===== AWS LOAD BALANCER CONTROLLER ====="
kubectl get deployment \
    -n kube-system \
    aws-load-balancer-controller

echo ""
echo "===== AWS LOAD BALANCER CONTROLLER PODS ====="
kubectl get pods \
    -n kube-system \
    -l app.kubernetes.io/name=aws-load-balancer-controller

echo ""
echo "===== EBS CSI PODS ====="
kubectl get pods \
    -n kube-system |
    grep ebs

echo ""
echo "===== HELM RELEASES ====="
helm list -n kube-system

echo ""
echo "============================================================"
echo "EKS SETUP COMPLETED"
echo "============================================================"

echo ""
echo "Cluster:"
echo "$CLUSTER_NAME"

echo ""
echo "Region:"
echo "$AWS_REGION"

echo ""
echo "Account ID:"
echo "$AWS_ACCOUNT_ID"

echo ""
echo "Kubernetes:"
kubectl version --short 2>/dev/null || kubectl version --client