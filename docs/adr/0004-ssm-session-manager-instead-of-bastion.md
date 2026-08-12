# ADR 0004: Use SSM Session Manager for administrative access

## Status
Accepted

## Context
Application instances run in private subnets and are not directly
reachable. Shell access is still needed for troubleshooting.

The conventional approach is a bastion host in a public subnet with
SSH exposed. That requires an internet-facing SSH port, long-lived
private key material stored on the operator's machine, and an
additional instance to run, patch, and pay for.

## Decision
Use AWS Systems Manager Session Manager. Instances receive an IAM
instance profile granting SSM access and reach the service through
outbound connections only.

## Consequences
- No inbound ports are open on application instances.
- No SSH key material exists in this repository or on any instance.
- No bastion host to run or maintain.
- Every session is authenticated via IAM and logged to CloudTrail.
- Access depends on the instance having outbound connectivity (via NAT)
  and a correctly attached instance profile — a misconfigured IAM role
  means no access at all, which is a real failure mode to be aware of.