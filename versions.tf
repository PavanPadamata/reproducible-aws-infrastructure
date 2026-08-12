# Pins the Terraform CLI and provider versions.
#
# required_version states the minimum this configuration needs, not the
# newest available: 1.11 introduced native S3 state locking via
# use_lockfile, which this project relies on. The upper bound guards
# against a future 2.x with breaking changes.
#
# The AWS provider uses a pessimistic constraint: accept any 6.x release,
# reject 7.0. Exact versions and checksums are recorded in
# .terraform.lock.hcl, which IS committed — a provider release can be
# withdrawn or shipped broken, and the lock file guarantees every run
# resolves to the version that was actually tested.

terraform {
  required_version = ">= 1.11, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}