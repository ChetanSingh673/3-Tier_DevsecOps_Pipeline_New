#!/bin/bash

set -e

echo "=========================================="
echo " Ubuntu DevSecOps Server Setup"
echo "=========================================="

# ------------------------------------------
# 1. UPDATE SYSTEM
# ------------------------------------------

echo "[1/6] Updating Ubuntu..."

sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt upgrade -y


# ------------------------------------------
# 2. BASIC PACKAGES
# ------------------------------------------

echo "[2/6] Installing basic packages..."

sudo apt install -y \
    bash-completion \
    wget \
    git \
    zip \
    unzip \
    curl \
    jq \
    net-tools \
    build-essential \
    ca-certificates \
    apt-transport-https \
    gnupg \
    fontconfig \
    software-properties-common \
    lsb-release


# ------------------------------------------
# 3. GIT
# ------------------------------------------

echo "[3/6] Installing latest Git..."

sudo add-apt-repository -y ppa:git-core/ppa
sudo apt update -y
sudo apt install -y git

echo "Git:"
git --version


# ------------------------------------------
# 4. JAVA 21
# ------------------------------------------

echo "[4/6] Installing Java 21..."

sudo apt install -y openjdk-21-jdk

echo "Java:"
java --version


# ------------------------------------------
# 5. JENKINS
# ------------------------------------------

echo "[5/6] Installing Jenkins..."

sudo mkdir -p /etc/apt/keyrings

sudo wget -O /etc/apt/keyrings/jenkins-keyring.asc \
    https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" \
| sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

sudo apt update -y
sudo apt install -y jenkins

sudo systemctl enable jenkins
sudo systemctl start jenkins

echo "Jenkins:"
sudo systemctl is-active jenkins


# ------------------------------------------
# 6. DOCKER
# ------------------------------------------

echo "[6/6] Installing Docker..."

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update -y

sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

# Allow current user to use Docker
sudo usermod -aG docker "$USER"

# Allow Jenkins to use Docker
sudo usermod -aG docker jenkins

sudo systemctl restart jenkins

echo "Docker:"
sudo systemctl is-active docker

echo "Docker version:"
sudo docker --version


# ------------------------------------------
# 7. TRIVY
# ------------------------------------------

echo "Installing Trivy..."

sudo mkdir -p /etc/apt/keyrings

curl -fsSL \
    https://aquasecurity.github.io/trivy-repo/deb/public.key \
    | sudo gpg --dearmor \
    -o /etc/apt/keyrings/trivy.gpg

echo "deb [signed-by=/etc/apt/keyrings/trivy.gpg] \
https://aquasecurity.github.io/trivy-repo/deb \
$(lsb_release -sc) main" \
| sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null

sudo apt update -y
sudo apt install -y trivy

echo "Trivy:"
trivy --version


# ------------------------------------------
# 8. SONARQUBE
# ------------------------------------------

echo "Installing SonarQube..."

sudo docker volume create sonarqube_data
sudo docker volume create sonarqube_logs
sudo docker volume create sonarqube_extensions

if sudo docker ps -a --format '{{.Names}}' | grep -q '^sonarqube$'; then

    echo "SonarQube container already exists."

    sudo docker start sonarqube 2>/dev/null || true

else

    sudo docker run -d \
        --name sonarqube \
        --restart unless-stopped \
        -p 9000:9000 \
        -v sonarqube_data:/opt/sonarqube/data \
        -v sonarqube_logs:/opt/sonarqube/logs \
        -v sonarqube_extensions:/opt/sonarqube/extensions \
        sonarqube:lts-community

fi


# ------------------------------------------
# FINAL CHECK
# ------------------------------------------

echo ""
echo "=========================================="
echo " Installation Completed"
echo "=========================================="

echo ""
echo "Git:"
git --version

echo ""
echo "Java:"
java --version

echo ""
echo "Docker:"
sudo docker --version

echo ""
echo "Trivy:"
trivy --version

echo ""
echo "Jenkins:"
sudo systemctl is-active jenkins

echo ""
echo "Docker:"
sudo systemctl is-active docker

echo ""
echo "SonarQube:"
sudo docker ps --filter name=sonarqube

echo ""
echo "=========================================="
echo " Jenkins Initial Admin Password"
echo "=========================================="

if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
fi

echo ""
echo "=========================================="
echo " Access"
echo "=========================================="

echo "Jenkins  : http://SERVER-IP:8080"
echo "SonarQube: http://SERVER-IP:9000"

echo ""
echo "IMPORTANT:"
echo "Logout/login or run 'newgrp docker'"
echo "to use Docker without sudo."

echo ""
echo "Setup completed successfully."