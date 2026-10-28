# ADR 0008: NAT Gateway is opt-in, and SSM connectivity depends on it

## Status
Accepted.

## Context
ADR 0004 chose Systems Manager Session Manager instead of a bastion host,
and instances run in private subnets with no public IP. Session Manager
works through the instance opening an outbound connection to the Systems
Manager service. A private instance therefore needs some path to that
service, or it cannot be reached at all.

Two paths exist:

1. A **NAT Gateway**, which also gives the instance general outbound
   access (package updates).
2. **VPC interface endpoints** for `ssm`, `ssmmessages` and `ec2messages`,
   which keep traffic inside AWS but reach only those services.

Both bill by the hour while they exist (ADR 0002). A reusable module that
creates one by default would charge anyone who tries it.

## Decision
- The `vpc` module creates **no** NAT Gateway by default
  (`enable_nat_gateway = false`).
- `envs/dev` sets `enable_nat_gateway = true` explicitly, with a comment,
  so the cost driver is visible in the code that creates it.
- Interface endpoints are **not built**. They are the documented
  alternative.

## Alternatives rejected
- **NAT on by default.** Simplest to use, but it makes the cost an
  invisible default instead of a choice.
- **SSM interface endpoints, built now.** Avoids the NAT, but the three
  endpoints bill per endpoint per zone, give no general outbound access,
  and add code to explain. Worth building only if package access is not
  needed.
- **Put the instance in a public subnet with a public IP.** Removes both
  costs but breaks the requirement that application instances have no
  public IP address.

## Consequences
- Using the `vpc` module with defaults and then launching an instance in
  the app tier gives an instance nobody can reach through Session Manager.
  This is the misconfiguration ADR 0004 warned about, now documented in the
  module README as well.
- The dev environment pays the NAT Gateway cost for as long as it exists,
  which is bounded by destroying it after each session.
- Switching to endpoints later is an additive change: a new variable and
  resources, with no change to existing ones.
