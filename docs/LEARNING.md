# Learning log

One entry per phase: the concepts met, the commands used, and what went
wrong. Written for the maintainer, to revise from before interviews.

## 2026-10-26 — Phase 0: audit

**Concepts**
- Reading a repository before changing it: history, branches, every file.
- A branch that is ahead of `main` with a shared merge base can be
  fast-forwarded; nothing diverged.
- `for_each` keyed by AZ name versus `count` indexed by position: removing
  one `count` item shifts the rest and forces needless recreation.
- A subnet is "public" only because of its route table, not because it
  has an Internet Gateway nearby. No `0.0.0.0/0` route means no internet
  path in either direction.
- The provider lock file is committed; state is not.

**Commands**
- `git log --oneline --graph --all`, `git branch -a`
- `git merge-base main origin/feat/networking`
- `git diff --stat main origin/feat/networking`
- `git show origin/feat/networking:<file>`
- `git log --all -p | grep -E '<secret patterns>'` as a stand-in for
  gitleaks, which was not installed.

**Mistakes and fixes**
- None made. Findings recorded for later phases: missing trailing
  newlines, unvalidated CIDR/AZ variables, always-on NAT, unverified cost
  figures in ADR 0002, docs describing components that do not exist.

## 2026-10-26 — Phase 1: repository hygiene and README

**Concepts**
- Pinning pre-commit hooks to release tags, for the same reason providers
  are pinned: identical checks on every machine.
- Honesty in documentation: a status table separates built from planned,
  and unmeasured values become `TODO(measure)` instead of guesses.
- ADRs are append-only. A decision is changed by a new ADR that
  supersedes the old one, so the reasoning history survives.
- Private vulnerability reporting avoids publishing a personal email in
  `SECURITY.md`.
- Stacked branches: each builds on the previous one and must be merged in
  order.

**Commands**
- `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name` to look up
  real release tags before pinning.
- `git switch -c <type>/<name>` per logical change.

**Mistakes and fixes**
- None found yet, but nothing here has been executed against the real
  tools. `terraform`, `tflint`, `terraform-docs`, `pre-commit` and
  `gitleaks` were not installed, so the hook configuration is only
  checked for valid YAML. Run on 2026-10-28; the fixes are recorded under
  Phase 2.

## 2026-10-26 — Phase 2: modules

**Status of this entry:** the code was written on 2026-10-26 without
Terraform installed, so nothing could be run. It was verified on 2026-10-28
once the tools were installed; the results are under "Verification" below.

**Concepts**
- A module declares the providers it needs (`required_providers`) but never
  configures them; the caller owns region and default tags.
- Optional resources: `count = var.flag ? 1 : 0`. Consumers then use
  `one(resource[*].attr)` to get the value or `null`.
- `count` versus `for_each`: `for_each` keys must be known at plan time, so
  it fails over a list of IDs or ARNs created in the same apply. `count`
  needs only the list length, which is always known. Used `for_each` where
  keys are static (subnets by zone name, rules by description).
- Input validation, including a rule that reads another variable (needs
  Terraform 1.9+): a bad value fails at the variable, not deep in a resource.
- `terraform test` with `mock_provider`: offline, no credentials. `plan`
  runs cannot assert on values that depend on computed attributes (an ARN),
  because they are unknown until apply; those runs use `command = apply`,
  which with a mock provider creates nothing real.
- Hardening, each a distinct mistake closed: IMDSv2 (blocks SSRF stealing
  instance credentials), encrypted EBS and RDS, no public IP, empty default
  security group, S3 public access block plus TLS-only policy.
- RDS `manage_master_user_password`: the password is generated and held in
  Secrets Manager, so it is never in code, variables or `tfvars`.
- Deletion protection and final snapshot default to on; a disposable
  environment turns them off visibly in its own code.
- OIDC for CI: the trust policy is the security boundary. It must check both
  `aud` and `sub` with `StringEquals`. The `sub` claim is
  `repo:O/R:pull_request` for pull request jobs and
  `repo:O/R:environment:NAME` for jobs using an Environment, which is why
  the branch restriction moves to the Environment's settings.
- Terraform's S3 native lock writes a `.tflock` object, so a read-only plan
  role needs write access to that object only, never to the state.
