#!/bin/bash

set -e

clear

echo "======================================"
echo "       TERRAFORM PRE-FLIGHT CHECK"
echo "======================================"
echo

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

# Initialize Terraform if not initialized
if [ ! -d ".terraform" ]; then
    echo "[1/6] Initializing Terraform..."
    terraform init
else
    echo "[1/6] Terraform already initialized. Skipping init."
fi

# Format Terraform files
echo
echo "[2/6] Formatting Terraform files..."
terraform fmt -recursive

# Validate Terraform configuration
echo
echo "[3/6] Validating Terraform configuration..."
terraform validate

# Create Terraform plan
echo
echo "[4/6] Creating Terraform plan..."
terraform plan -out=tfplan

# Apply Terraform plan
echo
echo "[5/6] Applying Terraform configuration..."
terraform apply --auto-approve tfplan

# Get EC2 public IP
echo
echo "[6/6] Fetching EC2 public IP..."

INSTANCE_IP=$(terraform output -raw instance_public_ip)

if [ -z "$INSTANCE_IP" ]; then
    echo "ERROR: Could not retrieve EC2 public IP."
    exit 1
fi

echo
echo "======================================"
echo " EC2 INSTANCE PUBLIC IP"
echo " $INSTANCE_IP"
echo "======================================"
echo

# Interactive SSH or Exit
read -n 1 -s -r -p "Press ENTER to SSH or any other key to exit..."

if [[ "$REPLY" == "" ]]; then
    echo
    echo "Connecting to Ubuntu instance..."
    ssh -i id_ed25519 ubuntu@"$INSTANCE_IP"
else
    echo
    echo "Exiting..."
    exit 0
fi
