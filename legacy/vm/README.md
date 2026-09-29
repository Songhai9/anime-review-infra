# AWS VMs · Docker application deployment

[Current Kubernetes deployment](../../README.md) · [AWS bootstrap](../../docs/BOOTSTRAP-AWS.md) · [Variables](../../docs/CONFIGURATION.md) · [Recovered CI](../../docs/ci-history/README.md)

![VM architecture](../../docs/assets/02-vm.png)

This is the container variant of the VM phase: frontend/API run in Docker while PostgreSQL remains native. For Node.js/systemd deployment, see [legacy/local](../local/README.md). Run commands from the infrastructure repository root.

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

## 4. Docker variant · two images, native database

Populate `legacy/vm/ansible/inventory/group_vars/all/vault.yml` from the VM Vault example. The token must provide `read_registry` access to the application registry. Set the actual `registry_image_prefix` in `all/vars.yml`, for example `registry.gitlab.com/YOUR_GROUP/YOUR_APP`.

Old Vault files in backend/database groups may still exist: they must be decryptable with the same Vault password and must not override the common secret inconsistently. If you move their values to `all/vault.yml`, remove the duplicates in your own copy after preserving anything needed.

```bash
ansible-vault encrypt legacy/vm/ansible/inventory/group_vars/all/vault.yml
ansible-galaxy collection install -r legacy/vm/ansible/requirements.yml
ansible private -i legacy/vm/ansible/inventory/inventory.ini \
  --ask-vault-pass -m wait_for_connection -a 'timeout=300'
export IMAGE_TAG=REPLACE_WITH_PUBLISHED_COMMIT_TAG
ansible-playbook -i legacy/vm/ansible/inventory/inventory.ini \
  --ask-vault-pass -e "image_tag=$IMAGE_TAG" legacy/vm/ansible/playbooks/site.yml
```

The playbook runs Docker → PostgreSQL → backend → frontend. Containers are named `anime-review-api` and `anime-review-frontend`, with `pull: always` and `restart_policy: unless-stopped`. Ansible injects the SQL connection into the API and the private API address into the frontend. Seeding is disabled. Sensitive tasks use `no_log`; registry credentials nevertheless remain a secret stored on the host for image pulls.

If the same VMs previously ran native services, stop/disable those systemd services before starting containers and check that ports are free. PostgreSQL can remain in place if its database, username and password are preserved. Back up before any update whose initialization SQL could change the schema.

## 5. Verify the result

```bash
FRONTEND_IP=$(terraform -chdir=legacy/vm/terraform output -raw frontend_public_ip)
curl --fail "http://$FRONTEND_IP:3000/health"
# Docker variant: check from the private backend through Ansible.
ansible backend -i legacy/vm/ansible/inventory/inventory.ini --ask-vault-pass \
  -m uri -a 'url=http://localhost:3001/ready status_code=200'
ansible 'frontend:backend' -i legacy/vm/ansible/inventory/inventory.ini \
  --ask-vault-pass -b -m command -a 'docker ps'
```

For native services, inspect `systemctl status anime-review-api` / `anime-review-frontend` and `journalctl -u SERVICE_NAME`. For Docker, inspect `docker logs anime-review-api` and `docker logs anime-review-frontend`. In both cases, perform a real browser write and verify persistence.

Diagnose API/database failures layer by layer: route → Security Group → listening port → `pg_hba.conf` → username/password → schema. Do not expose 5432 to the Internet to bypass an inter-tier problem.

## 6. Reactivate historical VM CI

Two infra files are supplied: the original September 18 version (`terraform/`, `ansible/`) and today's archive (`legacy/vm/...`). Select the latter for today's directory layout. Place it at a dedicated path and select that path under **Settings → CI/CD → General pipelines → CI/CD configuration file**, or deliberately replace the root configuration on a branch dedicated to this phase.

Configure `AWS_ROLE_ARN`, `TF_VAR_admin_cidr`, `TF_VAR_ssh_public_key`, `SSH_PRIVATE_KEY` (File) and `ANSIBLE_VAULT_PASSWORD_FILE` (File). In the application project, enable `phase2-vm.gitlab-ci.yml`, which forwards `IMAGE_TAG`.

The VM runner must reach the bastion from an authorized CIDR. A personal workstation `/32` is insufficient for a SaaS runner with changing outbound addresses: use a runner with known egress or adapt the access architecture. SSM belongs to the cluster phase and is not implemented in this old VM pipeline.

This CI automatically applies the plan and runs Ansible only when `IMAGE_TAG` is supplied. It declares a `test` stage without a job. These are properties of the archive, not safety or validation guarantees added later. A standalone infra pipeline can provision resources without deploying the application.

## 7. Shutdown and cleanup

To release this phase's resources, inspect a destroy plan for the VM state only. Back up PostgreSQL first and verify that the targeted resources belong to the demonstration. Preserve S3/OIDC bootstrap if subsequent phases use it. Deleting VMs is not a backup mechanism.
