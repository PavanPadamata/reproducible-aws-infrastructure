# Bootstrap: the pieces that must outlive the disposable dev environment
# and exist before anything else can run (ADR 0005, ADR 0009).
#
#   - the S3 bucket that holds Terraform state for every environment
#   - the GitHub OIDC provider and the two CI roles
#
# This configuration is applied once, by a person with their own AWS
# credentials, and keeps its own state in a local file. That file is small
# and only tracks the pieces above. It is git-ignored; if it is lost, the
# resources are brought back with `terraform import`.

# Used only to make the bucket name globally unique. The account ID is read
# at run time and never written into the repository.
data "aws_caller_identity" "current" {}

locals {
  state_bucket_name = "${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}"
}

module "state_bucket" {
  source = "../modules/s3"

  bucket_name = local.state_bucket_name

  # Both are the module defaults, written out because they are the point of
  # this bucket. Versioning lets a bad state write be rolled back.
  # force_destroy = false makes a destroy fail while any state object or
  # version exists, which stops a stray `terraform destroy` here from
  # deleting every environment's state (ADR 0010).
  versioning_enabled = true
  force_destroy      = false
}

module "iam" {
  source = "../modules/iam"

  # The project name, not the environment: the CI roles manage everything
  # named "<project>-*", which covers every environment. The state bucket
  # and the CI roles share that prefix, and the iam module denies the apply
  # role any change to them.
  name_prefix = var.project_name

  github_repository           = var.github_repository
  apply_environment           = var.apply_environment
  create_github_oidc_provider = var.create_github_oidc_provider

  # The name, not module.state_bucket.bucket_id: the policy only needs the
  # name, and a name known at plan time keeps the iam module's validation
  # working on a first run.
  state_bucket_name = local.state_bucket_name
  state_key_prefix  = var.state_key_prefix
  allowed_region    = var.aws_region
}
