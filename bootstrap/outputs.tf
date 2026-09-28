output "state_bucket_name" {
  value = aws_s3_bucket.terraform_state.bucket
}

output "terraform_ci_role_arn" {
  value = aws_iam_role.gitlab_terraform.arn
}

output "ansible_ssm_bucket_name" {
  value = aws_s3_bucket.ansible_ssm.bucket
}