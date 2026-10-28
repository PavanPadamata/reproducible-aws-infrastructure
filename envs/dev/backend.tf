# Remote state: a versioned, encrypted, private S3 bucket created by
# bootstrap/ (ADR 0003, ADR 0005).
#
# This is a partial configuration. A backend block cannot use variables,
# and the bucket name contains the AWS account ID, which is kept out of the
# repository. The bucket is supplied when initialising:
#
#   terraform init -backend-config=backend.hcl
#
# See backend.hcl.example.
#
# use_lockfile makes Terraform write a .tflock object next to the state for
# the length of a run, so two runs cannot write state at once. It needs
# Terraform 1.11 or newer and replaces the DynamoDB lock table.
#
# The key must start with the state_key_prefix given to bootstrap/
# ("envs/"): the CI roles can only touch state under that prefix.

terraform {
  backend "s3" {
    key          = "envs/dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
