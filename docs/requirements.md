# Requirements and Constraints

## Overview

A small web application and its supporting AWS infrastructure, defined
entirely in Terraform. The environment is provisioned on demand,
verified, and destroyed — nothing runs permanently. The deliverable is
the code and documentation, not a live system.

## Functional Requirements

- Serves HTTP/HTTPS traffic from a public endpoint
- Application instances run in private subnets, not directly reachable
  from the internet
- Traffic is distributed across at least two Availability Zones
- Loss of a single instance does not take the service down
- Application data is stored in a managed database, unreachable from
  the internet
- The entire environment is created and destroyed by a single command

## Non-Functional Requirements

- **Reproducibility:** repeated destroy/apply cycles produce an
  equivalent working system
- **Security:** least-privilege IAM, no long-lived credentials on
  instances, no plaintext secrets in the repository
- **Data residency:** all resources in eu-central-1 (Frankfurt)
- **Auditability:** consistent resource tagging, CloudTrail enabled
- **Observability:** basic CloudWatch metrics, logs, and one alarm

## Constraints

- **Cost:** AWS Free Tier, student budget. Resources billed hourly are
  destroyed when not in active use.
- **Ephemeral by design:** no permanently running compute. This is a
  deliberate constraint that shapes the architecture — it forces the
  infrastructure to be genuinely reproducible rather than hand-repaired.
- **Learning priority:** where a simpler and a more production-complete
  option both teach the same concept, the simpler one is chosen.

## Non-Goals

Deliberately out of scope for this project:

- Kubernetes or any container orchestration
- CI/CD pipelines (covered in a later project)
- Multi-region or disaster recovery
- Production traffic, real users, or SLAs
- Autoscaling based on real load patterns
- Centralised secrets management (Vault, Secrets Manager rotation)

## Success Criteria

This project is complete when:

1. `terraform destroy` followed by `terraform apply` produces a working
   system with no manual intervention
2. Application instances have no public IP addresses
3. The database is unreachable from outside the VPC
4. No credentials or state files exist in Git history
5. Architecture decisions are recorded with their trade-offs
6. Estimated running cost is documented per component