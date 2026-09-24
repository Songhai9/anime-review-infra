#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../../terraform"
INVENTORY_DIR="$SCRIPT_DIR/../inventory"
GENERATE_INVENTORY_SCRIPT="$SCRIPT_DIR/../scripts/generate_inventory.sh"

terraform -chdir="$TERRAFORM_DIR" apply -auto-approve

sh "$GENERATE_INVENTORY_SCRIPT"

cat "$INVENTORY_DIR/inventory.ini"

ssh-add ~/.ssh/anime-review


# Example IP address
ssh -o StrictHostKeyChecking=accept-new \
  -i ~/.ssh/anime-review \
  -J ubuntu@51.21.65.114 \
  ubuntu@10.0.1.63

ssh -o StrictHostKeyChecking=accept-new \
  -i ~/.ssh/anime-review \
  ubuntu@16.192.105.78