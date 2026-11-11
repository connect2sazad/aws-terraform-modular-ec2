
#!/bin/bash
set -euxo pipefail

# ==========================================
# AWS CLI Version Configuration
# ==========================================

AWSCLI_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/awscli-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting AWS CLI v2 installation..."
echo "========================================"

if [[ -n "$AWSCLI_VERSION" ]]; then
    echo "Requested AWS CLI version: ${AWSCLI_VERSION}"
else
    echo "AWS CLI version not specified. Installing latest available version."
fi

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y

apt-get install -y \
    curl \
    unzip

# ==========================================
# Detect System Architecture
# ==========================================

ARCH=$(uname -m)

case "$ARCH" in
    x86_64)
        AWS_ARCH="x86_64"
        ;;
    aarch64)
        AWS_ARCH="aarch64"
        ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

echo "Detected architecture: ${AWS_ARCH}"

# ==========================================
# Create Temporary Directory
# ==========================================

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# ==========================================
# Download AWS CLI v2
# ==========================================

if [[ -n "$AWSCLI_VERSION" ]]; then

    echo "Installing requested AWS CLI version: ${AWSCLI_VERSION}"

    DOWNLOAD_URL="https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}-${AWSCLI_VERSION}.zip"

else

    echo "Installing latest AWS CLI v2..."

    DOWNLOAD_URL="https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"

fi

echo "Download URL: ${DOWNLOAD_URL}"

curl -fsSL \
    --retry 3 \
    --retry-delay 2 \
    "$DOWNLOAD_URL" \
    -o "$TMP_DIR/awscliv2.zip"

# ==========================================
# Extract AWS CLI Installer
# ==========================================

unzip -q "$TMP_DIR/awscliv2.zip" -d "$TMP_DIR"

# ==========================================
# Install or Update AWS CLI
# ==========================================

if command -v aws >/dev/null 2>&1; then

    echo "Existing AWS CLI detected. Updating installation..."

    "$TMP_DIR/aws/install" --update

else

    echo "Installing AWS CLI..."

    "$TMP_DIR/aws/install"

fi

# ==========================================
# Verify AWS CLI Installation
# ==========================================

echo "========================================"
echo "Verifying AWS CLI installation..."
echo "========================================"

aws --version

INSTALLED_AWSCLI_VERSION=$(
    aws --version 2>&1 |
    sed -nE 's/^aws-cli\/([^ ]+).*/\1/p'
)

echo "Installed AWS CLI version: ${INSTALLED_AWSCLI_VERSION}"

if [[ -z "$INSTALLED_AWSCLI_VERSION" ]]; then
    echo "ERROR: Unable to determine installed AWS CLI version."
    exit 1
fi

# Verify requested version if provided
if [[ -n "$AWSCLI_VERSION" ]]; then

    if [[ "$INSTALLED_AWSCLI_VERSION" != "$AWSCLI_VERSION" ]]; then
        echo "ERROR: AWS CLI version mismatch!"
        echo "Expected: ${AWSCLI_VERSION}"
        echo "Installed: ${INSTALLED_AWSCLI_VERSION}"
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
echo "AWS CLI installation successfully completed!"
echo "Installed Version: ${INSTALLED_AWSCLI_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "AWS CLI v2 installation completed successfully."
