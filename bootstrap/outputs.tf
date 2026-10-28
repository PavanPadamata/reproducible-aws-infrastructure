# Values needed after the apply: the bucket name goes into the backend
# configuration of each environment, and the role ARNs go into the CI
# workflows.

output "state_bucket_name" {
  description = "Name of the S3 bucket that holds Terraform state. Pass it to `terraform init -backend-config=\"bucket=...\"` in each environment."
  value       = local.state_bucket_name
}

output "state_bucket_arn" {
  description = "ARN of the state bucket."
  value       = module.state_bucket.bucket_arn
}

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider the CI roles trust."
  value       = module.iam.github_oidc_provider_arn
}

output "ci_plan_role_arn" {
  description = "ARN of the read-only role pull request workflows assume to run terraform plan."
  value       = module.iam.ci_plan_role_arn
}

output "ci_apply_role_arn" {
  description = "ARN of the role the protected apply workflow assumes to run terraform apply."
  value       = module.iam.ci_apply_role_arn
}
