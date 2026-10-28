# bootstrap

The pieces that must exist before anything else can run, and must outlive
the disposable `dev` environment. Applied **once**, by a person with their
own AWS credentials. Creates:

| Resource | Purpose |
|----------|---------|
| S3 bucket `<project>-tfstate-<account id>` | Holds Terraform state for every environment. Versioned, encrypted, private (the [s3 module](../modules/s3/README.md)) |
| GitHub OIDC provider (optional) | Lets AWS accept tokens signed by GitHub |
| `<project>-ci-plan` and `<project>-ci-apply` roles | What CI assumes to plan and apply (the [iam module](../modules/iam/README.md)) |

Why these live here and not in `envs/dev`:
[ADR 0005](../docs/adr/0005-s3-native-locking-and-terraform-bootstrap.md),
[ADR 0009](../docs/adr/0009-ci-roles-and-where-the-iam-module-runs.md) and
[ADR 0010](../docs/adr/0010-state-bucket-from-the-s3-module-and-partial-backend.md).

## Run it

> **Never applied.** This has only been checked offline (`validate`,
> `tflint`, `trivy`, `terraform test` with a mock provider). Expect to
> correct this page after the first real run.

1. Have AWS credentials for the target account. This configuration keeps
   its own state in a local file, so nothing else is needed first.
2. `cp terraform.tfvars.example terraform.tfvars`, then set
   `github_repository`. If the account already has a GitHub OIDC provider,
   set `create_github_oidc_provider = false`.
3. `terraform init`, `terraform plan`, read the plan, then `terraform apply`.
4. Point `envs/dev` at the bucket: copy `envs/dev/backend.hcl.example` to
   `backend.hcl`, put the `state_bucket_name` output in it, and run
   `terraform init -backend-config=backend.hcl` there.
5. In the GitHub repository settings, protect the Environment named by
   `apply_environment` with required reviewers and a deployment branch rule
   limited to `main`. The apply role is not safe without it.

**Keep `terraform.tfstate` in this directory.** It is git-ignored and is the
only record that these resources belong to Terraform. If it is lost, the
resources have to be brought back with `terraform import`.

## Cost

No resource here bills by the hour. The bucket is billed for the storage and
requests it uses, which for state files is small; IAM roles and the OIDC
provider are free. No price is quoted because none has been measured.

TODO(measure): monthly cost of the state bucket after a few weeks of use.

## Tear down

A deliberate, manual step. `terraform destroy` here fails while the bucket
holds any object, version or delete marker (`force_destroy = false`). Destroy
every environment first, empty the bucket including all versions and delete
markers, then destroy `bootstrap/`.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_apply_environment"></a> [apply\_environment](#input\_apply\_environment) | Name of the GitHub Environment whose jobs may assume the apply role. Protect it with required reviewers and a deployment branch rule restricted to main (ADR 0009). | `string` | `"dev"` | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for the state bucket and regional resources. Frankfurt, for EU data residency. | `string` | `"eu-central-1"` | no |
| <a name="input_create_github_oidc_provider"></a> [create\_github\_oidc\_provider](#input\_create\_github\_oidc\_provider) | Create the GitHub OIDC provider. An account can hold only one per URL; set false if it already exists and it will be looked up instead. | `bool` | `true` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository allowed to assume the CI roles, as "owner/name". No wildcards. | `string` | n/a | yes |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Short project identifier. Prefixes the state bucket and the CI roles, and is the prefix the apply role is allowed to manage. | `string` | `"reproducible-aws-infra"` | no |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | Prefix of the state objects inside the bucket. The CI roles can only touch keys under it, so each environment's key must start with it. | `string` | `"envs/"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ci_apply_role_arn"></a> [ci\_apply\_role\_arn](#output\_ci\_apply\_role\_arn) | ARN of the role the protected apply workflow assumes to run terraform apply. |
| <a name="output_ci_plan_role_arn"></a> [ci\_plan\_role\_arn](#output\_ci\_plan\_role\_arn) | ARN of the read-only role pull request workflows assume to run terraform plan. |
| <a name="output_github_oidc_provider_arn"></a> [github\_oidc\_provider\_arn](#output\_github\_oidc\_provider\_arn) | ARN of the GitHub OIDC provider the CI roles trust. |
| <a name="output_state_bucket_arn"></a> [state\_bucket\_arn](#output\_state\_bucket\_arn) | ARN of the state bucket. |
| <a name="output_state_bucket_name"></a> [state\_bucket\_name](#output\_state\_bucket\_name) | Name of the S3 bucket that holds Terraform state. Pass it to `terraform init -backend-config="bucket=..."` in each environment. |
<!-- END_TF_DOCS -->
