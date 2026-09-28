provider "aws" {
  region = var.aws_region
}

terraform {
  backend "s3" {
    bucket       = "songhai9-anime-review-tfstate-0909-eu-north-1"
    key          = "anime-review/bootstrap.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}