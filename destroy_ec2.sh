#!/bin/bash

# ======================================
# COLORS
# ======================================

RED='\033[1;31m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
NC='\033[0m'

clear

# ======================================
# FIRST: CONFIRMATION
# ======================================

echo "=========================================="
echo
echo "      TERRAFORM INFRASTRUCTURE"
echo
echo -e "              ${RED}DESTROY${NC}"
echo
echo "=========================================="
echo
echo -e "${YELLOW}WARNING: This will permanently destroy${NC}"
echo -e "${YELLOW}all infrastructure managed by Terraform.${NC}"
echo
echo "=========================================="
echo

read -r -p "Are you SURE you want to DESTROY? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" && "$CONFIRM" != "YES" ]]; then
    echo
    echo -e "${GREEN}DESTROY CANCELLED${NC}"
    echo "No checks or destroy operations performed."
    exit 0
fi

# ======================================
# PRE-FLIGHT CHECKS
# ======================================

set -e

echo
echo -e "${BLUE}[CHECK] Terraform...${NC}"

if ! command -v terraform >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Terraform is not installed.${NC}"
    exit 1
fi

terraform version

# Check Terraform files
echo
echo -e "${BLUE}[CHECK] Terraform Configuration...${NC}"

if ! compgen -G "*.tf" >/dev/null; then
    echo -e "${RED}ERROR: No Terraform .tf files found.${NC}"
    exit 1
fi

echo -e "${GREEN}Terraform files found.${NC}"

# Initialize Terraform
if [ ! -d ".terraform" ]; then
    echo
    echo "Initializing Terraform..."
    terraform init
fi

# Validate Terraform
echo
echo "Validating Terraform configuration..."
terraform validate

# ======================================
# DESTROY INFRASTRUCTURE
# ======================================

echo
echo "=========================================="
echo -e "       ${RED}DESTROYING INFRASTRUCTURE${NC}"
echo "=========================================="
echo

if terraform destroy --auto-approve; then

    echo
    echo "=========================================="
    echo
    echo -e "       ${GREEN}DESTROY SUCCESSFUL!${NC}"
    echo
    echo "=========================================="
    echo
    echo "All Terraform-managed resources destroyed."

else

    echo
    echo "=========================================="
    echo
    echo -e "          ${RED}DESTROY FAILED!${NC}"
    echo
    echo "=========================================="
    exit 1

fi
