# ADR 0002: Provision the environment on demand rather than continuously

## Status
Accepted

## Context
This is a learning project on a student budget. Several components
(NAT Gateway, ALB, RDS) bill hourly regardless of traffic. Leaving them
running would be a recurring monthly cost for an environment with no
users. TODO(measure): monthly cost of leaving the environment running,
taken from the AWS Pricing Calculator or Cost Explorer.

## Decision
The environment is provisioned at the start of a working session and
destroyed at the end. Nothing runs permanently except the Terraform
state bucket. Evidence of correct operation (outputs, screenshots,
CloudWatch graphs) is committed to the repository instead.

## Consequences
- Running cost is limited to the hours the environment exists, instead
  of every hour of the month. TODO(measure): cost of one session,
  from Cost Explorer after a real apply and destroy.
- Reproducibility is continuously verified rather than assumed — every
  session is a full rebuild test.
- Nothing may be repaired by hand in the console; a manual fix would be
  lost on the next destroy. All changes go through Terraform.
- There is no permanent demo URL. The environment can be brought up on
  request.