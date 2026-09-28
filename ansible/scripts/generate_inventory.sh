#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform"
INVENTORY_DIR="$SCRIPT_DIR/../inventory"

: "${ANSIBLE_SSM_BUCKET:?ANSIBLE_SSM_BUCKET must be set}"

cd "$TERRAFORM_DIR"

CONTROL_PLANE_INSTANCE_ID=$(terraform output -raw control_plane_instance_id)
CONTROL_PLANE_PRIVATE_IP=$(terraform output -raw control_plane_private_ip)

WORKER_1_INSTANCE_ID=$(terraform output -json | jq -r '.worker_instance_ids.value.worker_1')
WORKER_2_INSTANCE_ID=$(terraform output -json | jq -r '.worker_instance_ids.value.worker_2')

WORKER_1_PRIVATE_IP=$(terraform output -json | jq -r '.worker_private_ips.value.worker_1')
WORKER_2_PRIVATE_IP=$(terraform output -json | jq -r '.worker_private_ips.value.worker_2')

mkdir -p "$INVENTORY_DIR"

cat > "$INVENTORY_DIR/inventory.ini" <<EOF
[control_plane]
control-plane ansible_host=$CONTROL_PLANE_INSTANCE_ID node_private_ip=$CONTROL_PLANE_PRIVATE_IP

[workers]
worker-1 ansible_host=$WORKER_1_INSTANCE_ID node_private_ip=$WORKER_1_PRIVATE_IP
worker-2 ansible_host=$WORKER_2_INSTANCE_ID node_private_ip=$WORKER_2_PRIVATE_IP

[k8s_nodes:children]
control_plane
workers

[k8s_nodes:vars]
ansible_connection=amazon.aws.aws_ssm
ansible_aws_ssm_region=eu-north-1
ansible_aws_ssm_bucket_name=$ANSIBLE_SSM_BUCKET
EOF