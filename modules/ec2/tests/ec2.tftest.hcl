# Offline tests: a mock provider stands in for AWS, so no credentials are
# needed and nothing is created. Run from modules/ec2 with `terraform test`.

mock_provider "aws" {
  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }
}

variables {
  name      = "test-app"
  vpc_id    = "vpc-0123456789abcdef0"
  subnet_id = "subnet-0123456789abcdef0"
}

run "hardened_defaults" {
  command = plan

  assert {
    condition     = aws_instance.this.metadata_options[0].http_tokens == "required"
    error_message = "IMDSv2 must be required."
  }

  assert {
    condition     = aws_instance.this.root_block_device[0].encrypted == true
    error_message = "The root volume must be encrypted."
  }

  assert {
    condition     = aws_instance.this.associate_public_ip_address == false
    error_message = "The instance must not get a public IP address by default."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "There must be no inbound rules by default."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 1
    error_message = "The default is a single outbound rule for HTTPS."
  }

  assert {
    condition     = aws_instance.this.ami == "ami-0123456789abcdef0"
    error_message = "Without ami_id the instance must use the looked-up Amazon Linux image."
  }
}

run "ssm_role_attached_by_default" {
  command = plan

  assert {
    condition     = length(aws_iam_role_policy_attachment.ssm) == 1
    error_message = "AmazonSSMManagedInstanceCore must be attached by default."
  }

  assert {
    condition     = jsondecode(aws_iam_role.this.assume_role_policy).Statement[0].Principal.Service == "ec2.amazonaws.com"
    error_message = "Only the EC2 service may assume the instance role."
  }
}

run "ssm_can_be_disabled" {
  command = plan

  variables {
    enable_ssm = false
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.ssm) == 0
    error_message = "enable_ssm = false must remove the SSM attachment."
  }
}

run "pinned_ami_skips_lookup" {
  command = plan

  variables {
    ami_id = "ami-0fedcba9876543210"
  }

  assert {
    condition     = length(data.aws_ami.al2023) == 0 && aws_instance.this.ami == "ami-0fedcba9876543210"
    error_message = "A pinned ami_id must be used as given, without a lookup."
  }
}

run "accepts_security_group_sourced_ingress" {
  command = plan

  variables {
    ingress_rules = [{
      description                  = "HTTP from the load balancer"
      from_port                    = 80
      to_port                      = 80
      referenced_security_group_id = "sg-0123456789abcdef0"
    }]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 1
    error_message = "A valid ingress rule must create one rule resource."
  }
}

run "rejects_ssh_open_to_the_world" {
  command = plan

  variables {
    ingress_rules = [{
      description = "SSH from anywhere"
      from_port   = 22
      to_port     = 22
      cidr_ipv4   = "0.0.0.0/0"
    }]
  }

  expect_failures = [var.ingress_rules]
}

run "rejects_all_traffic_open_to_the_world" {
  command = plan

  variables {
    ingress_rules = [{
      description = "Everything from anywhere"
      from_port   = 0
      to_port     = 0
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }]
  }

  expect_failures = [var.ingress_rules]
}

run "rejects_rule_with_two_sources" {
  command = plan

  variables {
    ingress_rules = [{
      description                  = "Ambiguous"
      from_port                    = 80
      to_port                      = 80
      cidr_ipv4                    = "10.0.0.0/16"
      referenced_security_group_id = "sg-0123456789abcdef0"
    }]
  }

  expect_failures = [var.ingress_rules]
}

run "rejects_malformed_ami_id" {
  command = plan

  variables {
    ami_id = "not-an-ami"
  }

  expect_failures = [var.ami_id]
}

run "rejects_undersized_root_volume" {
  command = plan

  variables {
    root_volume_size_gb = 4
  }

  expect_failures = [var.root_volume_size_gb]
}
