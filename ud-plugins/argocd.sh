
#!/bin/bash
set -euxo pipefail

# ==========================================
# Argo CD Version Configuration
# ==========================================

ARGOCD_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/argocd-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Argo CD CLI installation..."
echo "========================================"

if [[ -n "$ARGOCD_VERSION" ]]; then
    echo "Requested Argo CD version: v${ARGOCD_VERSION}"
else
    echo "Argo CD version not specified. Installing latest stable version."
fi

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y

apt-get install -y \
    curl \
    ca-certificates

# ==========================================
# Detect System Architecture
# ==========================================

ARCH=$(dpkg --print-architecture)

case "$ARCH" in
    amd64)
        ARGO_ARCH="amd64"
        ;;
    arm64)
        ARGO_ARCH="arm64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: ${ARGO_ARCH}"

# ==========================================
# Determine Argo CD Version
# ==========================================

if [[ -z "$ARGOCD_VERSION" ]]; then

    echo "Fetching latest stable Argo CD version..."

    ARGOCD_VERSION=$(curl -fsSL \
        https://raw.githubusercontent.com/argoproj/argo-cd/stable/VERSION)

fi

# Remove optional v prefix
ARGOCD_VERSION="${ARGOCD_VERSION#v}"

echo "Installing Argo CD CLI version: v${ARGOCD_VERSION}"

# ==========================================
# Download Argo CD CLI
# ==========================================

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

DOWNLOAD_URL="https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-${ARGO_ARCH}"

echo "Downloading from: ${DOWNLOAD_URL}"

curl -fsSL \
    --retry 3 \
    --retry-delay 2 \
    -o "$TMP_DIR/argocd" \
    "$DOWNLOAD_URL"

# ==========================================
# Install Argo CD CLI
# ==========================================

install -m 0755 "$TMP_DIR/argocd" /usr/local/bin/argocd

# ==========================================
# Verify Installation
# ==========================================

echo "========================================"
echo "Verifying Argo CD CLI installation..."
echo "========================================"

argocd version --client

INSTALLED_ARGOCD_VERSION=$(
    argocd version --client |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' |
    head -n 1 |
    sed 's/^v//'
)

echo "Requested Argo CD version: ${ARGOCD_VERSION}"
echo "Installed Argo CD version: ${INSTALLED_ARGOCD_VERSION}"

if [[ "$INSTALLED_ARGOCD_VERSION" != "$ARGOCD_VERSION" ]]; then
    echo "ERROR: Argo CD version mismatch!"
    exit 1
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
echo "Argo CD CLI installation successfully completed!"
echo "Installed Version: v${INSTALLED_ARGOCD_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Argo CD CLI installation completed successfully."
