# Prepare the operator workstation

[Home](../README.md) · [AWS foundations](BOOTSTRAP-AWS.md)

Local application development does not need this repository: see `legacy/local/README.md` in `anime-review-app`. This page is for operating the AWS phases from a workstation (written for macOS; the Linux commands are the same apart from the package manager).

## 1 · Tools

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform python@3.12 awscli jq
brew install --cask session-manager-plugin
```

Terraform comes from the HashiCorp tap: the `terraform` formula in Homebrew core stopped at 1.5.x, and this project needs at least **1.10** (`use_lockfile`). The CI uses 1.13.

```bash
terraform version
aws --version
jq --version
session-manager-plugin --version
```

An SSH client is only needed for the bastion and for the legacy VM phases. Docker is only needed to build the GitLab runner image.

## 2 · Python virtual environment for Ansible

Create the venv explicitly from the Homebrew Python. A pyenv shim or the system Python can produce an environment where Ansible, boto3 and the SSM plugin do not see the same interpreter.

```bash
"$(brew --prefix python@3.12)/bin/python3.12" -m venv .venv
source .venv/bin/activate

python -m pip install --upgrade pip
python -m pip install ansible boto3 'botocore[crt]'
ansible-galaxy collection install -r ansible/requirements.yml
```

| Package | Why |
|---|---|
| `ansible` | playbooks |
| `boto3` / `botocore` | used by the `amazon.aws.aws_ssm` connection plugin (S3 transfer, SSM sessions) |
| `[crt]` extra | needed when the AWS profile comes from `aws login` (console credentials) or SSO: without it, boto3 cannot read those credentials |
| `amazon.aws`, `community.general` | collections from `ansible/requirements.yml` |

`.venv/` is git-ignored. These dependencies are not pinned in the repository, so write down the versions you used (`pip freeze`, `ansible --version`).

On macOS, Ansible's forked workers can crash when the Objective-C runtime is initialized after `fork()`. Export this in the session (it is in `operator.env`):

```bash
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES
```

## 3 · AWS authentication

Use a profile with administrative rights on the account. With the AWS CLI's console login:

```bash
aws login --profile YOUR_PROFILE
```

With IAM Identity Center, use `aws sso login --profile YOUR_PROFILE` instead.

Copy [`examples/operator.env.example`](examples/operator.env.example) to `~/.config/anime-review/operator.env` (outside Git), fill it, then load it in every new shell:

```bash
. ~/.config/anime-review/operator.env
aws sts get-caller-identity          # the Account must be the project account
```

Two buckets, two roles. Do not mix them up:

| Bucket | Role | Used by |
|---|---|---|
| state bucket (`state_bucket_name`) | Terraform state of `bootstrap/` and `terraform/` | backend blocks only |
| transfer bucket (`ansible_ssm_bucket_name`) | Ansible SSM file transfer, `k8s-bootstrap/` archives | `ANSIBLE_SSM_BUCKET`, `K8S_TRANSFER_BUCKET` |

Export the profile and region explicitly. A profile whose default region is another one does not override the `eu-north-1` values hard-coded in the project. CI jobs never use a local profile: they receive credentials through OIDC.

## 4 · SSH key for the bastion

`terraform/` still provisions a bastion, so it requires `ssh_public_key` and `admin_cidr`:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/anime-review
cat ~/.ssh/anime-review.pub          # value for ssh_public_key
curl -s https://checkip.amazonaws.com # your IP, used as admin_cidr = "x.x.x.x/32"
```

The private key stays on the workstation. Ansible and the CI do not use it for the Kubernetes nodes: they go through SSM.

Next: [AWS foundations](BOOTSTRAP-AWS.md), then [Deploy the cluster](../README.md#deploy-the-cluster).
