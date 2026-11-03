#!/bin/bash

set -e

clear

echo "======================================"
echo "       TERRAFORM PRE-FLIGHT CHECK"
echo "======================================"
echo

# ======================================
# PRE-FLIGHT CHECKS
# ======================================

# Check Terraform
echo "[CHECK] Terraform..."
if ! command -v terraform >/dev/null 2>&1; then
    echo "ERROR: Terraform is not installed."
    exit 1
fi
terraform version

# Check AWS CLI
echo
echo "[CHECK] AWS CLI..."
if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: AWS CLI is not installed."
    exit 1
fi
aws --version

# Check AWS credentials
echo
echo "[CHECK] AWS Credentials..."
if ! aws sts get-caller-identity; then
    echo "ERROR: AWS credentials invalid or not configured."
    exit 1
fi

# Check SSH client
echo
echo "[CHECK] SSH Client..."
if ! command -v ssh >/dev/null 2>&1; then
    echo "ERROR: SSH client is not installed."
    exit 1
fi
ssh -V

# Check private key
echo
echo "[CHECK] SSH Private Key..."
if [ ! -f "id_ed25519" ]; then
    echo "ERROR: id_ed25519 private key not found."
    exit 1
fi
echo "SSH private key found."

# Check Terraform configuration
echo
echo "[CHECK] Terraform Configuration..."
if ! compgen -G "*.tf" >/dev/null; then
    echo "ERROR: No Terraform .tf files found."
    exit 1
fi
echo "Terraform configuration files found."

echo
echo "======================================"
echo "       ALL CHECKS PASSED"
echo "======================================"
echo

# ======================================
# TERRAFORM DEPLOYMENT
# ======================================

# Initialize Terraform if not initialized
if [ ! -d ".terraform" ]; then
    echo "[1/6] Initializing Terraform..."
    if ! terraform init; then
        echo "ERROR: Terraform initialization failed."
        exit 1
    fi
else
    echo "[1/6] Terraform already initialized. Skipping init."
fi

# Format Terraform files
echo
echo "[2/6] Formatting Terraform files..."
if ! terraform fmt -recursive; then
    echo "ERROR: Terraform formatting failed."
    exit 1
fi

# Validate Terraform configuration
echo
echo "[3/6] Validating Terraform configuration..."
if ! terraform validate; then
    echo "ERROR: Terraform validation failed."
    exit 1
fi

# Create Terraform plan
echo
echo "[4/6] Creating Terraform plan..."
if ! terraform plan -out=tfplan; then
    echo "ERROR: Terraform plan failed."
    exit 1
fi

# Apply Terraform plan
echo
echo "[5/6] Applying Terraform configuration..."
if ! terraform apply --auto-approve tfplan; then
    echo "ERROR: Terraform apply failed."
    echo "Infrastructure deployment may be incomplete."
    exit 1
fi

# ======================================
# DEPLOYMENT SUCCESSFUL
# ======================================

echo
echo "======================================"
echo "    TERRAFORM DEPLOYMENT SUCCESSFUL!"
echo "======================================"
echo

# ======================================
# GET EC2 PUBLIC IP
# ======================================

echo "[6/6] Fetching EC2 public IP..."

INSTANCE_IP=$(terraform output -json instance_public_ip 2>/dev/null | jq -r '.[0] // empty' 2>/dev/null || true)

if [ -z "$INSTANCE_IP" ] || [ "$INSTANCE_IP" = "null" ]; then
    echo
    echo "WARNING: Could not retrieve EC2 public IP."
    echo "Infrastructure was deployed successfully."
    echo "Run: terraform output instance_public_ip"
    exit 0
fi

echo
echo "======================================"
echo " EC2 INSTANCE PUBLIC IP"
echo " $INSTANCE_IP"
echo "======================================"
echo

# ======================================
# SSH OR EXIT
# ======================================

read -n 1 -s -r -p "Press ENTER to SSH or any other key to exit..."

if [[ "$REPLY" == "" ]]; then
    echo
    echo "Connecting to Ubuntu instance..."
    echo

    if ssh -i id_ed25519 ubuntu@"$INSTANCE_IP"; then
        echo
        echo "SSH session completed."
    else
        echo
        echo "WARNING: SSH connection failed."
        echo "Infrastructure remains deployed successfully."
    fi
else
    echo
    echo "Exiting..."
fi

# ======================================
# POST DEPLOYMENT COMPLETED
# ======================================

echo
echo "======================================"
echo "       DEPLOYMENT COMPLETED"
echo "======================================"
echo "Terraform infrastructure deployed successfully."
echo
