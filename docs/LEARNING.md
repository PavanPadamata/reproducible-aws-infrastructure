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
  checked for valid YAML. Run `pre-commit run --all-files` after
  installing and record any fixes here.
