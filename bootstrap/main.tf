resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

data "aws_iam_openid_connect_provider" "gitlab" {
  url = "https://gitlab.com"
}

resource "aws_iam_role" "gitlab_terraform" {
  name = "GitLabAnimeReviewTerraformRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRoleWithWebIdentity"

        Principal = {
          Federated = data.aws_iam_openid_connect_provider.gitlab.arn
        }

        Condition = {
          StringEquals = {
            "gitlab.com:aud" = "sts.amazonaws.com"
            "gitlab.com:sub" = "project_path:${var.gitlab_infra_project_path}:ref_type:branch:ref:main"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "gitlab_terraform" {
  name = "GitLabAnimeReviewTerraformRolePolicy"
  role = aws_iam_role.gitlab_terraform.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid      = "TerraformEC2Infrastructure"
        Effect   = "Allow"
        Action   = ["ec2:*"]
        Resource = "*"
      },
      {
        Sid      = "TerraformElasticLoadBalancing"
        Effect   = "Allow"
        Action   = ["elasticloadbalancing:*"]
        Resource = "*"
      },
      {
        Sid    = "TerraformIAMRead"
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetInstanceProfile",
          "iam:GetOpenIDConnectProvider",
          "iam:ListOpenIDConnectProviders",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole"
        ]
        Resource = "*"
      },
      {
        Sid    = "TerraformIAMProjectRoles"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy"
        ]
        Resource = [
          "arn:aws:iam::${var.aws_account_id}:role/anime-review-*",
          "arn:aws:iam::${var.aws_account_id}:role/k8s-cd"
        ]
      },
      {
        Sid    = "TerraformIAMInstanceProfiles"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile"
        ]
        Resource = "arn:aws:iam::${var.aws_account_id}:instance-profile/anime-review-*"
      },
      {
        Sid      = "TerraformPassEC2Roles"
        Effect   = "Allow"
        Action   = ["iam:PassRole"]
        Resource = "arn:aws:iam::${var.aws_account_id}:role/anime-review-*"

        Condition = {
          StringEquals = {
            "iam:PassedToService" = "ec2.amazonaws.com"
          }
        }
      },
      {
        Sid    = "TerraformStateBucketAccess"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.terraform_state.arn
      },
      {
        Sid    = "TerraformStateObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${aws_s3_bucket.terraform_state.arn}/anime-review/*"
      }
    ]
  })
} 