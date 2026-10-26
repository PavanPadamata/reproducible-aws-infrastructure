# Offline tests: a mock provider stands in for AWS, so no credentials are
# needed and nothing is created. Run from modules/rds with `terraform test`.

mock_provider "aws" {}

variables {
  name       = "test-db"
  vpc_id     = "vpc-0123456789abcdef0"
  subnet_ids = ["subnet-0123456789abcdef0", "subnet-0fedcba9876543210"]
}

run "private_encrypted_defaults" {
  command = plan

  assert {
    condition     = aws_db_instance.this.publicly_accessible == false
    error_message = "The database must never be publicly accessible."
  }

  assert {
    condition     = aws_db_instance.this.storage_encrypted == true
    error_message = "Storage must be encrypted."
  }

  assert {
    condition     = aws_db_instance.this.manage_master_user_password == true
    error_message = "The master password must be managed by RDS in Secrets Manager."
  }

  assert {
    condition     = aws_db_instance.this.deletion_protection == true && aws_db_instance.this.skip_final_snapshot == false
    error_message = "Deletion protection and a final snapshot must be on by default."
  }

  assert {
    condition     = aws_db_instance.this.final_snapshot_identifier == "test-db-final"
    error_message = "The final snapshot must have a predictable name."
  }

  assert {
    condition     = aws_db_instance.this.engine == "postgres" && aws_db_instance.this.engine_version == "17"
    error_message = "The default engine must be PostgreSQL 17."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_allowed) == 0
    error_message = "With no allowed security groups there must be no inbound rule at all."
  }
}

run "ingress_only_on_the_database_port_from_named_groups" {
  command = plan

  variables {
    allowed_security_group_ids = ["sg-0123456789abcdef0"]
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.from_allowed) == 1
    error_message = "One allowed security group must produce exactly one rule."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.from_allowed[0].from_port == 5432 && aws_vpc_security_group_ingress_rule.from_allowed[0].to_port == 5432
    error_message = "The rule must open only the PostgreSQL port."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.from_allowed[0].cidr_ipv4 == null
    error_message = "Access must be granted to a security group, never to a CIDR range."
  }
}

run "mysql_uses_its_own_port_and_version" {
  command = plan

  variables {
    engine                     = "mysql"
    allowed_security_group_ids = ["sg-0123456789abcdef0"]
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.from_allowed[0].from_port == 3306
    error_message = "MySQL must use port 3306."
  }

  assert {
    condition     = aws_db_instance.this.engine_version == "8.4"
    error_message = "The MySQL default version must be 8.4."
  }
}

run "disposable_settings_are_explicit" {
  command = plan

  variables {
    deletion_protection = false
    skip_final_snapshot = true
  }

  assert {
    condition     = aws_db_instance.this.deletion_protection == false && aws_db_instance.this.final_snapshot_identifier == null
    error_message = "A throwaway database must be able to opt out of protection and the final snapshot."
  }
}

run "rejects_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0123456789abcdef0"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_unsupported_engine" {
  command = plan

  variables {
    engine = "oracle-ee"
  }

  expect_failures = [var.engine]
}

run "rejects_reserved_master_username" {
  command = plan

  variables {
    master_username = "admin"
  }

  expect_failures = [var.master_username]
}

run "rejects_zero_backup_retention" {
  command = plan

  variables {
    backup_retention_days = 0
  }

  expect_failures = [var.backup_retention_days]
}

run "rejects_tiny_storage" {
  command = plan

  variables {
    allocated_storage_gb = 10
  }

  expect_failures = [var.allocated_storage_gb]
}
