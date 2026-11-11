
#!/bin/bash
set -euxo pipefail

# ==========================================
# Kind Version Configuration
# ==========================================

KIND_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/kind_k8s-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Kind installation..."
echo "========================================"

if [[ -n "$KIND_VERSION" ]]; then
    echo "Requested Kind version: ${KIND_VERSION}"
else
    echo "Kind version not specified. Installing latest stable version."
fi

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y
apt-get install -y curl ca-certificates

# ==========================================
# Detect System Architecture
# ==========================================

ARCH=$(dpkg --print-architecture)

case "$ARCH" in
    amd64)
        KIND_ARCH="amd64"
        ;;
    arm64)
        KIND_ARCH="arm64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: ${KIND_ARCH}"

# ==========================================
# Determine Kind Version
# ==========================================

if [[ -z "$KIND_VERSION" ]]; then

    echo "Fetching latest stable Kind version..."

    KIND_VERSION=$(
        curl -fsSL https://api.github.com/repos/kubernetes-sigs/kind/releases/latest |
        grep '"tag_name"' |
        head -n 1 |
        sed -E 's/.*"tag_name": "v?([^"]+)".*/\1/'
    )

fi

# Remove optional v prefix
KIND_VERSION="${KIND_VERSION#v}"

if [[ -z "$KIND_VERSION" ]]; then
    echo "ERROR: Unable to determine Kind version."
    exit 1
fi

echo "Installing Kind version: v${KIND_VERSION}"

# ==========================================
# Download Kind Binary
# ==========================================

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

DOWNLOAD_URL="https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-linux-${KIND_ARCH}"

echo "Downloading: ${DOWNLOAD_URL}"

curl -fsSL \
    --retry 3 \
    --retry-delay 2 \
    -o "$TMP_DIR/kind" \
    "$DOWNLOAD_URL"

# ==========================================
# Install Kind
# ==========================================

install -m 0755 "$TMP_DIR/kind" /usr/local/bin/kind

# ==========================================
# Verify Kind Installation
# ==========================================

echo "========================================"
echo "Verifying Kind installation..."
echo "========================================"

kind version

INSTALLED_KIND_VERSION=$(
    kind version |
    awk '{print $2}' |
    sed 's/^v//'
)

echo "Requested Kind version: ${KIND_VERSION}"
echo "Installed Kind version: ${INSTALLED_KIND_VERSION}"

if [[ "$INSTALLED_KIND_VERSION" != "$KIND_VERSION" ]]; then
    echo "ERROR: Kind version mismatch!"
    echo "Expected: ${KIND_VERSION}"
    echo "Installed: ${INSTALLED_KIND_VERSION}"
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
echo "Kind installation successfully completed!"
echo "Installed Kind Version: v${INSTALLED_KIND_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Kind Kubernetes installation completed successfully."
