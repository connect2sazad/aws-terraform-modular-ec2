
#!/bin/bash
set -euxo pipefail

# ==========================================
# Kubernetes kubectl Version Configuration
# ==========================================

KUBECTL_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/kubectl-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Kubernetes kubectl installation..."
echo "========================================"

if [[ -n "$KUBECTL_VERSION" ]]; then
    echo "Requested kubectl version: ${KUBECTL_VERSION}"
else
    echo "kubectl version not specified. Installing latest stable version."
fi

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y

apt-get install -y \
    ca-certificates \
    curl \
    gpg

# ==========================================
# Determine Kubernetes Version
# ==========================================

if [[ -z "$KUBECTL_VERSION" ]]; then

    echo "Fetching latest stable Kubernetes version..."

    KUBECTL_VERSION=$(
        curl -fsSL https://dl.k8s.io/release/stable.txt
    )

fi

# Remove optional v prefix
KUBECTL_VERSION="${KUBECTL_VERSION#v}"

# Extract Kubernetes minor version
K8S_MINOR_VERSION=$(
    echo "$KUBECTL_VERSION" |
    awk -F. '{print $1 "." $2}'
)

echo "Kubernetes minor version: ${K8S_MINOR_VERSION}"

# ==========================================
# Configure Kubernetes APT Repository
# ==========================================

install -m 0755 -d /etc/apt/keyrings

# Download Kubernetes official GPG key
curl -fsSL \
    "https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR_VERSION}/deb/Release.key" \
    -o /tmp/kubernetes-release.key

# Convert GPG key
gpg --dearmor --yes \
    -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    /tmp/kubernetes-release.key

chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

rm -f /tmp/kubernetes-release.key

# Add Kubernetes official APT repository
cat > /etc/apt/sources.list.d/kubernetes.list <<EOF
deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR_VERSION}/deb/ /
EOF

# ==========================================
# Update Package Lists
# ==========================================

apt-get update -y

# ==========================================
# Install kubectl
# ==========================================

if [[ "$KUBECTL_VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then

    echo "Installing latest available patch for Kubernetes ${KUBECTL_VERSION}..."

    apt-get install -y kubectl

elif [[ "$KUBECTL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

    echo "Installing exact kubectl version: ${KUBECTL_VERSION}"

    KUBECTL_PACKAGE_VERSION=$(
        apt-cache madison kubectl |
        awk -v version="$KUBECTL_VERSION" '
            {
                package_version = $3

                if (
                    package_version == version ||
                    index(package_version, version "-") == 1 ||
                    index(package_version, version "+") == 1
                ) {
                    print package_version
                    exit
                }
            }
        '
    )

    if [[ -z "$KUBECTL_PACKAGE_VERSION" ]]; then
        echo "ERROR: kubectl version ${KUBECTL_VERSION} not found."
        echo "Available versions:"
        apt-cache madison kubectl
        exit 1
    fi

    apt-get install -y "kubectl=${KUBECTL_PACKAGE_VERSION}"

else

    echo "ERROR: Invalid Kubernetes version: ${KUBECTL_VERSION}"
    echo "Expected format: 1.31 or 1.31.4"
    exit 1

fi

# ==========================================
# Verify kubectl Installation
# ==========================================

echo "========================================"
echo "Verifying kubectl installation..."
echo "========================================"

kubectl version --client

INSTALLED_KUBECTL_VERSION=$(
    kubectl version --client -o json |
    python3 -c "import json,sys; print(json.load(sys.stdin)['clientVersion']['gitVersion'])"
)

INSTALLED_KUBECTL_VERSION="${INSTALLED_KUBECTL_VERSION#v}"

echo "Requested kubectl version: ${KUBECTL_VERSION}"
echo "Installed kubectl version: ${INSTALLED_KUBECTL_VERSION}"

# Verify requested version
if [[ "$KUBECTL_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then

    if [[ "$INSTALLED_KUBECTL_VERSION" != "$KUBECTL_VERSION" ]]; then
        echo "ERROR: kubectl version mismatch!"
        exit 1
    fi

elif [[ "$INSTALLED_KUBECTL_VERSION" != "$K8S_MINOR_VERSION".* ]]; then

    echo "ERROR: Installed kubectl minor version mismatch!"
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
echo "kubectl installation successfully completed!"
echo "Installed kubectl Version: v${INSTALLED_KUBECTL_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Kubernetes kubectl installation completed successfully."
