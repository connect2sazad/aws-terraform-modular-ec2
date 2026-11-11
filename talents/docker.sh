
#!/bin/bash
set -euxo pipefail

# ==========================================
# Docker Version Configuration
# ==========================================

DOCKER_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/docker-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Docker installation..."
echo "========================================"

if [[ -n "$DOCKER_VERSION" ]]; then
    echo "Requested Docker version: ${DOCKER_VERSION}"
else
    echo "Docker version not specified. Installing latest available version."
fi

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

# ==========================================
# Install Docker
# ==========================================

if [[ -n "$DOCKER_VERSION" ]]; then

    echo "Installing requested Docker version: ${DOCKER_VERSION}"

    # Find the requested Docker package version
    DOCKER_PACKAGE_VERSION=$(
      apt-cache madison docker-ce |
      awk -v version="$DOCKER_VERSION" '
        index($3, ":" version "-") > 0 {
          print $3
          exit
        }
      '
    )

    if [[ -z "$DOCKER_PACKAGE_VERSION" ]]; then
        echo "ERROR: Docker version ${DOCKER_VERSION} not found."
        echo "Available versions:"
        apt-cache madison docker-ce
        exit 1
    fi

    echo "Resolved package version: ${DOCKER_PACKAGE_VERSION}"

    # Install specific Docker version
    apt-get install -y \
      "docker-ce=${DOCKER_PACKAGE_VERSION}" \
      "docker-ce-cli=${DOCKER_PACKAGE_VERSION}" \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin

else

    echo "Installing latest available Docker version..."

    # Install latest Docker version
    apt-get install -y \
      docker-ce \
      docker-ce-cli \
      containerd.io \
      docker-buildx-plugin \
      docker-compose-plugin

fi

# ==========================================
# Docker Service Configuration
# ==========================================

# Enable Docker at boot
systemctl enable docker

# Start Docker
systemctl start docker

# Add Ubuntu user to Docker group
if id ubuntu &>/dev/null; then
    usermod -aG docker ubuntu
fi

# ==========================================
# Verify Docker Installation
# ==========================================

echo "========================================"
echo "Verifying Docker installation..."
echo "========================================"

docker --version
docker compose version
docker buildx version

systemctl is-active docker

INSTALLED_DOCKER_VERSION=$(
    docker --version | awk '{print $3}' | tr -d ','
)

echo "Installed Docker version: ${INSTALLED_DOCKER_VERSION}"

# Verify requested version if provided
if [[ -n "$DOCKER_VERSION" ]]; then

    if [[ "$INSTALLED_DOCKER_VERSION" != "$DOCKER_VERSION" ]]; then
        echo "ERROR: Docker version mismatch!"
        echo "Expected: ${DOCKER_VERSION}"
        echo "Installed: ${INSTALLED_DOCKER_VERSION}"
        exit 1
    fi

fi

# ==========================================
# Installation Duration
# ==========================================

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

MINUTES=$((DURATION / 60000))
SECONDS=$(((DURATION % 60000) / 1000))
MILLISECONDS=$((DURATION % 1000))

echo "========================================"
echo "Docker installation successfully completed!"
echo "Docker Version: ${INSTALLED_DOCKER_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Docker installation and configuration completed successfully."
