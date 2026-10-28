# ADR 0006: Add CI/CD with GitHub Actions, authenticated by OIDC

## Status
Accepted. Supersedes the "CI/CD pipelines" entry under Non-Goals in
`docs/requirements.md`, which deferred pipelines to a later project.

## Context
The project's purpose has widened from "infrastructure that can be
rebuilt" to "infrastructure that is changed the way a team changes it":
every change reviewed, planned and applied by automation instead of from
a laptop. Pipelines are therefore in scope.

CI needs AWS access. Long-lived access keys stored as repository secrets
are the common shortcut, but they never expire, must be rotated by hand,
and leak whenever a log, fork or workflow is misconfigured.

## Decision
- Use **GitHub Actions**: plan on pull request, apply on merge to `main`
  behind a GitHub Environment that requires reviewer approval.
- Authenticate to AWS with **OpenID Connect**. GitHub issues a short-lived
  signed token per workflow run; an IAM role trusts GitHub's OIDC
  provider and is assumed with `sts:AssumeRoleWithWebIdentity`. No AWS
  access keys are stored anywhere.
- The role's trust policy is scoped to this repository (and, for apply,
  to the `main` branch or the protected environment) through the token's
  `sub` claim. A trust policy that only names the provider would let any
  repository on GitHub assume the role.

## Alternatives rejected
- **Static IAM user keys in GitHub secrets.** Long-lived credentials,
  the exact thing the requirements forbid.
- **Self-hosted Jenkins or GitLab CI.** A server to run, patch and
  secure, for no benefit on a repository already hosted on GitHub.
- **Atlantis or HCP Terraform.** Capable, but each adds a service or an
  account; the aim is to understand the primitives first.

## Consequences
- The `iam` module owns the OIDC provider and the CI role, so the most
  privileged resource in the repository is reviewed like any other code.
- The CI role can change infrastructure, so its permissions are the
  blast radius of a compromised workflow. They are scoped as tightly as
  the modules allow and documented.
- Bootstrap order: the OIDC provider and CI role must first be created
  by hand (with a human's credentials), because CI cannot create the
  access it needs to run. The manual steps are listed in the README.
- Standard GitHub-hosted runners are free for public repositories, so
  CI adds no AWS bill beyond what the plans and applies create.
