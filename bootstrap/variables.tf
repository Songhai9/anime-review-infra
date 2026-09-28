variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "state_bucket_name" {
  type = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = "429502077256"
}

variable "gitlab_infra_project_path" {
  description = "GitLab project allowed to assume the Terraform CI role"
  type        = string
  default     = "anilist-cicd/anilist-infra"
}

variable "ansible_ssm_bucket_name" {
  description = "Temporary S3 bucket used by Ansible over AWS SSM"
  type        = string
  default     = "songhai9-anime-review-ansible-ssm-0909-eu-north-1"
}