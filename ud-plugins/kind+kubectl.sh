#!/bin/bash
set -euxo pipefail

# Log all output for troubleshooting
exec > >(tee -a /var/log/docker-install.log) 2>&1

echo "Starting Docker installation..."

# Update package lists
apt-get update -y

# Install required packages
apt-get install -y ca-certificates curl

# Add Docker's official GPG key
install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc

chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker's official repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  > /etc/apt/sources.list.d/docker.list

# Update package lists again
apt-get update -y

# Install Docker Engine and plugins
apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Start Docker and enable it at boot
systemctl enable docker
systemctl start docker

# Add the default Ubuntu user to the Docker group
if id ubuntu &>/dev/null; then
  usermod -aG docker ubuntu
fi

# Verify installation
docker --version
docker compose version
systemctl is-active docker

echo "Docker installation and configuration completed successfully."

# ========================================
# Go Language
# ========================================

apt-get install -y golang-go

echo "Go installation completed."

# ========================================
# Kubernetes kubectl
# ========================================

K8S_VERSION="v1.31"

curl -fsSL \
  "https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/Release.key" \
  | gpg --dearmor --yes -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

chmod a+r /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo \
  "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${K8S_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y

apt-get install -y kubectl

echo "Kubectl installation completed."

# ========================================
# Kind Kubernetes
# ========================================

KIND_VERSION="v0.26.0"

curl -fLo /usr/local/bin/kind \
  "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"

chmod +x /usr/local/bin/kind

echo "Kind installation completed."

# ========================================
# Verification
# ========================================

echo "Verifying installations..."

docker --version
go version
kubectl version --client
kind --version

echo "========================================"
echo "All installations completed successfully."
echo "========================================"
