#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform"
INVENTORY_DIR="$SCRIPT_DIR/../inventory"

cd $TERRAFORM_DIR

BASTION_EIP=$(terraform output -json | jq -r '.bastion_eip.value')
BASTION_PRIVATE_IP=$(terraform output -json | jq -r '.bastion_private_ip.value')
FRONTEND_PUBLIC_IP=$(terraform output -json | jq -r '.frontend_public_ip.value')
FRONTEND_PRIVATE_IP=$(terraform output -json | jq -r '.frontend_private_ip.value')
BACKEND_PRIVATE_IP=$(terraform output -json | jq -r '.backend_private_ip.value')
DATABASE_PRIVATE_IP=$(terraform output -json | jq -r '.database_private_ip.value')

cd $INVENTORY_DIR

cat > inventory.ini <<EOF
[bastion]
$BASTION_EIP

[frontend]
$FRONTEND_PRIVATE_IP

[backend]
$BACKEND_PRIVATE_IP

[database]
$DATABASE_PRIVATE_IP
EOF