# Recovered VM infrastructure pipelines

[Home](../../README.md) · [VM deployment](../../legacy/vm/README.md)

| File | Exact source | Compatible layout |
|---|---|---|
| [phase2-vm-original.gitlab-ci.yml](phase2-vm-original.gitlab-ci.yml) | [2453347 · September 18, 2026](https://github.com/Songhai9/anime-review-infra/blob/2453347ba57230ac0f0f8f4802a0b47bb7092362/.gitlab-ci.yml) | Historical commit's `terraform/`, `ansible/` |
| [phase2-vm-archive.gitlab-ci.yml](phase2-vm-archive.gitlab-ci.yml) | [legacy/.gitlab-ci.yml at e5a4214](https://github.com/Songhai9/anime-review-infra/blob/e5a4214925891bf2143dcd7c4199917a06c9df56/legacy/.gitlab-ci.yml) | Today's `legacy/vm/terraform`, `legacy/vm/ansible` |

Both files are exact copies with verified Git blob hashes. The second already contains the repository's archival path adjustments; it is not a rewrite created for this package.

## Activation

The historical file still exists at `legacy/.gitlab-ci.yml`, but GitLab does not activate it automatically. For VMs on today's layout, select this path, or the supplied copy, under **Settings → CI/CD → General pipelines → CI/CD configuration file**. Alternatively, use a dedicated branch whose root file is the VM pipeline, consistently updating `main` rules and OIDC trust if the branch changes.

**Do not copy the original version to the current repository root without restoring its original layout**: today's `terraform/` provisions Kubernetes, while the old directory provisioned three-tier VMs. This is a real resource difference, not a documentation-only rename.

## Preserved variables and behavior

`AWS_ROLE_ARN`, `TF_VAR_admin_cidr`, `TF_VAR_ssh_public_key`; File variables `SSH_PRIVATE_KEY` and `ANSIBLE_VAULT_PASSWORD_FILE`; application-forwarded `IMAGE_TAG`. The expected CI image is `ci-image:1.0`; publish/make it available or explicitly adapt the reference. The archive runs validate → plan → automatic apply, then configures only when IMAGE_TAG exists. Its test stage contains no job.

The archived bastion SSH connection disables host-key verification. The runner must be allowed by the Security Group. Possible improvements—manual apply, strict host-key checking, final tests or SSM—have not been silently added to these recovered copies.

## Manual native phase

The complete tree at [df149c9 on September 16, 2026](https://github.com/Songhai9/anime-review-infra/tree/df149c994ddce677b1083ef843922d7da6e67a95), after native playbook orchestration, contains no CI/pipeline/workflow file. Terraform and Ansible commands ran from the workstation. No `.gitlab-ci.yml` specific to that milestone was found, so no invented pipeline is supplied as a “historical” artifact.

Today's active root `.gitlab-ci.yml` is for Kubernetes. Corresponding application archives are included in the app repository package.