- An explicit `Deny` beats any `Allow`; used so the apply role cannot edit
  the CI roles, the OIDC provider or the state bucket.
- Where a module runs matters: the CI identity has to outlive the
  disposable environment, so `iam` belongs in `bootstrap/`.

**Commands**
- `git mv` in a commit of its own, so renames keep history.
- `terraform init -backend=false` then `terraform test`, run per module.
- `terraform-docs --output-check <module>` fails when the README tables are
  stale, without writing anything.
- `pre-commit run --all-files` runs every hook once across the repository.
- `trivy config --severity HIGH,CRITICAL .` scans the Terraform for
  misconfigurations.

**Mistakes and fixes**
- `ec2` first used `for_each = toset(additional_policy_arns)`. That fails
  when a caller passes the ARN of a policy created in the same apply.
  Switched to `count = length(...)` before writing `rds`, which has the same
  shape.
- A test asserted `aws_instance.key_name == null`. That attribute is
  optional and computed, so it is unknown at plan time and the assertion
  would error. Removed; the module has no key pair argument to test.
- A draft `rds` README claimed something about what Terraform state holds
  that I could not support. Replaced with the one fact that is certain: the
  password is never an input to Terraform.

**Verification (2026-10-28, on `fix/trivy-ssm-egress`, the top of the stack)**
- `terraform fmt`, `validate` (five modules and `envs/dev`), `tflint` with
  the AWS ruleset and gitleaks: clean on the first run.
- `terraform test`: 39 of 39 pass (ec2 10, iam 8, rds 9, s3 6, vpc 6).
- Every `pre-commit` hook passes after the fixes below.
- `trivy config`: one CRITICAL, AWS-0104, on the ec2 egress rule that allows
  HTTPS to `0.0.0.0/0`. That is needed for Session Manager (ADR 0004, 0008),
  so it is suppressed with `#trivy:ignore:AWS-0104` and the reason beside it.
  The guess above about flow log encryption and `ReadOnlyAccess` was wrong:
  trivy flagged neither.
- Five MEDIUM/LOW findings are **accepted, not suppressed**, so they stay
  visible: RDS backup retention (AWS-0077) and deletion protection
  (AWS-0177), which `envs/dev` turns off on purpose for a disposable
  environment (ADR 0002); RDS Performance Insights (AWS-0133), off because it
  bills beyond its free tier; S3 access logging (AWS-0089) and VPC flow logs
  (AWS-0178), which are opt-in. An ignore inside a module would hide the
  check from every future caller, including a production one. The CI gate in
  Phase 4 should fail on HIGH and CRITICAL only.

**Mistakes and fixes found by running the tools**
- The `end-of-file-fixer` hook rewrote 13 files that lacked a trailing
  newline. Phase 0 had listed this as a finding, but no branch had fixed it.
  Committed on its own as whitespace-only.
- The module READMEs were committed with empty `BEGIN_TF_DOCS` blocks.
  Filled by running terraform-docs.
- `terraform init` failed with "because it is a symlink": the `.terraform/`
  directories held symlinks into a plugin cache from an earlier session that
  no longer existed. Deleted the (gitignored) directories and re-initialised
  with `TF_PLUGIN_CACHE_DIR`, so the provider downloads once, not per module.
- The `terraform_docs` hook rewrote the Providers table from `~> 6.0` to
  `6.70.0`. The cause: `terraform_validate` runs first and creates a
  `.terraform.lock.hcl` inside each module, and terraform-docs prints the
  locked version when one exists. The committed `~> 6.0` is the reproducible
  one. Open follow-up for `.terraform-docs.yml` on `chore/repo-hygiene`:
  drop `{{ .Providers }}`, because the Requirements table already shows the
  constraint.

**Still to do**
- Update the status tables in `README.md` and `docs/architecture.md` once
  the module branches are merged. They still say "planned".

**Check yourself**
1. Why does the trivy ignore sit on the module's egress rule, and what is the
   downside of an ignore inside a reusable module compared with one in the
   environment that calls it?
2. `terraform-docs` printed `6.70.0` in one run and `~> 6.0` in another from
   identical code. What was different between the two runs, and why is the
   committed version the reproducible one?
3. Why are the RDS deletion-protection and backup findings left visible
   instead of suppressed, when the CRITICAL egress finding is suppressed?
