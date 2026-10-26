# A private S3 bucket with the safe settings turned on by default.
#
# S3 splits one bucket across many resources (versioning, encryption,
# lifecycle and so on are separate resources in the AWS provider), so the
# order below follows the order of the protections: nothing public first,
# then access control, then durability, then cost housekeeping.

resource "aws_s3_bucket" "this" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy
}

# Blocks every route to public access, whatever a policy or ACL later says.
# This is the single most important setting on the bucket.
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Turns ACLs off entirely: the bucket owner owns every object and access is
# controlled by IAM and bucket policies only. ACLs are a legacy mechanism
# and a common source of accidental exposure.
resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  count = var.versioning_enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest. SSE-S3 (AES256) by default because it is free and
# needs no key management; pass kms_key_arn to use your own key instead.
# S3 encrypts new objects by default now, but declaring it keeps the
# setting in code, where it can be reviewed.
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn == null ? "AES256" : "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }

    # A bucket key reduces KMS request calls, and so cost, when using KMS.
    bucket_key_enabled = var.kms_key_arn != null
  }
}

# Housekeeping. Old versions and abandoned multipart uploads are invisible
# in normal use but accumulate storage charges indefinitely.
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    id     = "housekeeping"
    status = "Enabled"

    # An empty filter applies the rule to every object in the bucket.
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }

  # Lifecycle rules for old versions are only meaningful once versioning
  # exists, and S3 rejects concurrent changes to one bucket.
  depends_on = [aws_s3_bucket_versioning.this]
}

# Refuses any request that does not use TLS 1.2 or newer. Without this, a
# client could read or write over plain HTTP and the data would cross the
# network unencrypted.
resource "aws_s3_bucket_policy" "tls_only" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
      {
        Sid       = "DenyOutdatedTls"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.this.arn,
          "${aws_s3_bucket.this.arn}/*",
        ]
        Condition = {
          NumericLessThan = { "s3:TlsVersion" = "1.2" }
        }
      },
    ]
  })

  # S3 returns a conflict error if a policy and the public access block
  # are changed at the same moment, so the block goes first.
  depends_on = [aws_s3_bucket_public_access_block.this]
}
