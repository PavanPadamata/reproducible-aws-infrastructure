# Network layer: VPC, subnets across two Availability Zones, and the
# routing that defines which tier can reach the internet.
#
# See docs/architecture.md for the tier layout and docs/adr/ for the
# cost decisions behind the single NAT Gateway.

# Queries AWS for Availability Zones in the configured region, rather
# than hardcoding names like eu-central-1a. Filtered to zones that are
# fully available and opted-in, excluding Local Zones and Wavelength
# zones, which do not support all services used here.
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  # Take only as many AZs as az_count, so the subnet lists and the AZ
  # list are guaranteed to be the same length.
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Maps of AZ name to CIDR, used as for_each keys below. for_each is
  # used instead of count so each subnet is addressed by AZ name rather
  # than list index. With count, removing an entry shifts every
  # subsequent index and causes Terraform to destroy and recreate
  # resources that did not actually change.
  public_subnets = { for i, az in local.azs : az => var.public_subnet_cidrs[i] }
  app_subnets    = { for i, az in local.azs : az => var.app_subnet_cidrs[i] }
  data_subnets   = { for i, az in local.azs : az => var.data_subnet_cidrs[i] }

  name_prefix = "${var.project_name}-${var.environment}"
}

# ---------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------

# enable_dns_hostnames and enable_dns_support are required for RDS
# endpoint resolution and for SSM Session Manager to work over the
# private network.
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

# ---------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------

# Attaching an IGW does not by itself make anything public. A subnet is
# public only because its route table sends 0.0.0.0/0 here.
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-igw"
  }
}

# ---------------------------------------------------------------------
# Subnets
# ---------------------------------------------------------------------

# Public subnets host the load balancer and the NAT Gateway.
# map_public_ip_on_launch is deliberately left at its default of false:
# nothing in this project launches instances here, and defaulting to
# public IPs invites accidental exposure.
resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${local.name_prefix}-public-${each.key}"
    Tier = "public"
  }
}

# Application subnets host EC2 instances. Outbound internet access only,
# via the NAT Gateway. No inbound path from the internet exists.
resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${local.name_prefix}-app-${each.key}"
    Tier = "application"
  }
}

# Database subnets are fully isolated: their route table has no
# 0.0.0.0/0 route at all, so traffic cannot leave the VPC in either
# direction. Two are required because an RDS subnet group must span at
# least two Availability Zones, even for a single-AZ instance.
resource "aws_subnet" "data" {
  for_each = local.data_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = each.key

  tags = {
    Name = "${local.name_prefix}-data-${each.key}"
    Tier = "data"
  }
}

# ---------------------------------------------------------------------
# NAT Gateway
# ---------------------------------------------------------------------

# A single NAT Gateway serves both Availability Zones. Production
# designs place one per AZ so that losing a zone does not cut off
# outbound traffic from the surviving zone. This is a deliberate cost
# decision and a known single point of failure.
#
# Billed hourly whether or not traffic flows. See ADR 0002: the
# environment is destroyed between sessions, which keeps this to cents.

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name_prefix}-nat-eip"
  }
}

# The NAT Gateway itself sits in a public subnet, because it needs the
# IGW route to reach the internet on behalf of private instances.
#
# depends_on is required here and is not inferable from references:
# the NAT Gateway needs a functioning internet path at creation time,
# but nothing in this resource block refers to the IGW.
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[local.azs[0]].id

  tags = {
    Name = "${local.name_prefix}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------------
# Route tables
# ---------------------------------------------------------------------

# Public: everything not local goes to the internet gateway.
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-public-rt"
  }
}

# Application: outbound via NAT. Return traffic for connections the
# instance opened is allowed back; nothing can initiate inbound.
resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${local.name_prefix}-app-rt"
  }
}

# Database: no 0.0.0.0/0 route. Only the implicit local route for the
# VPC CIDR exists, so this tier can reach nothing outside the VPC and
# nothing outside can reach it. Isolation here comes from routing, not
# only from security groups.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name_prefix}-data-rt"
  }
}

# ---------------------------------------------------------------------
# Route table associations
# ---------------------------------------------------------------------

# Without an association a subnet falls back to the VPC main route
# table, which has no internet route. A missing association is the most
# common cause of "the instance cannot reach the internet".

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}