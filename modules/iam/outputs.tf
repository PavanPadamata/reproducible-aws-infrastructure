output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider the CI roles trust."
  value       = local.oidc_provider_arn
}

output "ci_plan_role_arn" {
  description = "ARN of the read-only role pull request workflows assume to run terraform plan."
  value       = aws_iam_role.ci_plan.arn
}

output "ci_apply_role_arn" {
  description = "ARN of the role the protected apply workflow assumes to run terraform apply."
  value       = aws_iam_role.ci_apply.arn
}
