# One hardened EC2 instance, reachable through Session Manager.
#
# Hardening choices, each of which is a separate attack or mistake closed:
#   - IMDSv2 required: blocks the classic SSRF route to instance credentials
#   - encrypted root volume
#   - no public IP and no inbound rules by default
#   - no SSH key pair, so no key material to lose or leak (ADR 0004)

# Latest Amazon Linux 2023, only used when no ami_id is given. The name
# pattern excludes the "minimal" and ECS variants.
data "aws_ami" "al2023" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  ami_id = coalesce(var.ami_id, one(data.aws_ami.al2023[*].id))
}

# ---------------------------------------------------------------------
# Instance role and profile
# ---------------------------------------------------------------------

# An instance cannot hold an IAM role directly. It holds an instance
# profile, a wrapper that passes the role to the instance. Credentials are
# temporary and rotate automatically, so no access keys exist on the host.
resource "aws_iam_role" "this" {
  name = "${var.name}-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Lets the SSM agent on the instance register with Systems Manager so a
# session can be opened. The agent ships with Amazon Linux 2023.
resource "aws_iam_role_policy_attachment" "ssm" {
  count = var.enable_ssm ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# count, not for_each: the ARNs may belong to policies created in the same
# apply, so their values are unknown at plan time. for_each needs its keys
# at plan time; count needs only the length of the list, which is known.
resource "aws_iam_role_policy_attachment" "additional" {
  count = length(var.additional_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = var.additional_policy_arns[count.index]
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance"
  role = aws_iam_role.this.name
}

# ---------------------------------------------------------------------
# Security group
# ---------------------------------------------------------------------

# Rules are separate resources, not inline blocks. Inline rules and
# separate rule resources on the same group conflict, and separate
# resources can be added to or removed without rewriting the group.
resource "aws_security_group" "this" {
  name        = "${var.name}-sg"
  description = "Managed by Terraform: network rules for ${var.name}"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name}-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = { for r in var.ingress_rules : r.description => r }

  security_group_id = aws_security_group.this.id
  description       = each.value.description

  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port                      = each.value.ip_protocol == "-1" ? null : each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = { for r in var.egress_rules : r.description => r }

  security_group_id = aws_security_group.this.id
  description       = each.value.description

  ip_protocol                  = each.value.ip_protocol
  from_port                    = each.value.ip_protocol == "-1" ? null : each.value.from_port
  to_port                      = each.value.ip_protocol == "-1" ? null : each.value.to_port
  cidr_ipv4                    = each.value.cidr_ipv4
  referenced_security_group_id = each.value.referenced_security_group_id
}

# ---------------------------------------------------------------------
# Instance
# ---------------------------------------------------------------------

resource "aws_instance" "this" {
  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  iam_instance_profile        = aws_iam_instance_profile.this.name
  associate_public_ip_address = var.associate_public_ip_address

  user_data                   = var.user_data
  user_data_replace_on_change = var.user_data != null

  # Detailed (1-minute) monitoring is billed; basic 5-minute metrics are not.
  monitoring = false

  # IMDSv2 requires a session token for every metadata request. IMDSv1
  # answers a plain GET, so any server-side request forgery bug in an
  # application on the host can be used to steal the instance's
  # credentials. A hop limit of 1 keeps the token from being forwarded
  # beyond the instance itself.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    kms_key_id            = var.kms_key_id
    delete_on_termination = true
  }

  tags = {
    Name = var.name
  }
}
