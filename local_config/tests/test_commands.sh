cd terraform && terraform apply -auto-approve && cd .. && sh ./scripts/generate_inventory.sh && cat ./inventory/inventory.ini

ssh-add ~/.ssh/anime-review

ssh -o StrictHostKeyChecking=accept-new -i ~/.ssh/anime-review -J ubuntu@51.21.65.114 ubuntu@10.0.1.63 # private IP example of hosts

ssh -o StrictHostKeyChecking=accept-new -i ~/.ssh/anime-review ubuntu@16.192.105.78 # Public IP of the bastion
