# Input variables for the root module.
#
# Defaults are set where a value is genuinely project-wide and unlikely
# to change. Variables without defaults must be supplied explicitly,
# which forces a conscious decision at apply time.

variable "aws_region" {
  description = "AWS region for all resources. Frankfurt, for EU data residency."
  type        = string
  default     = "eu-central-1"
}

variable "project_name" {
  description = "Short project identifier, used in resource names and tags."
  type        = string
  default     = "reproducible-aws-infra"
}

variable "environment" {
  description = "Environment name, used in resource names and tags."
  type        = string
  default     = "dev"
}