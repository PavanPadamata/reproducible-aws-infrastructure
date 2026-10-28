# Offline tests: a mock provider stands in for AWS, so no credentials are
# needed and nothing is created. Run from bootstrap/ with `terraform test`.
#
# A test can see this configuration's outputs but not the resources inside
# the s3 and iam modules; those have their own tests, including the ones that
# reject a wildcard repository or a state prefix without a trailing slash (a
# test cannot expect a failure from a module's variable). These runs cover
# what bootstrap itself decides: how the bucket is named and which existing
# pieces it reuses.
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
  github_repository = "octo/example"
}

run "bucket_name_has_project_and_account_id" {
  command = apply

  assert {
    condition     = output.state_bucket_name == "reproducible-aws-infra-tfstate-123456789012"
    error_message = "The bucket name must be <project>-tfstate-<account id> so it is globally unique."
  }
}

run "project_name_changes_the_bucket_name" {
  command = apply

  variables {
    project_name = "demo"
  }

  assert {
    condition     = output.state_bucket_name == "demo-tfstate-123456789012"
    error_message = "The bucket name must follow project_name."
  }
}

run "existing_oidc_provider_is_reused" {
  command = apply

  variables {
    create_github_oidc_provider = false
  }

  assert {
    condition     = output.github_oidc_provider_arn == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "With create_github_oidc_provider = false, the existing provider must be looked up, not created."
  }
}
