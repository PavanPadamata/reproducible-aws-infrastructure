# ADR 0003: Store Terraform state in S3 with locking

## Status
Accepted

## Context
Terraform state contains resource identifiers and sensitive values in
plaintext. Local state is lost if the machine is lost, leaving
provisioned resources orphaned and still billing. Concurrent runs
against the same local state can corrupt it.

## Decision
Store state in a versioned, encrypted, private S3 bucket in
eu-central-1, with state locking enabled. The bucket is created once
and persists between sessions.

## Consequences
- State survives machine loss; resources can always be destroyed.
- Versioning allows recovery from a corrupted or bad state write.
- The bucket is the one component that runs continuously. Cost is a few
  cents per month.
- Bootstrapping order matters: the bucket must exist before it can hold
  the state of everything else.