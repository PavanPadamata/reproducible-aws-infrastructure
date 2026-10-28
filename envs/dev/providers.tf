# AWS provider configuration.
#
# default_tags applies these tags to every taggable resource created by
# this provider, without repeating them on each resource block. This
# satisfies the tagging requirement in docs/requirements.md and makes
# cost attribution possible in Cost Explorer.
#
# ManagedBy is deliberate: it tells anyone looking at the console that
# manual changes to this resource will be reverted on the next apply.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "reproducible-aws-infrastructure"
    }
  }
}