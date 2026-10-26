# ec2 module

One hardened EC2 instance, reachable through Systems Manager Session Manager
instead of SSH ([ADR 0004](../../docs/adr/0004-ssm-session-manager-instead-of-bastion.md)).

| Setting | Value |
|---------|-------|
| Metadata service | IMDSv2 required, hop limit 1 |
| Root volume | gp3, always encrypted |
| Public IP | None unless `associate_public_ip_address = true` |
| Inbound rules | None by default |
| Outbound rules | HTTPS only by default |
| SSH key pair | None |
| Access | Session Manager, via an instance profile with `AmazonSSMManagedInstanceCore` |

## Usage

```hcl
module "app" {
  source = "../../modules/ec2"

  name      = "myproj-dev-app"
  vpc_id    = module.vpc.vpc_id
  subnet_id = values(module.vpc.app_subnet_ids)[0]
}
```

Then open a shell without SSH:

```bash
aws ssm start-session --target <instance_id>
```

(Needs the Session Manager plugin for the AWS CLI.)

## Design notes

- **The instance must have a path to Systems Manager.** In a private subnet
  that means a NAT Gateway or VPC endpoints; with neither, the instance runs
  but cannot be reached. See
  [ADR 0008](../../docs/adr/0008-nat-gateway-opt-in-and-ssm-connectivity.md).
- **SSH and RDP from `0.0.0.0/0` are rejected** at plan time by a validation
  on `ingress_rules`, not left to review.
- **Rules reference security groups where possible.** A rule sourced from
  another group stays correct when the instances behind it are replaced.
- **`ami_id = null` follows the newest Amazon Linux 2023 image.** A new image
  changes the plan and replaces the instance. Pin an `ami_id` for an
  environment that should not change on its own.
- **`user_data` runs once, at first boot,** and changing it replaces the
  instance. Never put secrets in it; it is readable from the instance.
- **IMDSv2's hop limit of 1** also stops containers on the instance from
  reaching the metadata service. Raise it only if you run containers that
  need instance credentials.

## Tests

```bash
cd modules/ec2
terraform init -backend=false
terraform test
```

The tests use a mock provider, so they need no AWS credentials and create
nothing.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
