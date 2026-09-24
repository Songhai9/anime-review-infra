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

variable "ssh_public_key" {
  description = "Public SSH key used by the bastion and Kubernetes nodes"
  type        = string
}

variable "bastion_instance_type" {
  description = "EC2 instance type for the bastion"
  type        = string
  default     = "t4g.micro"
}

variable "kubernetes_instance_type" {
  description = "EC2 instance type for Kubernetes nodes"
  type        = string
  default     = "t4g.small"
}

variable "availability_zone" {
  type = string
}