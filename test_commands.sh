cd terraform && terraform apply -auto-approve && cd .. && sh ansible/scripts/generate_inventory.sh && cat ansible/inventory/inventory.ini

ssh -o StrictHostKeyChecking=accept-new \             
  -J ubuntu@16.192.105.78 \
  ubuntu@10.0.3.171

ssh -o StrictHostKeyChecking=accept-new \             
  -i ~/.ssh/anime-review \ 
  ubuntu@16.192.105.78
