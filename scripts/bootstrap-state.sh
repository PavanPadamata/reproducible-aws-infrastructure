#!/usr/bin/env bash
#
# Creates the S3 bucket that holds Terraform state.
#
# Run once, before the first `terraform init`. The bucket exists outside
# Terraform's lifecycle by necessity: a backend must be available before
# Terraform can initialise against it.
#
# Versioning is enabled so a corrupted or bad state write can be rolled
# back. Encryption and public access blocking are enabled because state
# contains sensitive values in plaintext.
#
# Usage: ./scripts/bootstrap-state.sh <bucket-name>

set -euo pipefail

BUCKET="${1:?Usage: $0 <bucket-name>}"
REGION="eu-central-1"

echo "Creating bucket ${BUCKET} in ${REGION}..."
aws s3api create-bucket \
  --bucket "${BUCKET}" \
  --region "${REGION}" \
  --create-bucket-configuration LocationConstraint="${REGION}"

echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket "${BUCKET}" \
  --versioning-configuration Status=Enabled

echo "Enabling default encryption..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Blocking all public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "Done. Set this bucket name in backend.tf."