# Contributing

This is a personal learning project, but it is maintained the way a
team repository would be. These rules apply to every change, including
the maintainer's own.

## Workflow

1. Branch from `main`. One logical change per branch.
2. Name the branch `<type>/<short-description>`, for example
   `feat/ec2-module` or `docs/readme`.
3. Make small commits. Explain *why* in the commit body, not only *what*.
4. Open a pull request and fill in the template.
5. Merge only after review and passing checks.

Never push directly to `main`.

## Commit messages

Conventional Commits:

```
<type>(<optional scope>): <summary in the imperative, under 72 chars>

<body: why the change was needed>
```

Types: `feat`, `fix`, `docs`, `ci`, `chore`, `refactor`.

## Local setup

Install the tools listed below, then enable the hooks once per clone:

```bash
pre-commit install
pre-commit run --all-files
```

| Tool | Used for |
|---|---|
| Terraform (version in `.terraform-version`) | `fmt`, `validate`, `plan` |
| TFLint | linting, config in `.tflint.hcl` |
| terraform-docs | generating module README tables |
| pre-commit | running all of the above on commit |
| gitleaks | secret scanning |

## Rules for Terraform changes

- Run `terraform fmt` and `terraform validate` before committing.
- Every variable has a `type` and a `description`; add `validation`
  blocks where a bad value would otherwise fail late and obscurely.
- Pin versions: Terraform, providers (`~>`), modules, and GitHub Actions.
- Commit `.terraform.lock.hcl`. Never commit state, plan files or
  `*.tfvars` (only `*.tfvars.example`).
- Prefer secure defaults. Anything that costs money while idle (NAT
  Gateway, RDS, running EC2) must be explicit and documented.
- Do not run `terraform apply` or `destroy` against an AWS account
  without reading the plan first.

## Decisions

A choice between real alternatives (a pattern, a service, a trade-off)
gets an Architecture Decision Record in `docs/adr/`. ADRs are
append-only: to change a decision, add a new ADR that supersedes the
old one.
