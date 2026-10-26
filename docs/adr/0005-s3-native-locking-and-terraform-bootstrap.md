# ADR 0005: S3 native state locking, and a Terraform bootstrap for the bucket

## Status
Accepted. Refines ADR 0003: the decision to keep state in S3 stands;
how the bucket is created and how locking works are decided here.

## Context
ADR 0003 chose S3 for state "with locking" without saying how. Two
questions were left open:

1. Which mechanism provides the lock?
2. How is the bucket itself created, given that it must exist before
   Terraform can use it as a backend?

`versions.tf` already requires Terraform 1.11 or newer, the release that
added native S3 locking (`use_lockfile = true`). The bucket was created
by `scripts/bootstrap-state.sh`, which fails if run twice, hardcodes the
region, and sets no bucket policy.

## Decision
**Locking:** use S3 native locking (`use_lockfile`). Terraform writes a
`.tflock` object next to the state file and removes it when the run ends.
No DynamoDB table is created.

**Bootstrap:** create the bucket with a small Terraform configuration in
`bootstrap/`, applied once with local state. It replaces the shell
script.

## Alternatives rejected
- **DynamoDB lock table.** The established approach and still common in
  existing projects, so it is worth being able to explain. Rejected
  because it adds a second resource to create, secure and pay for, to do
  something S3 can now do on its own.
- **Keep the shell script.** Rejected because it is imperative and not
  idempotent, and its settings cannot be reviewed in a pull request or
  checked by `tflint` and `trivy`.
- **HCP Terraform / Terraform Cloud for state.** Rejected to keep the
  project on plain AWS primitives and avoid another account.

## Consequences
- One resource fewer, and the lock lives where the state lives.
- The CI role needs `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject`
  on the state key and its `.tflock` object, not DynamoDB permissions.
- The bootstrap configuration still has a chicken-and-egg problem: it
  keeps its own state locally. That file is small and tracks only the
  bucket. It must not be committed (`*.tfstate` is ignored); if it is
  lost, the bucket is re-imported with `terraform import`.
- The bucket gets `prevent_destroy` so a stray `terraform destroy` in
  `bootstrap/` cannot delete every environment's state. Teardown of the
  bucket is a deliberate, documented, manual step.
- Anyone reading older tutorials will see `dynamodb_table`; this ADR is
  the answer to why this repository does not.
