# iam module

Lets GitHub Actions run Terraform against AWS **without stored access keys**,
using OpenID Connect (OIDC). Creates:

| Resource | Purpose |
|----------|---------|
| OIDC provider (optional) | Tells AWS to accept tokens signed by GitHub |
| `<prefix>-ci-plan` role | Assumed by pull request jobs. Read-only; can write only `.tflock` objects in the state bucket |
| `<prefix>-ci-apply` role | Assumed by jobs in the protected GitHub Environment. Can change the project's infrastructure |

## Usage

This module is called from `bootstrap/`, not from `envs/dev`, because the
CI identity must outlive the disposable environment
([ADR 0009](../../docs/adr/0009-ci-roles-and-where-the-iam-module-runs.md)).

```hcl
module "iam" {
  source = "../modules/iam"

  name_prefix       = "myproj-dev"
  github_repository = "owner/repo"
  state_bucket_name = "myproj-tfstate-bucket"
}
```

## How a job gets credentials

1. GitHub issues the workflow run a signed token.
2. The workflow's `configure-aws-credentials` step presents it to AWS STS
   with a role ARN.
3. AWS checks the signature against the OIDC provider, then checks the
   token's claims against the role's trust policy.
4. If `aud` and `sub` both match exactly, STS returns credentials valid for
   one hour.

| Role | Required `sub` claim |
|------|----------------------|
| plan | `repo:OWNER/REPO:pull_request` |
| apply | `repo:OWNER/REPO:environment:NAME` |

## Settings this module cannot make for you

The apply role is only as safe as the GitHub Environment in front of it.
In the repository settings, the Environment named by `apply_environment`
needs **required reviewers** and a **deployment branch rule limited to
`main`**. Without them, any workflow that names the Environment can assume
the apply role.

## Limits

- The apply policy is scoped by service, not by action. It is a starting
  point to be narrowed from CloudTrail after a real apply.
- Not applied to a real AWS account yet; expect to adjust permissions on
  the first run.
- Residual privilege-escalation risk, and the planned permissions boundary,
  are described in ADR 0009.

## Tests

```bash
cd modules/iam
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
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_openid_connect_provider) | resource |
| [aws_iam_role.ci_apply](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ci_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ci_apply_infrastructure](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ci_apply_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ci_plan_state](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ci_plan_read_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_openid_connect_provider.github](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_allowed_region"></a> [allowed\_region](#input\_allowed\_region) | The only region the apply role may create regional resources in. | `string` | `"eu-central-1"` | no |
| <a name="input_apply_environment"></a> [apply\_environment](#input\_apply\_environment) | Name of the GitHub Environment whose jobs may assume the apply role. Protect that environment with required reviewers and a deployment branch rule restricted to main. | `string` | `"dev"` | no |
| <a name="input_create_github_oidc_provider"></a> [create\_github\_oidc\_provider](#input\_create\_github\_oidc\_provider) | Create the GitHub OIDC provider. An account can hold only one per URL, so set false if it already exists and it will be looked up instead. | `bool` | `true` | no |
| <a name="input_github_repository"></a> [github\_repository](#input\_github\_repository) | GitHub repository allowed to assume the CI roles, as "owner/name". No wildcards: a trust policy that matches more than one repository lets other repositories assume the role. | `string` | n/a | yes |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum lifetime in seconds of the credentials a CI job receives. One hour is the minimum and is enough for a plan or apply. | `number` | `3600` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for the names of the roles this module creates, and the prefix the apply role is allowed to manage, for example "myproj-dev". | `string` | n/a | yes |
| <a name="input_state_bucket_name"></a> [state\_bucket\_name](#input\_state\_bucket\_name) | Name of the S3 bucket that holds Terraform state. The CI roles are granted access to it. | `string` | n/a | yes |
| <a name="input_state_key_prefix"></a> [state\_key\_prefix](#input\_state\_key\_prefix) | Prefix of the state objects inside the bucket. The CI roles can only touch keys under it. | `string` | `"envs/"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ci_apply_role_arn"></a> [ci\_apply\_role\_arn](#output\_ci\_apply\_role\_arn) | ARN of the role the protected apply workflow assumes to run terraform apply. |
| <a name="output_ci_plan_role_arn"></a> [ci\_plan\_role\_arn](#output\_ci\_plan\_role\_arn) | ARN of the read-only role pull request workflows assume to run terraform plan. |
| <a name="output_github_oidc_provider_arn"></a> [github\_oidc\_provider\_arn](#output\_github\_oidc\_provider\_arn) | ARN of the GitHub OIDC provider the CI roles trust. |
<!-- END_TF_DOCS -->
