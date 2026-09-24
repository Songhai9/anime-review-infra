#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform"
INVENTORY_DIR="$SCRIPT_DIR/../inventory"

cd "$TERRAFORM_DIR"

BASTION_EIP=$(terraform output -raw bastion_public_ip)
CONTROL_PLANE_PRIVATE_IP=$(terraform output -raw control_plane_private_ip)
WORKER_1_PRIVATE_IP=$(terraform output -json | jq -r '.worker_private_ips.value.worker_1')
WORKER_2_PRIVATE_IP=$(terraform output -json | jq -r '.worker_private_ips.value.worker_2')

mkdir -p "$INVENTORY_DIR"

cd "$INVENTORY_DIR"

cat > inventory.ini <<EOF
[bastion]
$BASTION_EIP

[control_plane]
control-plane ansible_host=$CONTROL_PLANE_PRIVATE_IP

[workers]
worker-1 ansible_host=$WORKER_1_PRIVATE_IP
worker-2 ansible_host=$WORKER_2_PRIVATE_IP

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/anime-review

[k8s_nodes:children]
control_plane
workers

[k8s_nodes:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand="ssh -i ~/.ssh/anime-review -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p ubuntu@$BASTION_EIP"'

EOF