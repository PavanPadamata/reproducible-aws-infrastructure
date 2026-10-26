# A module declares which providers it needs but never configures them:
# the provider block (region, default tags) belongs to the root module
# that calls this one.

terraform {
  required_version = ">= 1.11, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
