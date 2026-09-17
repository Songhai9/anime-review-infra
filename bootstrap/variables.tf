variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "admin_cidr" {
  type = string
}

variable "state_bucket_name" {
  type = string
}