variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "admin_cidr" {
  type = string
}

variable "ssh_public_key" {
  description = "Public SSH key used for EC2 instances"
  type        = string
}