# AWS foundations · account, identity, buckets and state

[Home](../README.md) · [Variables](CONFIGURATION.md)

Run this procedure from the infra repository with an administrative identity authorized to create the resources. It distinguishes a new account from an existing installation to avoid creating two states that claim ownership of the same resources.

## 1. Choose names before starting

Populate `bootstrap/terraform.tfvars` from `docs/examples/bootstrap.terraform.tfvars.example`: actual AWS account, region `eu-north-1`, infra GitLab path, a globally unique state bucket name and a separate Ansible/SSM bucket name.

The original code contains account/project names in several places. Find them and replace only the values belonging to your installation:

```bash
rg -n '429502077256|songhai9|anilist-cicd|eu-north-1' bootstrap terraform ansible ci .gitlab-ci.yml legacy/vm
```

State uses three different S3 keys:

| Purpose | S3 key |
|---|---|
| Persistent foundations | `anime-review/bootstrap.tfstate` |
| VM deployment | `anime-review/terraform.tfstate` |
| kubeadm cluster | `anime-review/kubernetes.tfstate` |

Never reuse the same key for VM and cluster resources. Update bucket names in the **Git-tracked backend blocks** so CI can use them too. A local `-backend-config` argument does not change runner configuration.

## 2. Create or verify the GitLab OIDC provider

The repository uses a `data "aws_iam_openid_connect_provider"` lookup: it expects an existing provider. In AWS IAM → Identity providers, verify/create an OpenID Connect provider with URL `https://gitlab.com` and audience `sts.amazonaws.com`.

Once `AWS_ACCOUNT_ID` is set, verify through the CLI:

```bash
aws iam get-open-id-connect-provider \
  --open-id-connect-provider-arn "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/gitlab.com"
```

The infra role allows the exact subject `project_path:YOUR_GROUP/YOUR_INFRA:ref_type:branch:ref:main` and audience `sts.amazonaws.com`. The K8s role separately embeds its GitLab project path in `terraform/main.tf`; update it too if projects are renamed. Keep `main` consistent across branches, trust policies and pipelines. See the [official GitLab OIDC/AWS procedure](https://docs.gitlab.com/ci/cloud_services/aws/).

## 3A. First bootstrap in a new account

The backend block in `bootstrap/providers.tf` points to the bucket that `bootstrap/main.tf` creates. Resolve this circular dependency before the first `init`.

1. In your working copy, temporarily remove **only** the `backend "s3" { ... }` sub-block from `bootstrap/providers.tf`. Keep `required_providers` and the AWS provider.
2. Populate `bootstrap/terraform.tfvars` with both bucket names and the account ID. Check the AWS profile.
3. Initialize with local state, inspect the plan, then create the foundations:

```bash
terraform -chdir=bootstrap init
terraform -chdir=bootstrap validate
terraform -chdir=bootstrap plan -out=bootstrap.tfplan
terraform -chdir=bootstrap show bootstrap.tfplan
terraform -chdir=bootstrap apply bootstrap.tfplan
terraform -chdir=bootstrap output
```

4. Restore the S3 backend block with the newly created bucket, key `anime-review/bootstrap.tfstate`, region, `encrypt=true` and `use_lockfile=true`.
5. Migrate local state to S3 and accept the copy when Terraform prompts:

```bash
terraform -chdir=bootstrap init -migrate-state
terraform -chdir=bootstrap state list
terraform -chdir=bootstrap plan
```

Understand the final plan and ensure it does not unexpectedly recreate resources. Then inspect the S3 objects. Do not commit local state, plan files or backups: they can contain sensitive data. `terraform init -backend=false` alone does not establish a correct persistent bootstrap installation.

## 3B. Existing foundations

Do not follow 3A when remote state already manages these resources. Set the actual backend bucket, run `terraform -chdir=bootstrap init`, and plan using the correct profile. If resources exist without corresponding state, establish ownership and import them into the intended state before applying. An existing bucket name does not prove this project manages it.

## 4. What bootstrap creates

- State bucket: public access blocked, SSE-S3 encryption, versioning enabled and `prevent_destroy=true`. This protection applies to Terraform, not every possible deletion through AWS.
- Ansible/SSM bucket: public access blocked, encryption and `force_destroy=true`. It transfers modules and files and is separate from state; do not use it for permanent backups.
- `GitLabAnimeReviewTerraformRole`: OIDC trust and permissions for Terraform, EC2, NLB, project-related IAM, S3 and SSM sessions. Permissions are broad; this is not a strict least-privilege example.

The Terraform backend must read/write its state object and manage the `.tflock` lock. This project's S3 locking does not require a DynamoDB table. The three states remain independent.

## 5. Prepare infra CI

Set the infra project's GitLab `AWS_ROLE_ARN` variable to the `terraform_ci_role_arn` output. Set `ANSIBLE_SSM_BUCKET` to the transfer bucket and supply mandatory Terraform variables `TF_VAR_admin_cidr` and `TF_VAR_ssh_public_key`. For a renamed account/project setup, also update CI registry paths and trust policies.

Build and publish the tools image **before** running CI that references it:

```bash
export CI_IMAGE='registry.gitlab.com/YOUR_GROUP/YOUR_INFRA/ci-image:1.1'
# Authenticate to the registry with a token allowed to push.
docker buildx build --platform linux/amd64 -f ci/Dockerfile -t "$CI_IMAGE" --push .
```

The Dockerfile downloads x86_64 AWS CLI and Session Manager binaries, so the runner must be compatible. The target ARM64 EC2 instances do not run this image. Align CI's `default.image.name` with the published image. If the CI registry is private, the runner must be able to pull the image before the job starts.

## 6. PostgreSQL parameter for Kubernetes

Neither bootstrap nor cluster Terraform creates `/anime-review/postgres/password`. Create it in Systems Manager → Parameter Store as a **SecureString** in `eu-north-1`, using your chosen password. Do not print it in logs or place its literal value in a versioned script.

The identity executing `bootstrap-cluster.sh` must be able to read and decrypt this parameter, with the necessary KMS permissions when using a customer-managed key. The CI role `k8s-cd` is not automatically passed to the control plane. However, its EC2 profile already has `ssm:GetParameter` through `AmazonSSMManagedInstanceCore`; verify effective permissions, KMS and any account restrictions. The K8s guide provides a concrete execution path. [Official AWS policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonSSMManagedInstanceCore.html).

## 7. Foundation checks

```bash
aws sts get-caller-identity
aws s3api get-bucket-versioning --bucket YOUR_STATE_BUCKET
aws s3api get-public-access-block --bucket YOUR_STATE_BUCKET
aws s3api get-bucket-encryption --bucket YOUR_STATE_BUCKET
aws s3api head-bucket --bucket YOUR_ANSIBLE_SSM_BUCKET
# Read metadata only, without the secret value:
aws ssm describe-parameters \
  --parameter-filters 'Key=Name,Option=Equals,Values=/anime-review/postgres/password'
```

Preserve foundation state during a cluster rebuild. If an interrupted operation leaves a lock, first verify that no Terraform process is still active. Use `force-unlock` only with a confirmed orphaned lock ID and the correct backend. A 412 error does not justify arbitrarily deleting state.
