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
<!-- END_TF_DOCS -->
