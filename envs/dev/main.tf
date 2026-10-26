# Dev environment: wires the reusable modules together.
#
# This directory is the root module: the place `terraform plan` and
# `apply` are run from. It holds choices (names, sizes, what to turn on);
# the modules hold the implementation.

# Used only to make the S3 bucket name globally unique. The account ID is
# read at run time and never written into the repository.
data "aws_caller_identity" "current" {}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "vpc" {
  source = "../../modules/vpc"

  name_prefix = local.name_prefix

  # Cost driver, set on purpose. The instance sits in a private subnet and
  # needs an outbound path to reach Systems Manager (ADR 0004, ADR 0008).
  # The module default is false; dev opts in and the cost is visible here.
  enable_nat_gateway = var.enable_nat_gateway
}

module "app" {
  source = "../../modules/ec2"

  name   = "${local.name_prefix}-app"
  vpc_id = module.vpc.vpc_id

  # values() orders by key, so this is the first Availability Zone every
  # time. One instance, one zone: see ADR 0007.
  subnet_id = values(module.vpc.app_subnet_ids)[0]
}

module "app_data" {
  source = "../../modules/s3"

  bucket_name = "${local.name_prefix}-app-data-${data.aws_caller_identity.current.account_id}"

  # Dev is destroyed after every session (ADR 0002). Without this,
  # `terraform destroy` fails on a bucket that still holds objects.
  force_destroy = true
}
