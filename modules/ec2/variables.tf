variable "name" {
  description = "Name of the instance, also used to name its role and security group, for example \"myproj-dev-app\"."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,40}$", var.name))
    error_message = "name must be 1-41 characters: lowercase letters, digits and hyphens, starting with a letter or digit."
  }
}

variable "vpc_id" {
  description = "ID of the VPC the security group is created in."
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to launch the instance in. Use a private subnet unless the instance must be reachable from the internet."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type. Billed per hour while the instance exists."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*[0-9][a-z0-9-]*\\.[a-z0-9]+$", var.instance_type))
    error_message = "instance_type must look like \"t3.micro\"."
  }
}

variable "ami_id" {
  description = "AMI to launch. Null looks up the newest Amazon Linux 2023 image on every plan, which replaces the instance when a new image is published. Pin an ID for a stable environment."
  type        = string
  default     = null

  validation {
    condition     = var.ami_id == null || can(regex("^ami-[0-9a-f]{8,17}$", var.ami_id))
    error_message = "ami_id must be null or look like \"ami-0123456789abcdef0\"."
  }
}

variable "root_volume_size_gb" {
  description = "Size of the root volume in GiB."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size_gb >= 8
    error_message = "root_volume_size_gb must be at least 8, the size of the Amazon Linux 2023 image."
  }
}

variable "kms_key_id" {
  description = "KMS key to encrypt the root volume with. Null uses the AWS-managed EBS key. The volume is always encrypted."
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  description = "Give the instance a public IP address. Leave false for private subnets; Session Manager does not need one."
  type        = bool
  default     = false
}

variable "enable_ssm" {
  description = "Attach AmazonSSMManagedInstanceCore so the instance can be reached with Session Manager, with no SSH and no open inbound port."
  type        = bool
  default     = true
}

variable "additional_policy_arns" {
  description = "Extra managed policies to attach to the instance role, for example access to an S3 bucket."
  type        = list(string)
  default     = []
}

variable "user_data" {
  description = "Script to run on first boot. Changing it replaces the instance. Must not contain secrets: it is readable from the instance and from the console."
  type        = string
  default     = null
}

# Rules are objects with exactly one source: a CIDR block or another
# security group. Referencing a security group keeps a rule correct when
# the instances behind it change.

variable "ingress_rules" {
  description = "Inbound security group rules. Empty by default: Session Manager needs no inbound access."
  type = list(object({
    description                  = string
    from_port                    = number
    to_port                      = number
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = []

  validation {
    condition     = alltrue([for r in var.ingress_rules : (r.cidr_ipv4 != null) != (r.referenced_security_group_id != null)])
    error_message = "Each ingress rule needs exactly one source: cidr_ipv4 or referenced_security_group_id."
  }

  validation {
    condition = !anytrue([
      for r in var.ingress_rules :
      r.cidr_ipv4 == "0.0.0.0/0" && (r.ip_protocol == "-1" || (r.from_port <= 22 && r.to_port >= 22) || (r.from_port <= 3389 && r.to_port >= 3389))
    ])
    error_message = "Ingress from 0.0.0.0/0 must not include port 22 (SSH), port 3389 (RDP) or all protocols. Use Session Manager, or restrict the source."
  }

  validation {
    condition     = length(distinct([for r in var.ingress_rules : r.description])) == length(var.ingress_rules)
    error_message = "Ingress rule descriptions must be unique, because they are used as keys."
  }
}

variable "egress_rules" {
  description = "Outbound security group rules. The default allows HTTPS out, which Session Manager and package repositories need."
  type = list(object({
    description                  = string
    from_port                    = number
    to_port                      = number
    ip_protocol                  = optional(string, "tcp")
    cidr_ipv4                    = optional(string)
    referenced_security_group_id = optional(string)
  }))
  default = [
    {
      description = "HTTPS to anywhere for Session Manager and package repositories"
      from_port   = 443
      to_port     = 443
      cidr_ipv4   = "0.0.0.0/0"
    }
  ]

  validation {
    condition     = alltrue([for r in var.egress_rules : (r.cidr_ipv4 != null) != (r.referenced_security_group_id != null)])
    error_message = "Each egress rule needs exactly one destination: cidr_ipv4 or referenced_security_group_id."
  }

  validation {
    condition     = length(distinct([for r in var.egress_rules : r.description])) == length(var.egress_rules)
    error_message = "Egress rule descriptions must be unique, because they are used as keys."
  }
}
