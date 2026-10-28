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
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | ~> 6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_instance_profile.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.al2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_additional_policy_arns"></a> [additional\_policy\_arns](#input\_additional\_policy\_arns) | Extra managed policies to attach to the instance role, for example access to an S3 bucket. | `list(string)` | `[]` | no |
| <a name="input_ami_id"></a> [ami\_id](#input\_ami\_id) | AMI to launch. Null looks up the newest Amazon Linux 2023 image on every plan, which replaces the instance when a new image is published. Pin an ID for a stable environment. | `string` | `null` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Give the instance a public IP address. Leave false for private subnets; Session Manager does not need one. | `bool` | `false` | no |
| <a name="input_egress_rules"></a> [egress\_rules](#input\_egress\_rules) | Outbound security group rules. The default allows HTTPS out, which Session Manager and package repositories need. | <pre>list(object({<br/>    description                  = string<br/>    from_port                    = number<br/>    to_port                      = number<br/>    ip_protocol                  = optional(string, "tcp")<br/>    cidr_ipv4                    = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "cidr_ipv4": "0.0.0.0/0",<br/>    "description": "HTTPS to anywhere for Session Manager and package repositories",<br/>    "from_port": 443,<br/>    "to_port": 443<br/>  }<br/>]</pre> | no |
| <a name="input_enable_ssm"></a> [enable\_ssm](#input\_enable\_ssm) | Attach AmazonSSMManagedInstanceCore so the instance can be reached with Session Manager, with no SSH and no open inbound port. | `bool` | `true` | no |
| <a name="input_ingress_rules"></a> [ingress\_rules](#input\_ingress\_rules) | Inbound security group rules. Empty by default: Session Manager needs no inbound access. | <pre>list(object({<br/>    description                  = string<br/>    from_port                    = number<br/>    to_port                      = number<br/>    ip_protocol                  = optional(string, "tcp")<br/>    cidr_ipv4                    = optional(string)<br/>    referenced_security_group_id = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | EC2 instance type. Billed per hour while the instance exists. | `string` | `"t3.micro"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key to encrypt the root volume with. Null uses the AWS-managed EBS key. The volume is always encrypted. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of the instance, also used to name its role and security group, for example "myproj-dev-app". | `string` | n/a | yes |
| <a name="input_root_volume_size_gb"></a> [root\_volume\_size\_gb](#input\_root\_volume\_size\_gb) | Size of the root volume in GiB. | `number` | `8` | no |
| <a name="input_subnet_id"></a> [subnet\_id](#input\_subnet\_id) | ID of the subnet to launch the instance in. Use a private subnet unless the instance must be reachable from the internet. | `string` | n/a | yes |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | Script to run on first boot. Changing it replaces the instance. Must not contain secrets: it is readable from the instance and from the console. | `string` | `null` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC the security group is created in. | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_iam_role_arn"></a> [iam\_role\_arn](#output\_iam\_role\_arn) | ARN of the instance's IAM role. |
| <a name="output_iam_role_name"></a> [iam\_role\_name](#output\_iam\_role\_name) | Name of the instance's IAM role, for attaching further policies. |
| <a name="output_instance_id"></a> [instance\_id](#output\_instance\_id) | ID of the instance. Pass it to `aws ssm start-session --target` to open a shell. |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP address of the instance. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the instance's security group, for other resources to allow traffic from or to it. |
<!-- END_TF_DOCS -->
