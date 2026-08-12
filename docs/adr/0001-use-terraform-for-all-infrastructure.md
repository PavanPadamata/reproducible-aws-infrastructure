# ADR 0001: Use Terraform for all infrastructure

## Status
Accepted

## Context
The environment must be reproducible: created and destroyed repeatedly
with identical results. Console-created ("ClickOps") infrastructure
cannot be reproduced, reviewed, or torn down reliably.

Alternatives considered: AWS CloudFormation (AWS-native, no state file
to manage, but AWS-only and more verbose); AWS CDK (real programming
language, but adds an abstraction layer over CloudFormation that
obscures what is actually provisioned); Pulumi (capable, far less
common in German job listings).

## Decision
Use Terraform (OpenTofu-compatible HCL) for all infrastructure.

## Consequences
- Terraform state becomes a critical artifact requiring secure,
  durable storage (see ADR 0003).
- Provider versions must be pinned via .terraform.lock.hcl.
- Skills transfer across cloud providers.
- Every resource is reviewable in a pull request before it exists.