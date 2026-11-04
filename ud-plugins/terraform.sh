
#!/bin/bash
set -euxo pipefail

# ==========================================
# Terraform Version Configuration
# ==========================================

TERRAFORM_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/terraform-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Terraform installation..."
echo "========================================"

if [[ -n "$TERRAFORM_VERSION" ]]; then
    echo "Requested Terraform version: ${TERRAFORM_VERSION}"
else
    echo "Terraform version not specified. Installing latest available version."
fi

# ==========================================
# Install Required Packages
# ==========================================

apt-get update -y

apt-get install -y \
    ca-certificates \
    curl \
    gnupg

# ==========================================
# Configure HashiCorp APT Repository
# ==========================================

install -m 0755 -d /usr/share/keyrings

# Download and install HashiCorp GPG key
curl -fsSL https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor --yes \
    -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

chmod a+r /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add official HashiCorp APT repository
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") main" \
    > /etc/apt/sources.list.d/hashicorp.list

# ==========================================
# Update Package Lists
# ==========================================

apt-get update -y

# ==========================================
# Install Terraform
# ==========================================

if [[ -n "$TERRAFORM_VERSION" ]]; then

    echo "Installing requested Terraform version: ${TERRAFORM_VERSION}"

    # Find requested Terraform package version
    TERRAFORM_PACKAGE_VERSION=$(
        apt-cache madison terraform |
        awk -v version="$TERRAFORM_VERSION" '
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

    if [[ -z "$TERRAFORM_PACKAGE_VERSION" ]]; then
        echo "ERROR: Terraform version ${TERRAFORM_VERSION} not found."
        echo "Available Terraform versions:"
        apt-cache madison terraform
        exit 1
    fi

    echo "Resolved Terraform package version: ${TERRAFORM_PACKAGE_VERSION}"

    apt-get install -y "terraform=${TERRAFORM_PACKAGE_VERSION}"

else

    echo "Installing latest Terraform version..."

    apt-get install -y terraform

fi

# ==========================================
# Verify Terraform Installation
# ==========================================

echo "========================================"
echo "Verifying Terraform installation..."
echo "========================================"

terraform version

INSTALLED_TERRAFORM_VERSION=$(
    terraform version -json |
    python3 -c "import json,sys; print(json.load(sys.stdin)['terraform_version'])"
)

echo "Requested Terraform version: ${TERRAFORM_VERSION:-latest}"
echo "Installed Terraform version: ${INSTALLED_TERRAFORM_VERSION}"

# Verify requested version
if [[ -n "$TERRAFORM_VERSION" ]]; then

    if [[ "$INSTALLED_TERRAFORM_VERSION" != "$TERRAFORM_VERSION" ]]; then
        echo "ERROR: Terraform version mismatch!"
        echo "Expected: ${TERRAFORM_VERSION}"
        echo "Installed: ${INSTALLED_TERRAFORM_VERSION}"
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
echo "Terraform installation successfully completed!"
echo "Installed Terraform Version: ${INSTALLED_TERRAFORM_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Terraform installation completed successfully."
