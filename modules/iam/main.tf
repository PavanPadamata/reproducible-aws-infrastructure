# Lets GitHub Actions run Terraform against AWS without stored access keys.
#
# How it works: each workflow run receives a short-lived signed token from
# GitHub. AWS checks the token against the OIDC provider created below, and
# if the token's claims satisfy a role's trust policy, hands back temporary
# credentials. Nothing long-lived exists to leak or rotate. See ADR 0006
# and ADR 0009.
#
# Policies are built with jsonencode instead of aws_iam_policy_document so
# the exact JSON is plain configuration, which keeps it readable and lets
# the tests inspect it.

data "aws_caller_identity" "current" {}

# Used only when create_github_oidc_provider is false: an account can hold
# one provider per URL, so reuse the existing one.
data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1

  url = "https://${local.oidc_host}"
}

locals {
  account_id = data.aws_caller_identity.current.account_id
  oidc_host  = "token.actions.githubusercontent.com"

  iam_arn          = "arn:aws:iam::${local.account_id}"
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket_name}"

  oidc_provider_arn = coalesce(
    one(aws_iam_openid_connect_provider.github[*].arn),
    one(data.aws_iam_openid_connect_provider.github[*].arn),
  )

  # The `sub` claim names who is asking, and it differs by job type:
  #   pull request job:               repo:OWNER/REPO:pull_request
  #   job that uses an Environment:   repo:OWNER/REPO:environment:NAME
  # A job that uses an Environment gets the second form and the branch is
  # no longer in the claim, so the branch restriction lives on the
  # Environment's deployment branch rule instead (a GitHub setting).
  subjects = {
    plan  = "repo:${var.github_repository}:pull_request"
    apply = "repo:${var.github_repository}:environment:${var.apply_environment}"
  }

  # StringEquals, never StringLike: no wildcard is ever interpreted. Both
  # claims are required. Checking only `aud` would let any repository on
  # GitHub assume the role.
  trust_policies = {
    for name, subject in local.subjects : name => jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Principal = { Federated = local.oidc_provider_arn }
        Action    = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_host}:aud" = "sts.amazonaws.com"
            "${local.oidc_host}:sub" = subject
          }
        }
      }]
    })
  }
}

# ---------------------------------------------------------------------
# OIDC provider
# ---------------------------------------------------------------------

# Tells AWS to accept tokens signed by GitHub. The audience must match the
# value the workflow requests, which the configure-aws-credentials action
# sets to sts.amazonaws.com. No thumbprint is given: AWS validates the
# token signature against GitHub's published keys.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://${local.oidc_host}"
  client_id_list = ["sts.amazonaws.com"]
}

# ---------------------------------------------------------------------
# Plan role: assumed by pull request workflows
# ---------------------------------------------------------------------

# Read-only. A pull request is untrusted until reviewed, so the role that
# runs on it must not be able to change anything.
resource "aws_iam_role" "ci_plan" {
  name                 = "${var.name_prefix}-ci-plan"
  assume_role_policy   = local.trust_policies["plan"]
  max_session_duration = var.max_session_duration
}

# `terraform plan` refreshes by reading every resource it manages.
# ReadOnlyAccess is broad but cannot modify anything. Narrowing it to the
# services in use is a possible later hardening step (ADR 0009).
resource "aws_iam_role_policy_attachment" "ci_plan_read_only" {
  role       = aws_iam_role.ci_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Plan reads state and takes a lock but never writes state, so write
# access is limited to the .tflock object. A compromised plan job can
# therefore stall a run, but cannot alter the state itself.
resource "aws_iam_role_policy" "ci_plan_state" {
  name = "terraform-state-read-and-lock"
  role = aws_iam_role.ci_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListStatePrefix"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = [local.state_bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = ["${var.state_key_prefix}*"] }
        }
      },
      {
        Sid      = "ReadState"
        Effect   = "Allow"
        Action   = "s3:GetObject"
        Resource = ["${local.state_bucket_arn}/${var.state_key_prefix}*"]
      },
      {
        Sid      = "StateLockOnly"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = ["${local.state_bucket_arn}/${var.state_key_prefix}*.tflock"]
      },
    ]
  })
}

# ---------------------------------------------------------------------
# Apply role: assumed by the protected apply workflow
# ---------------------------------------------------------------------

# Can change infrastructure, so its permissions are the blast radius of a
# compromised apply job. Reaching it requires passing the GitHub
# Environment's protection rules (required reviewer, main branch only).
resource "aws_iam_role" "ci_apply" {
  name                 = "${var.name_prefix}-ci-apply"
  assume_role_policy   = local.trust_policies["apply"]
  max_session_duration = var.max_session_duration
}

