# ADR 0007: Initial scope is five modules and one instance

## Status
Accepted.

## Context
`docs/architecture.md` describes a full three-tier design: an Application
Load Balancer, an Auto Scaling group across two AZs, CloudTrail and
CloudWatch alarms. None of that exists yet, and a README or diagram that
presents it as built would be untrue.

The requirement "loss of a single instance does not take the service
down" needs an Auto Scaling group behind a load balancer. That is a
larger step than the foundation this project is meant to demonstrate
first.

## Decision
Deliver a smaller, complete foundation first, as five reusable modules:
`vpc`, `ec2`, `rds`, `s3` and `iam`, wired together in `envs/dev` with
a single EC2 instance.

The ALB, Auto Scaling group, CloudTrail and CloudWatch alarms stay in
the architecture document as the target design, labelled **planned**.
They are not described as built anywhere until they are.

## Alternatives rejected
- **Build the full design in one go.** More to explain, review and pay
  for, and the foundation modules would be written under time pressure.
- **Delete the unbuilt parts from the architecture document.** Loses
  the design intent, which is itself useful and reviewable.

## Consequences
- The functional requirements about multi-instance availability and a
  public HTTP endpoint are not met by the initial scope.
  `docs/requirements.md` says so explicitly.
- Each module is independently reusable and testable, which suits the
  reviewable, reproducible aim of the project.
- The ALB and Auto Scaling group are added later as separate modules
  and a new ADR, without reworking the five above.
