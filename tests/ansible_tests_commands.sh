#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)"
ANSIBLE_DIR="$SCRIPT_DIR/../ansible"

INVENTORY_FILE="$ANSIBLE_DIR/inventory/inventory.ini"
REQUIREMENTS_FILE="$ANSIBLE_DIR/requirements.yml"
COMMON_PLAYBOOK="$ANSIBLE_DIR/playbooks/common.yml"
CONTROL_PLANE_PLAYBOOK="$ANSIBLE_DIR/playbooks/control-plane.yml"

ansible all \
  -i "$INVENTORY_FILE" \
  -m ping

ansible-galaxy collection install \
  -r "$REQUIREMENTS_FILE"

ansible-playbook \
  -i "$INVENTORY_FILE" \
  "$COMMON_PLAYBOOK"

ansible-playbook \
  -i "$INVENTORY_FILE" \
  "$CONTROL_PLANE_PLAYBOOK"

# Kubernetes tests

ansible control_plane \
  -i "$INVENTORY_FILE" \
  -a "kubectl get nodes -o wide"

ansible control_plane \
  -i "$INVENTORY_FILE" \
  -a "kubectl get pods -n kube-system"

ansible control_plane \
  -i "$INVENTORY_FILE" \
  -b \
  -m shell \
  -a "ss -lntp | grep 6443"