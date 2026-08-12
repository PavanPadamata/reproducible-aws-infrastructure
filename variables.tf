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

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 leaves room to add tiers without renumbering."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "app_subnet_cidrs" {
  description = "CIDRs for private application subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "data_subnet_cidrs" {
  description = "CIDRs for private database subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "az_count" {
  description = "Number of Availability Zones to span. Two is the minimum for ALB and RDS subnet groups."
  type        = number
  default     = 2
}