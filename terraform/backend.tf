terraform {
  backend "s3" {
    bucket       = "songhai9-anime-review-tfstate-0909-eu-north-1"
    key          = "anime-review/terraform.tfstate"
    region       = "eu-north-1"
    encrypt      = true
    use_lockfile = true
  }
}