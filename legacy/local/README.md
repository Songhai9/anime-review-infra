# Local VM configuration

First version of the application deployment.

This configuration is run manually from a local workstation.

Architecture:
- Terraform provisions the AWS VMs
- Ansible configures the VMs
- Node.js is installed directly on the hosts
- The application code is cloned from GitLab
- The frontend and backend applications are run with systemd

This version is kept to document the project's evolution.
The active version used by CI/CD is located in `/ansible`.