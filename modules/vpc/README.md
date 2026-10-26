# vpc module

A three-tier network across two or three Availability Zones:

| Tier | Route to the internet | Intended for |
|------|-----------------------|--------------|
| public | Internet Gateway | load balancers, the NAT Gateway |
| app | NAT Gateway, only if `enable_nat_gateway` is true | EC2 instances |
| data | none, not even outbound | databases |

The data tier has no `0.0.0.0/0` route at all, so isolation comes from
routing, not only from security groups.

## Usage

```hcl
module "vpc" {
  source = "../../modules/vpc"

  name_prefix        = "myproj-dev"
  enable_nat_gateway = true
}
```

## Design notes

- **NAT Gateway is off by default.** It bills hourly whether or not traffic
  flows, so a consumer has to ask for it. Without it, instances in the app
  tier have no route out and cannot reach Systems Manager. See
  [ADR 0008](../../docs/adr/0008-nat-gateway-opt-in-and-ssm-connectivity.md).
- **One NAT Gateway serves every zone.** Losing its zone cuts outbound
  traffic for the others. Accepted as a cost decision.
- **The default security group is emptied.** The module adopts the VPC's
  default security group and removes every rule, so nothing is allowed by
  accident.
- **Flow logs are optional** (`enable_flow_logs`), also off by default.
- **Subnets use `for_each` keyed by zone name,** so removing a zone does not
  shift the others and force recreation.

## Not validated

The three subnet lists are checked for valid CIDRs and for having at least
`az_count` entries. They are **not** checked for overlap or for falling
inside `vpc_cidr`; AWS rejects those at apply time.

## Tests

```bash
cd modules/vpc
terraform init -backend=false
terraform test
```

The tests use a mock provider, so they need no AWS credentials and create
nothing.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
