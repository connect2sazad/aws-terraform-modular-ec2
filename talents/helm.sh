
#!/bin/bash
set -euxo pipefail

# ==========================================
# Helm Version Configuration
# ==========================================

HELM_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/helm-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Helm installation..."
echo "========================================"

if [[ -n "$HELM_VERSION" ]]; then
    echo "Requested Helm version: ${HELM_VERSION}"
else
    echo "Helm version not specified. Installing latest available version."
fi

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y

apt-get install -y \
    curl \
    gpg \
    ca-certificates

# ==========================================
# Helm Repository Configuration
# ==========================================

# Expected official Helm APT signing key fingerprint
HELM_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

# Temporary directory
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Create APT keyrings directory
install -m 0755 -d /etc/apt/keyrings

# Download Helm repository signing key
curl -fsSL \
    https://packages.buildkite.com/helm-linux/helm-debian/gpgkey \
    -o "$TMP_DIR/helm.asc"

# Verify GPG key fingerprint
ACTUAL_KEY_ID=$(
    gpg --show-keys --with-colons "$TMP_DIR/helm.asc" |
    awk -F: '$1 == "fpr" {print $10; exit}'
)

if [[ "$ACTUAL_KEY_ID" != "$HELM_KEY_ID" ]]; then
    echo "ERROR: Helm GPG key fingerprint verification failed."
    echo "Expected: ${HELM_KEY_ID}"
    echo "Actual:   ${ACTUAL_KEY_ID}"
    exit 1
fi

echo "Helm GPG signing key verified successfully."

# Install verified GPG key
install -m 0644 "$TMP_DIR/helm.asc" /etc/apt/keyrings/helm.asc

# Configure Helm APT repository
cat > /etc/apt/sources.list.d/helm-stable-debian.sources <<EOF
Types: deb
URIs: https://packages.buildkite.com/helm-linux/helm-debian/any/
Suites: any
Components: main
Signed-By: /etc/apt/keyrings/helm.asc
EOF

# ==========================================
# Update Package Lists
# ==========================================

apt-get update -y

# ==========================================
# Install Helm
# ==========================================

if [[ -n "$HELM_VERSION" ]]; then

    echo "Installing requested Helm version: ${HELM_VERSION}"

    # Find exact requested Helm version
    HELM_PACKAGE_VERSION=$(
        apt-cache madison helm |
        awk -v version="$HELM_VERSION" '
            {
                package_version = $3

                if (
                    index(package_version, version "-") == 1 ||
                    index(package_version, version "+") == 1 ||
                    index(package_version, version "~") == 1 ||
                    package_version == version
                ) {
                    print package_version
                    exit
                }
            }
        '
    )

    if [[ -z "$HELM_PACKAGE_VERSION" ]]; then
        echo "ERROR: Helm version ${HELM_VERSION} not found."
        echo "Available Helm versions:"
        apt-cache madison helm
        exit 1
    fi

    echo "Resolved Helm package version: ${HELM_PACKAGE_VERSION}"

    # Install specific Helm version
    apt-get install -y "helm=${HELM_PACKAGE_VERSION}"

else

    echo "Installing latest available Helm version..."

    # Install latest Helm version
    apt-get install -y helm

fi

# ==========================================
# Verify Helm Installation
# ==========================================

echo "========================================"
echo "Verifying Helm installation..."
echo "========================================"

helm version

INSTALLED_HELM_VERSION=$(
    helm version --template '{{.Version}}'
)

echo "Requested Helm version: ${HELM_VERSION:-latest}"
echo "Installed Helm version: ${INSTALLED_HELM_VERSION}"

if [[ -n "$HELM_VERSION" ]]; then

    if [[ "$INSTALLED_HELM_VERSION" != "v${HELM_VERSION}"* ]]; then
        echo "ERROR: Helm version mismatch!"
        echo "Expected: v${HELM_VERSION}"
        echo "Installed: ${INSTALLED_HELM_VERSION}"
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
echo "Helm installation successfully completed!"
echo "Installed Version: ${INSTALLED_HELM_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Helm installation completed successfully."
