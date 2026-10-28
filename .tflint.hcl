# TFLint configuration. Run `tflint --init` once to download the plugin.

config {
  # Also lint the contents of local modules called from a root module.
  call_module_type = "local"
}

# Built-in Terraform rules. "recommended" enables the rules most
# projects want, such as deprecated syntax and unused declarations.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# AWS rules catch mistakes `validate` cannot, for example an instance
# type that does not exist or an invalid IAM policy.
plugin "aws" {
  enabled = true
  version = "0.50.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Every variable and output must explain itself.
rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# Every variable must declare a type, so a wrong value fails at the
# variable instead of deep inside a resource.
rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

# Modules follow main.tf / variables.tf / outputs.tf.
rule "terraform_standard_module_structure" {
  enabled = true
}
