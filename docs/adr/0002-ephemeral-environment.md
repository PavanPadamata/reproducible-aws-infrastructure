# ADR 0002: Provision the environment on demand rather than continuously

## Status
Accepted

## Context
This is a learning project on a student budget. Several components
(NAT Gateway, ALB, RDS) bill hourly regardless of traffic. Leaving them
running would cost roughly €50-60/month for an environment with no
users.

## Decision
The environment is provisioned at the start of a working session and
destroyed at the end. Nothing runs permanently except the Terraform
state bucket. Evidence of correct operation (outputs, screenshots,
CloudWatch graphs) is committed to the repository instead.

## Consequences
- Running cost drops to cents per session. A NAT Gateway at roughly
  $0.052/hour costs about $0.21 for a four-hour session.
- Reproducibility is continuously verified rather than assumed — every
  session is a full rebuild test.
- Nothing may be repaired by hand in the console; a manual fix would be
  lost on the next destroy. All changes go through Terraform.
- There is no permanent demo URL. The environment can be brought up on
  request.