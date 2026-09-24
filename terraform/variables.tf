variable "aws_region" {
  description = "AWS region where the Kubernetes cluster is deployed"
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Project name used in resource names and tags"
  type        = string
  default     = "anime-review"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the cluster VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "kubernetes_subnet_cidr" {
  description = "CIDR block for the private Kubernetes subnet"
  type        = string
  default     = "10.0.10.0/24"
}

variable "admin_cidr" {
  description = "CIDR allowed to access the bastion over SSH"
  type        = string
}

variable "availability_zone" {
  description = "Availability Zone used by the public and Kubernetes subnets"
  type        = string
  default     = "eu-north-1a"
}