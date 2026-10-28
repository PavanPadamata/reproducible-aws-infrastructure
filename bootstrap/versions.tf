# Same pins as envs/dev: the versions that are tested are the versions that
# run. 1.11 is the first release with native S3 state locking.

terraform {
  required_version = ">= 1.11, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
