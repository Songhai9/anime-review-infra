terraform {
  backend "s3" {
    bucket       = "songhai9-anime-review-tfstate"
    key          = "anime-review/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}