#!/bin/sh

ansible -m ping all

ansible-galaxy collection install \
  -r ansible/requirements.yml

ansible-playbook \
  -i ansible/inventory/inventory.ini \
  ansible/playbooks/common.yml