resource "aws_iam_role_policy" "ci_apply_state" {
  name = "terraform-state-read-write"
  role = aws_iam_role.ci_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListStatePrefix"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = [local.state_bucket_arn]
        Condition = {
          StringLike = { "s3:prefix" = ["${var.state_key_prefix}*"] }
        }
      },
      {
        Sid      = "ReadWriteState"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = ["${local.state_bucket_arn}/${var.state_key_prefix}*"]
      },
    ]
  })
}

# Scoped by service, not by individual action: ec2, rds and logs are
# allowed in one region, S3 and IAM only for names starting with the
# project prefix. That is a starting point rather than a minimum. After a
# real apply, CloudTrail shows which actions were used and the policy can
# be narrowed to them (ADR 0009).
resource "aws_iam_role_policy" "ci_apply_infrastructure" {
  name = "manage-project-infrastructure"
  role = aws_iam_role.ci_apply.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "RegionalServices"
        Effect   = "Allow"
        Action   = ["ec2:*", "rds:*", "logs:*"]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:RequestedRegion" = var.allowed_region }
        }
      },
      {
        Sid    = "ProjectBuckets"
        Effect = "Allow"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::${var.name_prefix}-*",
          "arn:aws:s3:::${var.name_prefix}-*/*",
        ]
      },
      {
        # EBS volumes and RDS instances are encrypted with AWS-managed
        # keys. Using them requires KMS permissions, but only when the
        # request comes through one of these services.
        Sid    = "UseServiceEncryptionKeys"
        Effect = "Allow"
        Action = [
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:Decrypt",
          "kms:Encrypt",
          "kms:GenerateDataKey*",
          "kms:ReEncrypt*",
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:CallerAccount" = local.account_id
            "kms:ViaService" = [
              "ec2.${var.allowed_region}.amazonaws.com",
              "rds.${var.allowed_region}.amazonaws.com",
              "s3.${var.allowed_region}.amazonaws.com",
              "secretsmanager.${var.allowed_region}.amazonaws.com",
            ]
          }
        }
      },
      {
        Sid    = "ManageProjectIdentities"
        Effect = "Allow"
        Action = [
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:GetRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:ListRoleTags",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:GetRolePolicy",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:GetInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:TagInstanceProfile",
          "iam:UntagInstanceProfile",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:CreatePolicyVersion",
          "iam:DeletePolicyVersion",
        ]
        Resource = [
          "${local.iam_arn}:role/${var.name_prefix}-*",
          "${local.iam_arn}:instance-profile/${var.name_prefix}-*",
          "${local.iam_arn}:policy/${var.name_prefix}-*",
        ]
      },
      {
        # Attaching a policy is how a role gains power, so it is limited to
        # an approved list instead of being allowed freely.
        Sid      = "AttachApprovedPoliciesOnly"
        Effect   = "Allow"
        Action   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
        Resource = ["${local.iam_arn}:role/${var.name_prefix}-*"]
        Condition = {
          ArnLike = {
            "iam:PolicyARN" = [
              "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
              "${local.iam_arn}:policy/${var.name_prefix}-*",
            ]
          }
        }
      },
      {
        Sid      = "PassProjectRolesToServices"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = ["${local.iam_arn}:role/${var.name_prefix}-*"]
        Condition = {
          StringEquals = {
            "iam:PassedToService" = [
              "ec2.amazonaws.com",
              "vpc-flow-logs.amazonaws.com",
              "monitoring.rds.amazonaws.com",
            ]
          }
        }
      },
      {
        # The first RDS instance in an account needs this role to exist.
        Sid      = "CreateRdsServiceLinkedRole"
        Effect   = "Allow"
        Action   = "iam:CreateServiceLinkedRole"
        Resource = ["${local.iam_arn}:role/aws-service-role/rds.amazonaws.com/AWSServiceRoleForRDS"]
        Condition = {
          StringEquals = { "iam:AWSServiceName" = "rds.amazonaws.com" }
        }
      },
      {
        # An explicit Deny beats any Allow. The state bucket usually shares
        # the project prefix, so the Allow on ProjectBuckets above would
        # otherwise cover it.
        Sid    = "ProtectStateBucket"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketVersioning",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketPublicAccessBlock",
          "s3:PutLifecycleConfiguration",
        ]
        Resource = [local.state_bucket_arn]
      },
      {
        # The apply role must not be able to edit itself, the plan role, or
        # the OIDC provider. Their names also match the project prefix, so
        # the Allow statements above would otherwise cover them.
        Sid    = "ProtectCiIdentity"
        Effect = "Deny"
        Action = [
          "iam:Update*",
          "iam:Delete*",
          "iam:Put*",
          "iam:Attach*",
          "iam:Detach*",
          "iam:Tag*",
          "iam:Untag*",
          "iam:AddClientIDToOpenIDConnectProvider",
          "iam:RemoveClientIDFromOpenIDConnectProvider",
        ]
        Resource = [
          "${local.iam_arn}:role/${var.name_prefix}-ci-*",
          "${local.iam_arn}:oidc-provider/${local.oidc_host}",
        ]
      },
    ]
  })
}
