# Security Policy

## Scope

This is a personal learning project that defines AWS infrastructure in
Terraform. It is not a product and has no supported release line: only
the latest commit on `main` is maintained.

## Reporting a vulnerability

Please do not open a public issue for security problems.

Use GitHub's private reporting instead: go to the **Security** tab of
this repository and choose **Report a vulnerability**. You will get a
reply as soon as the maintainer can look at it.

Examples worth reporting:

- A credential, key, account ID or state file that was committed
- An IAM policy or trust policy that is broader than it needs to be
- A security group, bucket policy or database setting that exposes a
  resource to the internet unintentionally

## If you find an exposed credential

Report it privately as above. Do not try to use it. Deleting a secret
from the latest commit does not remove it from Git history, so the
maintainer will rotate the credential first and clean history second.

## How this repository protects itself

- `.gitignore` excludes Terraform state, plan files, `*.tfvars` and key
  material.
- A `gitleaks` pre-commit hook scans every commit for secrets.
- CI authenticates to AWS with short-lived OIDC credentials rather than
  stored access keys (planned, see the roadmap in the README).
