#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform"
INVENTORY_DIR="$SCRIPT_DIR/../inventory"

cd "$TERRAFORM_DIR"

BASTION_EIP=$(terraform output -json | jq -r '.bastion_eip.value')
# BASTION_PRIVATE_IP=$(terraform output -json | jq -r '.bastion_private_ip.value')
# FRONTEND_PUBLIC_IP=$(terraform output -json | jq -r '.frontend_public_ip.value')
FRONTEND_PRIVATE_IP=$(terraform output -json | jq -r '.frontend_private_ip.value')
BACKEND_PRIVATE_IP=$(terraform output -json | jq -r '.backend_private_ip.value')
DATABASE_PRIVATE_IP=$(terraform output -json | jq -r '.database_private_ip.value')

mkdir -p "$INVENTORY_DIR"

cd "$INVENTORY_DIR"

cat > inventory.ini <<EOF
[bastion]
$BASTION_EIP

[frontend]
$FRONTEND_PRIVATE_IP

[backend]
$BACKEND_PRIVATE_IP

[database]
$DATABASE_PRIVATE_IP

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/anime-review

[private:children]
frontend
backend
database

[private:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ~/.ssh/anime-review -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@$BASTION_EIP"'

EOF