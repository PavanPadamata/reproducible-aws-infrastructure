# Dev environment: wires the reusable modules together.
#
# This directory is the root module: the place `terraform plan` and
# `apply` are run from. It holds choices (names, sizes, what to turn on);
# the modules hold the implementation.

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
