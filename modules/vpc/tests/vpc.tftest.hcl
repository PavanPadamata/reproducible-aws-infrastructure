# Offline tests: a mock provider stands in for AWS, so no credentials are
# needed and nothing is created. Run from modules/vpc with `terraform test`.
#
# The module slices the list of Availability Zones, so the mocked data
# source must return a real-looking list instead of an empty one.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
    }
  }
}

variables {
  name_prefix = "test"
}

run "defaults_create_three_tiers_without_nat" {
  command = plan

  assert {
    condition     = keys(aws_subnet.public) == ["eu-central-1a", "eu-central-1b"]
    error_message = "Expected one public subnet in each of the first two zones."
  }

  assert {
    condition     = length(aws_subnet.app) == 2 && length(aws_subnet.data) == 2
    error_message = "Expected two app and two data subnets."
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 0 && length(aws_eip.nat) == 0 && length(aws_route.app_nat) == 0
    error_message = "The NAT Gateway, its Elastic IP and the app default route must not exist by default, because they are billed hourly."
  }

  assert {
    condition     = length(aws_flow_log.main) == 0
    error_message = "Flow logs must be off by default."
  }

  assert {
    condition     = aws_vpc.main.enable_dns_support && aws_vpc.main.enable_dns_hostnames
    error_message = "DNS support and hostnames are required for RDS endpoints and Systems Manager."
  }

  assert {
    condition     = output.nat_gateway_public_ip == null
    error_message = "nat_gateway_public_ip must be null when the NAT Gateway is disabled."
  }
}

run "nat_gateway_when_enabled" {
  command = plan

  variables {
    enable_nat_gateway = true
  }

  assert {
    condition     = length(aws_nat_gateway.main) == 1 && length(aws_eip.nat) == 1 && length(aws_route.app_nat) == 1
    error_message = "Enabling the NAT Gateway must create exactly one gateway, one Elastic IP and one default route."
  }
}

run "flow_logs_when_enabled" {
  command = plan

  variables {
    enable_flow_logs        = true
    flow_log_retention_days = 7
  }

  assert {
    condition     = length(aws_flow_log.main) == 1 && length(aws_cloudwatch_log_group.flow) == 1 && length(aws_iam_role.flow) == 1
    error_message = "Enabling flow logs must create the flow log, its log group and its role."
  }

  assert {
    condition     = aws_cloudwatch_log_group.flow[0].retention_in_days == 7
    error_message = "The log group must use the requested retention."
  }
}

run "rejects_single_availability_zone" {
  command = plan

  variables {
    az_count = 1
  }

  expect_failures = [var.az_count]
}

run "rejects_invalid_cidr" {
  command = plan

  variables {
    public_subnet_cidrs = ["not-a-cidr", "10.0.1.0/24"]
  }

  expect_failures = [var.public_subnet_cidrs]
}

run "rejects_too_few_subnet_cidrs_for_az_count" {
  command = plan

  variables {
    az_count          = 3
    app_subnet_cidrs  = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
    data_subnet_cidrs = ["10.0.20.0/24", "10.0.21.0/24", "10.0.22.0/24"]
  }

  expect_failures = [var.public_subnet_cidrs]
}
