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
| [aws_cloudwatch_log_group.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_default_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/default_security_group) | resource |
| [aws_eip.nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eip) | resource |
| [aws_flow_log.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/flow_log) | resource |
| [aws_iam_role.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.flow](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_internet_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_nat_gateway.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/nat_gateway) | resource |
| [aws_route.app_nat](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.data](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.public](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.main](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_app_subnet_cidrs"></a> [app\_subnet\_cidrs](#input\_app\_subnet\_cidrs) | CIDRs for private application subnets, one per Availability Zone. | `list(string)` | <pre>[<br/>  "10.0.10.0/24",<br/>  "10.0.11.0/24"<br/>]</pre> | no |
| <a name="input_az_count"></a> [az\_count](#input\_az\_count) | Number of Availability Zones to span. Two is the minimum for ALB and RDS subnet groups. | `number` | `2` | no |
| <a name="input_data_subnet_cidrs"></a> [data\_subnet\_cidrs](#input\_data\_subnet\_cidrs) | CIDRs for private database subnets, one per Availability Zone. | `list(string)` | <pre>[<br/>  "10.0.20.0/24",<br/>  "10.0.21.0/24"<br/>]</pre> | no |
| <a name="input_enable_flow_logs"></a> [enable\_flow\_logs](#input\_enable\_flow\_logs) | Send VPC flow logs to CloudWatch Logs. Off by default: log ingestion and storage are billed. | `bool` | `false` | no |
| <a name="input_enable_nat_gateway"></a> [enable\_nat\_gateway](#input\_enable\_nat\_gateway) | Create a NAT Gateway so the app subnets can reach the internet. Billed hourly while it exists, so it is off by default. | `bool` | `false` | no |
| <a name="input_flow_log_retention_days"></a> [flow\_log\_retention\_days](#input\_flow\_log\_retention\_days) | Days to keep flow logs in CloudWatch Logs. Must be a retention value CloudWatch accepts. | `number` | `14` | no |
| <a name="input_flow_log_traffic_type"></a> [flow\_log\_traffic\_type](#input\_flow\_log\_traffic\_type) | Which traffic to log when flow logs are enabled: ACCEPT, REJECT or ALL. | `string` | `"ALL"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for the Name tag of every resource, for example "myproj-dev". | `string` | n/a | yes |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDRs for public subnets, one per Availability Zone. | `list(string)` | <pre>[<br/>  "10.0.0.0/24",<br/>  "10.0.1.0/24"<br/>]</pre> | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for the VPC. /16 leaves room to add tiers without renumbering. | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_app_subnet_ids"></a> [app\_subnet\_ids](#output\_app\_subnet\_ids) | IDs of the private application subnets, keyed by Availability Zone. |
| <a name="output_availability_zones"></a> [availability\_zones](#output\_availability\_zones) | Availability Zones the subnets are spread across. |
| <a name="output_data_subnet_ids"></a> [data\_subnet\_ids](#output\_data\_subnet\_ids) | IDs of the private database subnets, keyed by Availability Zone. |
| <a name="output_nat_gateway_public_ip"></a> [nat\_gateway\_public\_ip](#output\_nat\_gateway\_public\_ip) | Public IP of the NAT Gateway, the source address for outbound traffic from the app subnets. Null when the NAT Gateway is disabled. |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | IDs of the public subnets, keyed by Availability Zone. |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC. |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC. |
<!-- END_TF_DOCS -->
