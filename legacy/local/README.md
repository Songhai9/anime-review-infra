# AWS VMs · native Node.js and systemd

[Current Kubernetes deployment](../../README.md) · [AWS bootstrap](../../docs/BOOTSTRAP-AWS.md) · [Variables](../../docs/CONFIGURATION.md) · [Recovered CI](../../docs/ci-history/README.md)

![VM architecture](../../docs/assets/02-vm.png)

This is the native variant of the VM phase, executed through Ansible from your workstation. For the container variant, see [legacy/vm](../vm/README.md). Run commands from the infrastructure repository root.

## 1. Scope and requirements

Four Ubuntu ARM64 EC2 instances: bastion, frontend, backend and PostgreSQL. The frontend has a public IP; the API and database remain private. Access control combines AWS routing, Security Groups and PostgreSQL's `pg_hba.conf`.

Prepare S3/OIDC foundations, Terraform 1.13, AWS CLI, Ansible, `jq`, SSH and private key `~/.ssh/anime-review`. The workstation must reach bastion port 22 and be covered by `admin_cidr`. For the Docker variant, publish two ARM64 images and obtain a `read_registry` deploy token.

This guide uses today's `legacy/vm/terraform` layout for both variants. They are **alternatives on the same VMs**: do not run systemd and Docker simultaneously on ports 3000/3001. To reproduce the exact original layout, use a separate checkout of the historical commit referenced in the CI archives.

## 2. Provision networking and machines

From the infra repository root:

```bash
cp docs/examples/vm.terraform.tfvars.example legacy/vm/terraform/terraform.tfvars
# Set admin_cidr and ssh_public_key; configure the actual S3 backend.
terraform -chdir=legacy/vm/terraform init
terraform -chdir=legacy/vm/terraform fmt -check
terraform -chdir=legacy/vm/terraform validate
terraform -chdir=legacy/vm/terraform plan -out=vm.tfplan
terraform -chdir=legacy/vm/terraform show vm.tfplan
terraform -chdir=legacy/vm/terraform apply vm.tfplan
terraform -chdir=legacy/vm/terraform output
```

The plan should match the expected VMs, VPC, subnets, routes, NAT/IGW, Security Groups, public key and Elastic IP. State key `anime-review/terraform.tfstate` is separate from the cluster's state. NAT, VMs, volumes and IP addresses may incur charges while provisioned.

| Source | Destination | Port | Purpose |
|---|---|---|---|
| Internet | Public frontend | TCP 3000 | HTTP web interface |
| Frontend | Private backend | TCP 3001 | Internal API |
| Backend | Private PostgreSQL | TCP 5432 | SQL queries |
| Admin CIDR | Bastion | TCP 22 | SSH entry point |
| Bastion | Application VMs | TCP 22 | Ansible SSH hop |
| VMs | Internet through appropriate routes | TCP 80/443 | Packages, Git, registry, AniList |

Security Groups allow source groups corresponding to the tiers, rather than opening ports to everyone. The private backend IP also restricts PostgreSQL through a `/32` rule.

## 3. Generate and inspect inventory

```bash
chmod 600 ~/.ssh/anime-review
bash legacy/vm/ansible/scripts/generate_inventory.sh
ansible-inventory -i legacy/vm/ansible/inventory/inventory.ini --graph
BASTION_IP=$(terraform -chdir=legacy/vm/terraform output -raw bastion_eip)
ssh -i ~/.ssh/anime-review "ubuntu@$BASTION_IP" 'hostname'
```

The generator uses private IPs for frontend/backend/database and an SSH `ProxyCommand` through the bastion. The `private` group contains all three tiers, including the frontend that also has a public IP. Inventory must match the **VM state** outputs, never the cluster state.

The archive disables host-key verification (`StrictHostKeyChecking=no`). This historical compromise should be corrected for a lasting environment: record verified host fingerprints in `known_hosts`, then enable strict checking.

## 4. Native variant · Node.js and systemd

After archiving, `legacy/local/scripts/` points to a Terraform directory that no longer exists. Use the freshly generated inventory from step 3 and copy it to the local inventory:

```bash
cp legacy/vm/ansible/inventory/inventory.ini legacy/local/inventory/inventory.ini
ansible-galaxy collection install community.postgresql
```

Replace the backend and database groups' two `vault.yml` files using `vault-native.yml.example`, with the **same** `vault_db_password`, then encrypt them:

```bash
ansible-vault encrypt legacy/local/inventory/group_vars/backend/vault.yml
ansible-vault encrypt legacy/local/inventory/group_vars/database/vault.yml
ansible private -i legacy/local/inventory/inventory.ini \
  --ask-vault-pass -m wait_for_connection -a 'timeout=300'
ansible-playbook -i legacy/local/inventory/inventory.ini \
  --ask-vault-pass legacy/local/playbooks/site.yml
```

Before running, check the GitLab URL hardcoded in `backend.yml` and `frontend.yml`. The VMs must be able to clone it. For a private project, provide appropriate code access without committing a plaintext token in the URL. The historical code clones `main`, not a pinned commit, so later redeployment can retrieve different code.

Order is database → backend → frontend. The database playbook installs PostgreSQL, creates `anilist_user`/`anilist_db` and configures listening and network access. The other playbooks install NodeSource 26.x, Git and ACL, create dedicated users, clone the code, run `npm ci`, and write environment files under `/etc/anime-review` and systemd units.

Native playbooks use Node 26.x, while images use Node 24. Native PostgreSQL paths are fixed to `/etc/postgresql/16/main`: confirm PostgreSQL 16 or adapt them to `SHOW config_file` / `SHOW hba_file`. The `deb822_repository` module also needs `python3-debian` on the target; if missing, install it before the playbook:

```bash
ansible 'backend:frontend' -i legacy/local/inventory/inventory.ini \
  --ask-vault-pass -b -m apt -a 'name=python3-debian state=present update_cache=true'
```

The backend has no handler guaranteeing restart after code or environment changes. During updates, explicitly restart the relevant services:

```bash
ansible backend -i legacy/local/inventory/inventory.ini --ask-vault-pass \
  -b -m systemd_service -a 'name=anime-review-api state=restarted daemon_reload=true'
ansible frontend -i legacy/local/inventory/inventory.ini --ask-vault-pass \
  -b -m systemd_service -a 'name=anime-review-frontend state=restarted daemon_reload=true'
```

## 5. Verify the native deployment

```bash
FRONTEND_IP=$(terraform -chdir=legacy/vm/terraform output -raw frontend_public_ip)
curl --fail "http://$FRONTEND_IP:3000/health"
ansible backend -i legacy/local/inventory/inventory.ini --ask-vault-pass \
  -m uri -a 'url=http://localhost:3001/ready status_code=200'
```

Inspect `systemctl status anime-review-api` / `anime-review-frontend` and `journalctl -u SERVICE_NAME` on the corresponding hosts. Perform a real browser write and verify persistence. Diagnose database failures in order: route, Security Group, listening port, `pg_hba.conf`, credentials, schema.

## CI and cleanup

No infrastructure pipeline was found at the documented native milestone. Use the manual procedure above; the recovered VM pipelines target the Docker variant. See [CI provenance](../../docs/ci-history/README.md).

Before releasing resources, back up PostgreSQL and inspect a destroy plan against the VM state only. Preserve shared S3/OIDC foundations if later deployments need them. To switch these VMs to containers, follow [the Docker guide](../vm/README.md) and stop the native application services before reusing their ports.
