variable "name_prefix" {
  description = "Prefix for the names of the roles this module creates, and the prefix the apply role is allowed to manage, for example \"myproj-dev\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,40}$", var.name_prefix))
    error_message = "name_prefix must be 1-41 characters: lowercase letters, digits and hyphens, starting with a letter or digit."
  }
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the CI roles, as \"owner/name\". No wildcards: a trust policy that matches more than one repository lets other repositories assume the role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.github_repository))
    error_message = "github_repository must look like \"owner/name\" and must not contain wildcards."
  }
}

variable "apply_environment" {
  description = "Name of the GitHub Environment whose jobs may assume the apply role. Protect that environment with required reviewers and a deployment branch rule restricted to main."
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.apply_environment))
    error_message = "apply_environment must not be empty and must not contain wildcards or spaces."
  }
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. An account can hold only one per URL, so set false if it already exists and it will be looked up instead."
  type        = bool
  default     = true
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket that holds Terraform state. The CI roles are granted access to it."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.state_bucket_name))
    error_message = "state_bucket_name must be a valid S3 bucket name."
  }
}

variable "state_key_prefix" {
  description = "Prefix of the state objects inside the bucket. The CI roles can only touch keys under it."
  type        = string
  default     = "envs/"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+/$", var.state_key_prefix))
    error_message = "state_key_prefix must end with a slash and contain no wildcards, for example \"envs/\"."
  }
}

variable "allowed_region" {
  description = "The only region the apply role may create regional resources in."
  type        = string
  default     = "eu-central-1"
}

variable "max_session_duration" {
  description = "Maximum lifetime in seconds of the credentials a CI job receives. One hour is the minimum and is enough for a plan or apply."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}
