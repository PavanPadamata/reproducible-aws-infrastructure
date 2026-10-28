# AWS provider configuration. Environment is "bootstrap" so Cost Explorer
# can separate the long-lived account setup from the disposable dev
# environment.

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = "bootstrap"
      ManagedBy   = "terraform"
      Repository  = "reproducible-aws-infrastructure"
    }
  }
}
