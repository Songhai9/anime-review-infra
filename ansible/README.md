# Containerized CI/CD deployment

Active Ansible configuration used by GitLab CI.

Architecture:
- Terraform provisions the infrastructure
- GitLab CI runs Ansible
- Ansible prepares the Docker hosts
- Application images are retrieved from the Container Registry
- Frontend and backend are run as containers