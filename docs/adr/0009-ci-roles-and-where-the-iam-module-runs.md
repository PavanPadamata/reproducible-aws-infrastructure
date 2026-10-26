# ADR 0009: Two CI roles, and the iam module runs from bootstrap

## Status
Accepted. Details how ADR 0006 is implemented.

## Context
ADR 0006 chose GitHub Actions authenticating to AWS with OIDC. Three
design questions follow from it:

1. One CI role, or several?
2. How does the trust policy tell a legitimate job from an illegitimate one?
3. Which Terraform configuration creates the OIDC provider and the roles?

## Decision

**Two roles, split by what the job needs.**
- `ci-plan` is assumed by pull request workflows. It carries the AWS
  managed `ReadOnlyAccess` policy and can write only `.tflock` objects in
  the state bucket, never the state itself.
- `ci-apply` is assumed by the protected apply workflow. It can change the
  infrastructure, within limits described below.

A pull request is untrusted until reviewed, so the identity that runs on
it must not be able to change anything.

**Trust policies check both `aud` and `sub`, with `StringEquals`.**
- `aud` must be `sts.amazonaws.com`.
- `sub` for `ci-plan` is `repo:OWNER/REPO:pull_request`.
- `sub` for `ci-apply` is `repo:OWNER/REPO:environment:NAME`.

GitHub puts the Environment name in `sub` instead of the branch whenever a
job uses an Environment. The branch restriction is therefore a GitHub
setting (the Environment's deployment branch rule, limited to `main`),
and it must be configured for the apply role to be safe. The module
rejects wildcards in the repository name, and uses `StringEquals`, so a
trust policy can never match more than one repository.

**The `iam` module is called from `bootstrap/`, not `envs/dev`.** The OIDC
provider and the CI roles are long-lived and account-wide. `envs/dev` is
destroyed after every session (ADR 0002); if it owned the CI roles, a
destroy would remove the access CI needs to apply again. `bootstrap/`
already holds the state bucket, which has the same lifetime.

## Alternatives rejected
- **One role for both.** Simpler, but every pull request job would hold
  apply permissions.
- **Scoping apply by branch** (`sub = repo:OWNER/REPO:ref:refs/heads/main`).
  Works only for jobs that do not use an Environment, and the Environment's
  required reviewer is the approval gate this project wants.
- **`AdministratorAccess` on the apply role.** Easy, and a compromised job
  could do anything in the account.
- **Calling `iam` from `envs/dev`.** Ties the CI identity to a
  disposable environment.

## Consequences
- Bootstrap order: someone with their own AWS credentials applies
  `bootstrap/` first. CI cannot create the access it needs to start.
- The apply policy is scoped by **service**, not by individual action:
  `ec2`, `rds` and `logs` within one region, and S3 and IAM only for names
  starting with the project prefix. It is a starting point, not a
  minimum. After a real apply, CloudTrail shows which actions were used,
  and the policy can be narrowed to those.
- The policy denies the apply role any change to the CI roles, the OIDC
  provider and the state bucket itself, because their names match the
  project prefix and the allow statements would otherwise cover them.
- **Residual risk.** The apply role can create IAM roles with the project
  prefix and put inline policies on them. Without a permissions boundary,
  that is a possible path to more privilege than intended. Attaching
  managed policies is restricted to an approved list. The Environment's
  required reviewer is the main control; a permissions boundary on created
  roles is the next hardening step.
- `ReadOnlyAccess` on the plan role is broader than the services in use.
  It cannot modify anything.
- None of these policies has been applied to a real account yet. Expect
  `AccessDenied` events on the first run and fix them from CloudTrail.
