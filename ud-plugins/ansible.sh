
#!/bin/bash
set -euxo pipefail

# ==========================================
# Ansible Version Configuration
# ==========================================

ANSIBLE_VERSION="${PLUGIN_VERSION:-}"

# Set timezone to GMT/UTC for logging
export TZ=UTC

# Log directory
LOG_DIR="/home/ubuntu/aws-terraform-modular-ec2/logs"
mkdir -p "$LOG_DIR"

# Log all output with GMT timestamps
exec > >(while IFS= read -r line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S GMT')] $line"
done | tee -a "$LOG_DIR/ansible-install.log") 2>&1

# Record installation start time
START_TIME=$(date +%s%3N)

echo "========================================"
echo "Starting Ansible installation..."
echo "========================================"

if [[ -n "$ANSIBLE_VERSION" ]]; then
    echo "Requested Ansible version: ${ANSIBLE_VERSION}"
else
    echo "Ansible version not specified. Installing latest available version."
fi

# ==========================================
# Install System Dependencies
# ==========================================

apt-get update -y

apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-full

# ==========================================
# Create Python Virtual Environment
# ==========================================

VENV_PATH="/opt/ansible-venv"

python3 -m venv "$VENV_PATH"

# Upgrade pip
"$VENV_PATH/bin/pip" install --upgrade pip

# ==========================================
# Install Ansible
# ==========================================

if [[ -n "$ANSIBLE_VERSION" ]]; then

    echo "Installing Ansible version: ${ANSIBLE_VERSION}"

    "$VENV_PATH/bin/pip" install "ansible==${ANSIBLE_VERSION}"

else

    echo "Installing latest Ansible version..."

    "$VENV_PATH/bin/pip" install ansible

fi

# ==========================================
# Install AWS Python Dependencies
# ==========================================

echo "Installing Boto3 and Botocore..."

"$VENV_PATH/bin/pip" install boto3 botocore

# ==========================================
# Install AWS Ansible Collection
# ==========================================

echo "Installing amazon.aws Ansible collection..."

"$VENV_PATH/bin/ansible-galaxy" collection install amazon.aws

# ==========================================
# Verify Ansible Installation
# ==========================================

echo "========================================"
echo "Verifying Ansible installation..."
echo "========================================"

"$VENV_PATH/bin/ansible" --version

INSTALLED_ANSIBLE_VERSION=$(
    "$VENV_PATH/bin/ansible" --version |
    awk 'NR==1 {print $2}'
)

echo "Installed Ansible version: ${INSTALLED_ANSIBLE_VERSION}"

# Verify requested version
if [[ -n "$ANSIBLE_VERSION" ]]; then

    if [[ "$INSTALLED_ANSIBLE_VERSION" != "$ANSIBLE_VERSION" ]]; then
        echo "ERROR: Ansible version mismatch!"
        echo "Expected: ${ANSIBLE_VERSION}"
        echo "Installed: ${INSTALLED_ANSIBLE_VERSION}"
        exit 1
    fi

fi

# ==========================================
# Verify Boto3 and Botocore
# ==========================================

"$VENV_PATH/bin/python" -c "
import boto3
import botocore

print('Boto3 version:', boto3.__version__)
print('Botocore version:', botocore.__version__)
"

# ==========================================
# Verify AWS Ansible Collection
# ==========================================

"$VENV_PATH/bin/ansible-galaxy" collection list amazon.aws

# ==========================================
# Installation Duration
# ==========================================

END_TIME=$(date +%s%3N)
DURATION=$((END_TIME - START_TIME))

MINUTES=$((DURATION / 60000))
SECONDS=$(((DURATION % 60000) / 1000))
MILLISECONDS=$((DURATION % 1000))

echo "========================================"
echo "Ansible installation successfully completed!"
echo "Ansible Version: ${INSTALLED_ANSIBLE_VERSION}"
echo "Installation Duration: ${MINUTES}m ${SECONDS}s ${MILLISECONDS}ms"
echo "========================================"

echo "Ansible, Boto3, Botocore and AWS collection installation completed successfully."
