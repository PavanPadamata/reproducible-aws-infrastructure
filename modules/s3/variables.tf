variable "bucket_name" {
  description = "Name of the bucket. S3 names are global across all AWS accounts, so include something unique such as the account ID."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters: lowercase letters, digits, hyphens and dots, starting and ending with a letter or digit."
  }
}

variable "force_destroy" {
  description = "Delete the bucket even if it still contains objects. Leave false for anything holding data you would miss."
  type        = bool
  default     = false
}

variable "versioning_enabled" {
  description = "Keep previous versions of overwritten or deleted objects, so a bad write can be rolled back."
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "ARN of a KMS key to encrypt objects with. Null uses S3-managed keys (SSE-S3), which cost nothing."
  type        = string
  default     = null

  validation {
    condition     = var.kms_key_arn == null || can(regex("^arn:aws[a-z-]*:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be null or a KMS key ARN."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days after which old object versions are permanently deleted. Only has an effect while versioning is enabled."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "noncurrent_version_expiration_days must be at least 1."
  }
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after which an unfinished multipart upload is cleaned up. Abandoned parts are invisible but still billed."
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_upload_days >= 1
    error_message = "abort_incomplete_multipart_upload_days must be at least 1."
  }
}
