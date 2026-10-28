# ADR 0011: Plan on pull request, apply and destroy started by hand

## Status
Accepted. Amends ADR 0006: "apply on merge to `main`" is replaced by a
manually started workflow. Everything else in ADR 0006 stands.

## Context
ADR 0006 says to plan on pull request and apply on merge to `main`, behind a
GitHub Environment that requires approval. ADR 0002 says the environment is
created at the start of a working session, destroyed at the end, and that
nothing runs permanently except the state bucket.

`envs/dev` contains a NAT Gateway, an RDS instance and an EC2 instance, all
of which bill by the hour. Applying on every merge would create them on every
merge, including a merge that only fixes a typo in the README, and leave them
running until someone remembers to destroy them. The two ADRs disagree.

## Decision
Three workflows in `.github/workflows/`:

- **`checks.yml`** runs on every pull request and every push to `main`, with
  no AWS access. Job `lint` runs the pre-commit hooks (fmt, validate, tflint,
  terraform-docs, file hygiene). Job `test` runs `terraform test` in each
  module and in `bootstrap/`. Job `security` runs trivy on the Terraform
  (failing on HIGH and CRITICAL) and gitleaks over the full history.
- **`plan.yml`** runs on pull requests that touch `envs/` or `modules/`. It
  assumes the read-only `ci-plan` role and shows `terraform plan` in the job
  summary. It is skipped for forks and until the repository variables exist.
- **`apply.yml`** is started by hand (`workflow_dispatch`) with a choice of
  `apply` or `destroy`. It runs only on `main`, in the `dev` Environment
  (which needs reviewer approval), assumes the `ci-apply` role, saves a plan
  and applies exactly that plan. One run at a time; a running one is never
  cancelled.

The role ARNs and the state bucket name are repository **variables**
(`AWS_PLAN_ROLE_ARN`, `AWS_APPLY_ROLE_ARN`, `TF_STATE_BUCKET`), set after
`bootstrap/` is applied. They are not secrets: an ARN grants nothing without a
token that GitHub signs for this repository and Environment.

Every action is pinned to a full commit SHA, with the release in a comment.
Tools downloaded by hand are checked against a pinned SHA-256. Dependabot
opens pull requests for updates.

## Alternatives rejected
- **Apply on every merge (ADR 0006 as written).** Every merge, docs included,
  would ask for approval and then create the full environment. Highest cost
  risk, and it contradicts ADR 0002.
- **Apply on merge only when infrastructure files change.** Docs merges do
  nothing, but each infrastructure merge still leaves billed resources running
  and relies on remembering to destroy them.
- **A plan job and an apply job, with approval between them.** Lets the
  reviewer read the plan before approving. The plan job would need the apply
  role (the plan role trusts only `pull_request` tokens), or a second approval
  gate. Worth doing later; not needed for one environment and one maintainer.

## Consequences
- Nothing bills until someone starts the workflow, and `destroy` is the same
  workflow with a different choice.
- The reviewer approves before the job starts, so they have not yet seen the
  plan of that run. The pull request's plan summary is what they should read.
- The repository is public, so logs and job summaries are public. Terraform
  hides values marked sensitive and the account ID is masked, but resource
  names and IDs appear in plans.
- Fork pull requests get no plan. A fork's workflow code is not reviewed, and
  AWS would reject its token.
- The pre-commit gitleaks hook scans staged changes only, so CI runs gitleaks
  separately over the full history.
- Nothing in these workflows has run on GitHub. They are checked with
  `actionlint` only, so expect the first runs to need small fixes. The first
  real apply is also expected to hit `AccessDenied` on the apply role (see
  ADR 0009).
- The `dev` Environment's required reviewers and its deployment branch rule
  are repository settings, not code. They must be configured by hand.
