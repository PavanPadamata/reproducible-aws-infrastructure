# ADR 0010: State bucket from the s3 module, and a partial backend

## Status
Accepted. Amends ADR 0005: the bucket is protected with `force_destroy =
false`, not `prevent_destroy`. Everything else in ADR 0005 stands.

## Context
ADR 0005 says the state bucket gets `lifecycle { prevent_destroy = true }`.
That setting cannot be passed into a module, because `lifecycle` arguments
must be literal values. The repository already has a hardened, tested `s3`
module (public access block, encryption, TLS-only policy, versioning). Two
questions follow:

1. How is the bucket created without losing either the module or the
   protection?
2. How does `envs/dev` find the bucket, given that a backend block cannot
   use variables and the bucket name contains the AWS account ID?

## Decision

**The bucket is created by calling `modules/s3` from `bootstrap/`, with
`force_destroy = false`.** AWS refuses to delete a bucket that holds any
object, object version or delete marker, so `terraform destroy` in
`bootstrap/` fails while state exists. That is the protection
`prevent_destroy` was meant to give: no stray destroy can remove state.

**`envs/dev` uses a partial backend configuration.** `backend.tf` holds the
fixed settings (`key`, `region`, `encrypt`, `use_lockfile`). The bucket name
is passed at `terraform init -backend-config=backend.hcl`. `backend.hcl` is
git-ignored; `backend.hcl.example` is committed.

**State keys start with `envs/`.** `envs/dev` uses
`envs/dev/terraform.tfstate`. The `iam` module restricts the CI roles to
that prefix, so a new environment must use a key under it.

**`bootstrap/` passes the project name as `name_prefix` to `iam`.** The CI
roles then manage everything named `<project>-*`, which covers every
environment. The state bucket and the CI roles share that prefix and are
covered by the module's explicit `Deny` statements.

## Alternatives rejected
- **Write the bucket inline in `bootstrap/` with `prevent_destroy`.** Follows
  ADR 0005 to the letter, but copies about forty lines of security settings
  that the `s3` module already holds and tests. Two copies drift apart.
- **Add a "protected" variant to the `s3` module.** A `count` switch between
  two bucket resources, one with `prevent_destroy`, would work, but it makes
  a tested, simple module harder to read for one caller.
- **Hardcode the bucket name in `backend.tf`.** Simple, but puts the account
  ID in the repository.

## Consequences
- **The protection is weaker in one case.** `prevent_destroy` fails at plan
  time. `force_destroy = false` fails at apply time, and only while the
  bucket is not empty. An emptied bucket can be destroyed, but then there is
  no state left to lose. Teardown stays a deliberate manual step: empty every
  object version and delete marker, then destroy `bootstrap/`.
- The apply role is also denied `s3:DeleteBucket` on the state bucket
  (ADR 0009), so CI cannot remove it either.
- The state bucket has no access logging (trivy AWS-0089, LOW), as with every
  bucket from the `s3` module. Logging needs a second bucket to write to.
  Accepted for now.
- Old state versions are deleted after 30 days, the `s3` module default.
  That is the window for rolling back a bad state write.
- `bootstrap/` keeps its own state in a local file, as ADR 0005 says. That
  file is git-ignored and must be kept by the person who ran the apply.
- `envs/dev` has never been applied, so there is no existing state to move.
  The first `terraform init` against the new backend is a plain init, not a
  migration.
