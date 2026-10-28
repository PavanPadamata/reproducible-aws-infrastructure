# Input variables for the bootstrap configuration.
#
# github_repository has no default on purpose: it decides which repository
# may assume the CI roles, so it must be written down by a person.

variable "aws_region" {
  description = "AWS region for the state bucket and regional resources. Frankfurt, for EU data residency."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Short project identifier. Prefixes the state bucket and the CI roles, and is the prefix the apply role is allowed to manage."
  type        = string
  default     = "reproducible-aws-infra"
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as \"owner/name\". No wildcards."
  type        = string
}

variable "apply_environment" {
  description = "Name of the GitHub Environment whose jobs may assume the apply role. Protect it with required reviewers and a deployment branch rule restricted to main (ADR 0009)."
  type        = string
  default     = "dev"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. An account can hold only one per URL; set false if it already exists and it will be looked up instead."
  type        = bool
  default     = true
}

variable "state_key_prefix" {
  description = "Prefix of the state objects inside the bucket. The CI roles can only touch keys under it, so each environment's key must start with it."
  type        = string
  default     = "envs/"
}
