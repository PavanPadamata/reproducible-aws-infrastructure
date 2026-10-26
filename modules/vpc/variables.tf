variable "name_prefix" {
  description = "Prefix for the Name tag of every resource, for example \"myproj-dev\"."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. /16 leaves room to add tiers without renumbering."
  type        = string
  default     = "10.0.0.0/16"
}

variable "az_count" {
  description = "Number of Availability Zones to span. Two is the minimum for ALB and RDS subnet groups."
  type        = number
  default     = 2
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

variable "enable_nat_gateway" {
  description = "Create a NAT Gateway so the app subnets can reach the internet. Billed hourly while it exists, so it is off by default."
  type        = bool
  default     = false
}
