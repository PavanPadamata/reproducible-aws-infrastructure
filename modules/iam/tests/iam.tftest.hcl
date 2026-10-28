# Offline tests: a mock provider stands in for AWS, so no credentials are
# needed and nothing is created. Run from modules/iam with `terraform test`.
#
# These runs use `command = apply` because the policies embed values that
# are unknown at plan time (the OIDC provider ARN). With a mock provider
# apply fills them with generated values and creates nothing real.
#
# 123456789012 is the placeholder account ID AWS uses in its documentation.

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_iam_openid_connect_provider" {
    defaults = {
      arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    }
  }
}

variables {
  name_prefix       = "test"
  github_repository = "octo/example"
  state_bucket_name = "test-state-bucket"
}

run "trust_policies_name_exact_repository_and_audience" {
  command = apply

  assert {
    condition     = jsondecode(aws_iam_role.ci_plan.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:octo/example:pull_request"
    error_message = "The plan role must trust only pull_request jobs of the named repository."
  }

  assert {
    condition     = jsondecode(aws_iam_role.ci_apply.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:octo/example:environment:dev"
    error_message = "The apply role must trust only jobs running in the named GitHub Environment."
  }

  assert {
    condition = alltrue([
      for r in [aws_iam_role.ci_plan, aws_iam_role.ci_apply] :
      jsondecode(r.assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] == "sts.amazonaws.com"
    ])
    error_message = "Both roles must require the sts.amazonaws.com audience."
  }

  assert {
    condition = alltrue([
      for r in [aws_iam_role.ci_plan, aws_iam_role.ci_apply] :
      jsondecode(r.assume_role_policy).Statement[0].Action == "sts:AssumeRoleWithWebIdentity" && !can(jsondecode(r.assume_role_policy).Statement[0].Condition.StringLike)
    ])
    error_message = "Trust must use AssumeRoleWithWebIdentity and StringEquals only; StringLike would allow wildcards."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "The OIDC provider must be created by default."
  }
}

run "plan_role_can_only_write_lock_files" {
  command = apply

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.ci_plan_state.policy).Statement :
      !contains(try(tolist(s.Action), [s.Action]), "s3:PutObject") || alltrue([for r in s.Resource : endswith(r, ".tflock")])
    ])
    error_message = "The plan role may write only to .tflock objects, never to state."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.ci_plan_read_only.policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "The plan role must carry ReadOnlyAccess."
  }
}

run "apply_role_protects_state_bucket_and_ci_identity" {
  command = apply

  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.ci_apply_infrastructure.policy).Statement :
      s.Sid == "ProtectCiIdentity" && s.Effect == "Deny"
    ])
    error_message = "The apply role must be explicitly denied changes to the CI roles and the OIDC provider."
  }

  assert {
    condition = anytrue([
      for s in jsondecode(aws_iam_role_policy.ci_apply_infrastructure.policy).Statement :
      s.Sid == "ProtectStateBucket" && s.Effect == "Deny"
    ])
    error_message = "The apply role must be explicitly denied changes to the state bucket itself."
  }

  assert {
    condition = alltrue([
      for s in jsondecode(aws_iam_role_policy.ci_apply_infrastructure.policy).Statement :
      !contains(try(tolist(s.Action), [s.Action]), "iam:*")
    ])
    error_message = "The apply role must never be granted iam:*."
  }
}

run "reuses_existing_oidc_provider" {
  command = apply

  variables {
    create_github_oidc_provider = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "No provider may be created when create_github_oidc_provider is false."
  }

  assert {
    condition     = jsondecode(aws_iam_role.ci_plan.assume_role_policy).Statement[0].Principal.Federated == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "The trust policy must point at the existing provider."
  }
}

run "rejects_wildcard_repository" {
  command = plan

  variables {
    github_repository = "octo/*"
  }

  expect_failures = [var.github_repository]
}

run "rejects_repository_without_owner" {
  command = plan

  variables {
    github_repository = "example"
  }

  expect_failures = [var.github_repository]
}

run "rejects_wildcard_state_prefix" {
  command = plan

  variables {
    state_key_prefix = "envs/*/"
  }

  expect_failures = [var.state_key_prefix]
}

run "rejects_short_session" {
  command = plan

  variables {
    max_session_duration = 900
  }

  expect_failures = [var.max_session_duration]
}
