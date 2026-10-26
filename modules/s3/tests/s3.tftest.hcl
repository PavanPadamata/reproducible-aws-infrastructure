# Offline tests: a mock provider stands in for AWS, so no credentials are
# needed and nothing is created. Run from modules/s3 with `terraform test`.
#
# Runs that read the bucket policy use `command = apply`. The policy is
# built from the bucket's ARN, which is unknown at plan time; with a mock
# provider, apply fills it with a generated value and creates nothing real.

mock_provider "aws" {}

variables {
  bucket_name = "test-bucket-123"
}

run "secure_defaults" {
  command = apply

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four public access block settings must be on."
  }

  assert {
    condition     = one(aws_s3_bucket_ownership_controls.this.rule).object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled with BucketOwnerEnforced."
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 1
    error_message = "Versioning must be on by default."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Without a KMS key the bucket must use SSE-S3 (AES256)."
  }

  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false."
  }
}

run "policy_denies_plain_http_and_old_tls" {
  command = apply

  assert {
    condition = anytrue([
      for s in jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement :
      s.Effect == "Deny" && try(s.Condition.Bool["aws:SecureTransport"], "") == "false"
    ])
    error_message = "The policy must deny requests made without TLS."
  }

  assert {
    condition = anytrue([
      for s in jsondecode(aws_s3_bucket_policy.tls_only.policy).Statement :
      s.Effect == "Deny" && try(s.Condition.NumericLessThan["s3:TlsVersion"], "") == "1.2"
    ])
    error_message = "The policy must deny TLS versions older than 1.2."
  }
}

run "kms_key_switches_encryption" {
  command = apply

  variables {
    kms_key_arn = "arn:aws:kms:eu-central-1:123456789012:key/00000000-0000-0000-0000-000000000000"
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.this.rule).apply_server_side_encryption_by_default).sse_algorithm == "aws:kms"
    error_message = "Passing kms_key_arn must switch encryption to aws:kms."
  }
}

run "versioning_can_be_disabled" {
  command = plan

  variables {
    versioning_enabled = false
  }

  assert {
    condition     = length(aws_s3_bucket_versioning.this) == 0
    error_message = "versioning_enabled = false must remove the versioning resource."
  }
}

run "rejects_uppercase_bucket_name" {
  command = plan

  variables {
    bucket_name = "Not-Valid"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_malformed_kms_arn" {
  command = plan

  variables {
    kms_key_arn = "not-an-arn"
  }

  expect_failures = [var.kms_key_arn]
}
