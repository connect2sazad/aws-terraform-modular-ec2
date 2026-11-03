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