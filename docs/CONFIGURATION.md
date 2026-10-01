# Variables, files and identities

[Home](../README.md) · [AWS bootstrap](BOOTSTRAP-AWS.md)

## Local files to prepare

| Supplied example | Destination in your repository copy | Purpose |
|---|---|---|
| `docs/examples/bootstrap.terraform.tfvars.example` | `bootstrap/terraform.tfvars` | Buckets and infra role |
| `docs/examples/kubernetes.terraform.tfvars.example` | `terraform/terraform.tfvars` | Cluster and bastion |
| `docs/examples/vm.terraform.tfvars.example` | `legacy/vm/terraform/terraform.tfvars` | Historical VMs |
| `docs/examples/vault-native.yml.example` | `vault.yml` in both backend and database groups under `legacy/local/inventory/group_vars/` | Same SQL password in both groups |
| `docs/examples/vault-vm.yml.example` | `legacy/vm/ansible/inventory/group_vars/all/vault.yml` | DB password and registry deploy token |
| `docs/examples/operator.env.example` | Personal file outside Git | AWS profile, region, transfer bucket |
| `docs/examples/gitlab-ci-variables.env.example` | Nowhere: copy values into GitLab **Settings → CI/CD → Variables** | Per-project CI variables |

The plaintext `vault*.example` files contain placeholders only. Populate and **encrypt** each `vault.yml` copy with Ansible Vault before committing it. The historical repository already has encrypted Vault files: these examples cannot recover their old password or contents. Replace/re-encrypt the relevant files for your environment, or use the original Vault password if you have it. Do not retain an unreadable old Vault file in the inventory and assume an `-e` override will prevent it from being loaded.

## GitLab variables

| Project / phase | Variable | GitLab type | Expected value / source |
|---|---|---|---|
| Infra, all AWS CI | `AWS_ROLE_ARN` | Variable | `bootstrap.terraform_ci_role_arn` output |
| Infra | `TF_VAR_admin_cidr` | Variable | Allowed public IP `/32`; the VM runner must also reach the bastion |
| Infra | `TF_VAR_ssh_public_key` | Variable, one line | Public key contents, not its file path |
| Infra cluster | `ANSIBLE_SSM_BUCKET` | Set in `.gitlab-ci.yml` | Transfer bucket created by bootstrap |
| Infra cluster | `REBUILD_CLUSTER` | Pipeline variable (Run pipeline) | `true` forces apply → configure → verify → bootstrap_k8s; default `false` |
| Historical VM infra | `SSH_PRIVATE_KEY` | **File** | OpenSSH private key with a final newline |
| Historical VM infra | `ANSIBLE_VAULT_PASSWORD_FILE` | **File** | Vault encryption password |
| VM infra | `IMAGE_TAG` | Forwarded variable | Image SHA from application CI |
| K8s | `AWS_ROLE_ARN` | Variable | `terraform.k8s_cd_arn` output, separate from the infra role |
| K8s | `IMAGE_TAG` | Forwarded variable | Short SHA from application CI; written to both chart image tags |
| K8s | `BACKEND_IMAGE`, `FRONTEND_IMAGE` | Forwarded, **unused** | The chart keeps repositories in `values.yaml` |
| K8s | `BOOTSTRAP_CLUSTER` | Forwarded by `bootstrap_k8s` | Needs a matching job in the k8s pipeline (see k8s README) |
| K8s | `K8S_TRANSFER_BUCKET` | Set in `.gitlab-ci.yml` | Same bucket as `ANSIBLE_SSM_BUCKET` |

Protect deployment variables and their corresponding branch. Mask secrets when their format permits it; a multiline key should primarily be protected and stored as a File variable. The name `ANSIBLE_VAULT_PASSWORD_FILE` does not create a file automatically: GitLab's File type makes the job variable contain a temporary file path. Do not pass raw secret contents where `--vault-password-file` expects a path.

Terraform automatically reads `TF_VAR_*`. Local `terraform.tfvars` files normally stay out of Git, so their values are not available in CI. Optional fields have defaults, including project-specific values. A backend bucket cannot be replaced through `TF_VAR_state_bucket_name`: configure the backend itself.

## GitHub Actions variables and secrets

| Repository | Name | Kind | Value |
|---|---|---|---|
| infra | `AWS_ROLE_ARN`, `AWS_REGION`, `ANSIBLE_SSM_BUCKET`, `TF_VAR_ADMIN_CIDR`, `TF_VAR_SSH_PUBLIC_KEY` | variables | same values as on GitLab |
| infra | `K8S_WORKFLOW_TOKEN` | secret | fine-grained PAT, anime-review-k8s, *Actions: read and write* |
| infra | environment `infrastructure` | setting | required reviewers = approval before `apply` |
| k8s | `AWS_ROLE_ARN` (= `k8s_cd_arn`), `AWS_REGION`, `K8S_TRANSFER_BUCKET` | variables | see the k8s README |
| app | `K8S_WORKFLOW_TOKEN` | secret | same kind of PAT |

GitHub variables are not secrets: they are visible to anyone with write access and in logs. Keep real secrets (the PAT) in *Secrets*.

## Which identity uses which secret?

| Identity | Purpose | Preparation |
|---|---|---|
| Workstation AWS profile | Bootstrap and manual operations | AWS authentication outside the repository |
| Job OIDC token (GitLab `id_tokens`, GitHub `id-token: write`) | STS exchange for an AWS role | Exact audience and trust subject in IAM |
| `CI_JOB_TOKEN` / `GITHUB_TOKEN` | Downstream pipeline, values push, GHCR push | Supplied by the platform; configure cross-project and push permissions |
| `K8S_WORKFLOW_TOKEN` (GitHub PAT) | Dispatch and follow the k8s workflow from app/infra | Fine-grained, one repository, *Actions: read and write*, with an expiry |
| Registry deploy token | Durable VM or K8s image pulls | `read_registry`, with managed expiration and rotation |
| Human Git token | Private clone/push from a workstation | Git credential manager, separate from registry and AWS |
| Vault password | Decrypt VM Ansible secrets | Protected local file or GitLab File variable |
| PostgreSQL password | SQL connections | Vault on VMs; Parameter Store → Secret in K8s |

Ansible SSM uses the Session Manager plugin, instance IAM profiles and an S3 transfer bucket. SSM Run Command, used by K8s CI, is a different mechanism: `StartSession` permission does not replace `SendCommand`. See the [Ansible SSM connection documentation](https://docs.ansible.com/projects/ansible/latest/collections/amazon/aws/aws_ssm_connection.html).

## Hardcoded values to inspect

Region and AZ; backend bucket names; CI's `ANSIBLE_SSM_BUCKET`; GitLab paths in trust policies and triggers; image prefixes; instance lookup name `anime-review-control-plane`; SSM parameter and region in `bootstrap-cluster.sh`; SQL username and database in K8s manifests.

Renaming `project_name` can change the EC2 tag expected by K8s CI. Changing the Terraform variable without updating the deployment's `tag:Name` filter can target the wrong instance.
