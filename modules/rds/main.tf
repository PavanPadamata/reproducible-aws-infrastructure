# A private, encrypted database whose password nobody ever types.
#
# Protections, each closing a separate mistake:
#   - isolated subnets and publicly_accessible = false: no route in from the internet
#   - security group that admits only named application security groups
#   - storage encrypted, always
#   - RDS-managed master password in Secrets Manager, never in code or state input
#   - deletion protection and a final snapshot on by default

locals {
  port = var.engine == "postgres" ? 5432 : 3306

  # Tested defaults. A major version alone lets AWS apply minor upgrades.
  engine_version = coalesce(var.engine_version, var.engine == "postgres" ? "17" : "8.4")
}

# An RDS instance is placed by a subnet group: a named set of subnets in at
# least two Availability Zones, even for a single-AZ instance, so that a
# failover target always exists.
resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-subnets"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.name}-subnets"
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Managed by Terraform: inbound access to ${var.name}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-sg"
  }
}

# The only inbound rule: the database port, from named security groups.
# Referencing a group instead of an IP range keeps the rule correct as
# application instances are replaced.
#
# count, not for_each: the IDs may belong to groups created in the same
# apply, so their values are unknown at plan time. for_each needs its keys
# at plan time; count needs only the length of the list, which is known.
resource "aws_vpc_security_group_ingress_rule" "from_allowed" {
  count = length(var.allowed_security_group_ids)

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = var.allowed_security_group_ids[count.index]
  ip_protocol                  = "tcp"
  from_port                    = local.port
  to_port                      = local.port
  description                  = "Database port from allowed security group ${count.index + 1}"
}

# No egress rules on purpose. The database never opens connections of its
# own, so it needs no outbound path.

resource "aws_db_instance" "this" {
  identifier = var.name

  engine         = var.engine
  engine_version = local.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage_gb
  max_allocated_storage = var.max_allocated_storage_gb
  storage_type          = "gp3"
  storage_encrypted     = true
  kms_key_id            = var.kms_key_id

  db_name  = var.db_name
  username = var.master_username

  # RDS generates the password, stores it in Secrets Manager and keeps it
  # out of Terraform's inputs. The secret ARN is exposed as an output;
  # the password itself is read from Secrets Manager by whoever needs it.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]
  publicly_accessible    = false
  multi_az               = var.multi_az

  backup_retention_period   = var.backup_retention_days
  copy_tags_to_snapshot     = true
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-final"

  # Lets applications authenticate with short-lived IAM tokens instead of a
  # password, if they choose to.
  iam_database_authentication_enabled = true

  enabled_cloudwatch_logs_exports = var.cloudwatch_log_exports
  auto_minor_version_upgrade      = var.auto_minor_version_upgrade
  apply_immediately               = var.apply_immediately

  # Performance Insights is billed beyond its free retention, so it stays off.
  performance_insights_enabled = false

  tags = {
    Name = var.name
  }
}
