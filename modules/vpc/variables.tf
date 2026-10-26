variable "name_prefix" {
  description = "Prefix for the Name tag of every resource, for example \"myproj-dev\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,40}$", var.name_prefix))
    error_message = "name_prefix must be 1-41 characters: lowercase letters, digits and hyphens, starting with a letter or digit."
  }
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 leaves room to add tiers without renumbering."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block, for example 10.0.0.0/16."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to span. Two is the minimum for ALB and RDS subnet groups."
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "az_count must be 2 or 3: RDS subnet groups need at least two zones, and the default CIDR lists hold two."
  }
}

# The three subnet lists are checked the same way: every entry must be a
# valid CIDR, and there must be at least az_count of them. Without the
# length check, an az_count larger than the list fails later with an
# opaque "invalid index" error from inside main.tf.

variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]

  validation {
    condition     = alltrue([for c in var.public_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in public_subnet_cidrs must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = length(var.public_subnet_cidrs) >= var.az_count
    error_message = "public_subnet_cidrs needs at least az_count entries."
  }
}

variable "app_subnet_cidrs" {
  description = "CIDRs for private application subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]

  validation {
    condition     = alltrue([for c in var.app_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in app_subnet_cidrs must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = length(var.app_subnet_cidrs) >= var.az_count
    error_message = "app_subnet_cidrs needs at least az_count entries."
  }
}

variable "data_subnet_cidrs" {
  description = "CIDRs for private database subnets, one per Availability Zone."
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]

  validation {
    condition     = alltrue([for c in var.data_subnet_cidrs : can(cidrhost(c, 0))])
    error_message = "Every entry in data_subnet_cidrs must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = length(var.data_subnet_cidrs) >= var.az_count
    error_message = "data_subnet_cidrs needs at least az_count entries."
  }
}

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway so the app subnets can reach the internet. Billed hourly while it exists, so it is off by default."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Send VPC flow logs to CloudWatch Logs. Off by default: log ingestion and storage are billed."
  type        = bool
  default     = false
}

variable "flow_log_traffic_type" {
  description = "Which traffic to log when flow logs are enabled: ACCEPT, REJECT or ALL."
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_log_traffic_type)
    error_message = "flow_log_traffic_type must be ACCEPT, REJECT or ALL."
  }
}

variable "flow_log_retention_days" {
  description = "Days to keep flow logs in CloudWatch Logs. Must be a retention value CloudWatch accepts."
  type        = number
  default     = 14

  validation {
    condition = contains(
      [1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.flow_log_retention_days
    )
    error_message = "flow_log_retention_days must be one of the retention periods CloudWatch Logs supports, for example 7, 14, 30 or 90."
  }
}
