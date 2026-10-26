# reproducible-aws-infrastructure

[![License: MIT](https://img.shields.io/github/license/PavanPadamata/reproducible-aws-infrastructure)](LICENSE)

A reusable, reviewable AWS foundation written in Terraform: VPC, EC2, RDS,
S3 and IAM as separate modules, in `eu-central-1` (Frankfurt). The aim is
an environment that can be created, verified and destroyed repeatedly with
the same result, changed only through pull requests.

> **Status: work in progress.** Only the provider configuration and the
> documentation are on `main`. The tables below say exactly what is built
> and what is planned. Nothing here has been applied to an AWS account yet.

<!-- TODO(phase 4): add CI status badges once the workflows exist. -->

## Status

| Area | State |
|------|-------|
| Provider configuration, default tags, version pinning | Built |
| Architecture docs, requirements, ADRs 0001-0007 | Built |
| VPC, subnets, routing | Written on branch `feat/networking`, not yet merged |
| `ec2`, `rds`, `s3`, `iam` modules | Planned |
| Remote state bootstrap (`bootstrap/`) | Planned |
| CI: plan on pull request, apply on merge | Planned |
| Load balancer, Auto Scaling, CloudTrail, CloudWatch alarms | Planned, beyond the initial scope ([ADR 0007](docs/adr/0007-initial-scope-five-modules.md)) |

## Target architecture

This is the design the modules are being built towards, not a description
of deployed infrastructure.

```mermaid
flowchart TB
    Internet((Internet))
    Operator([Operator])

    subgraph VPC["VPC in eu-central-1, two Availability Zones"]
        IGW[Internet Gateway]

        subgraph Public["Public subnets"]
            NAT["NAT Gateway (optional, off by default)"]
        end

        subgraph App["Private app subnets"]
            EC2["EC2 instance: IMDSv2, encrypted EBS, SSM"]
        end

        subgraph Data["Private data subnets: no internet route"]
            RDS[("RDS: encrypted, not public")]
        end
    end

    S3[("S3 bucket: private, versioned, encrypted")]
    SSM[AWS Systems Manager]

    Internet <--> IGW
    NAT --> IGW
    EC2 -.->|outbound via NAT| NAT
    EC2 -->|database port| RDS
    Operator -->|Session Manager, no SSH| SSM
    SSM -.-> EC2
```

The database tier has no route to the internet at all, so isolation comes
from routing as well as from security groups. See
[docs/architecture.md](docs/architecture.md) for the full design and its
known limitations.

## Prerequisites

- An AWS account you control, and an IAM identity with permission to create
  the resources above
- Terraform at the version in [`.terraform-version`](.terraform-version)
  (the code requires `>= 1.11, < 2.0.0`)
- AWS CLI, configured for that account
- For contributing: `pre-commit`, `tflint`, `terraform-docs`, `gitleaks`
  (see [CONTRIBUTING.md](CONTRIBUTING.md))

## Quickstart

> **Not runnable yet.** `bootstrap/` and `envs/dev/` do not exist. This is
> the intended flow, to be confirmed and corrected once they do.

1. `cd bootstrap`, then `terraform init`, `plan` and `apply` to create the
   state bucket. This uses local state, once.
2. `cd envs/dev`, copy `terraform.tfvars.example` to `terraform.tfvars` and
   fill in your values. That file is git-ignored.
3. `terraform init`, `terraform plan`, then `terraform apply`.

## Tear down

> **Planned and untested.** The order matters, because the state bucket
> holds the state that `envs/dev` needs to destroy itself.

1. In `envs/dev`: `terraform destroy`.
2. Empty the state bucket. It is versioned, so every object version and
   delete marker must be removed, not only the current objects.
3. In `bootstrap/`: remove the `prevent_destroy` lifecycle guard
   ([ADR 0005](docs/adr/0005-s3-native-locking-and-terraform-bootstrap.md)),
   then `terraform destroy`.

TODO(measure): record the date the full destroy path was run end to end,
and anything that did not clean up.

## Cost drivers

These resources bill by the hour or by use whether or not anything is
happening. No prices are quoted here, because none have been measured.

| Driver | Why it costs |
|--------|--------------|
| NAT Gateway | Hourly charge plus per-GB data processing. Off by default in the VPC module. |
| RDS instance | Instance hours, plus storage and backups |
| EC2 instance | Instance hours, plus EBS volume |
| Public IPv4 addresses | Billed hourly, including the Elastic IP a NAT Gateway uses |
| VPC interface endpoints | Hourly per endpoint per AZ, if used instead of a NAT Gateway for SSM |

The environment is meant to be created for a working session and destroyed
afterwards ([ADR 0002](docs/adr/0002-ephemeral-environment.md)).

TODO(measure): cost of one apply-and-destroy session, from Cost Explorer.

## Modules

| Module | Purpose | State |
|--------|---------|-------|
| `vpc` | Two-AZ network with public, app and data tiers | Written on `feat/networking`, flat, not yet a module |
| `ec2` | Instance reachable through SSM, IMDSv2 required | Planned |
| `rds` | Private encrypted database, password in Secrets Manager | Planned |
| `s3` | Private bucket with versioning, encryption and TLS-only policy | Planned |
| `iam` | Least-privilege roles, GitHub OIDC provider and CI role | Planned |

## Repository layout

What exists today:

```
.
├── docs/
│   ├── adr/            architecture decision records
│   ├── architecture.md
│   ├── requirements.md
│   └── LEARNING.md     what was learned in each phase
├── scripts/            bootstrap-state.sh (to be replaced by bootstrap/)
├── providers.tf        AWS provider and default tags
├── variables.tf
├── versions.tf         Terraform and provider version pins
├── .pre-commit-config.yaml  .tflint.hcl  .terraform-docs.yml
└── .github/            CODEOWNERS, pull request template
```

## Decisions

| ADR | Decision |
|-----|----------|
| [0001](docs/adr/0001-use-terraform-for-all-infrastructure.md) | Terraform for all infrastructure |
| [0002](docs/adr/0002-ephemeral-environment.md) | Create and destroy per session, not run continuously |
| [0003](docs/adr/0003-remote-state-in-s3.md) | Remote state in S3 |
| [0004](docs/adr/0004-ssm-session-manager-instead-of-bastion.md) | Session Manager instead of a bastion host |
| [0005](docs/adr/0005-s3-native-locking-and-terraform-bootstrap.md) | S3 native locking, Terraform bootstrap |
| [0006](docs/adr/0006-ci-cd-with-github-actions-and-oidc.md) | GitHub Actions with OIDC |
| [0007](docs/adr/0007-initial-scope-five-modules.md) | Initial scope: five modules, one instance |

## Contributing and security

Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.
Report security problems privately as described in [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
