# s3 module

A private S3 bucket with the safe settings on by default.

| Protection | Setting |
|------------|---------|
| Public access | All four block-public-access switches on |
| ACLs | Disabled (`BucketOwnerEnforced`) |
| Versioning | On, switchable with `versioning_enabled` |
| Encryption | SSE-S3 (AES256), or SSE-KMS if `kms_key_arn` is set |
| Transport | Bucket policy denies plain HTTP and TLS older than 1.2 |
| Housekeeping | Old versions and unfinished multipart uploads expire |

## Usage

```hcl
module "app_data" {
  source = "../../modules/s3"

  bucket_name = "myproj-dev-app-data-${data.aws_caller_identity.current.account_id}"
}
```

## Design notes

- **Bucket names are global.** Every AWS account shares one namespace, so a
  name like `data` is taken. Including the account ID makes a clash
  unlikely; the caller supplies it, so the module stays account-agnostic.
- **`force_destroy` defaults to false.** Terraform refuses to delete a
  bucket that still holds objects. A throwaway environment can set it to
  true so `terraform destroy` empties the bucket; do not do that for
  anything holding data you would miss.
- **Versioning makes deletion harder.** A versioned bucket also holds every
  old version and delete marker, so emptying it by hand means removing all
  versions, not only the visible objects. `force_destroy = true` handles
  this.
- **SSE-S3 is the default,** not KMS, because it is free and needs no key
  policy. Choose KMS when you need audit of key use or key-level access
  control.

## Tests

```bash
cd modules/s3
terraform init -backend=false
terraform test
```

The tests use a mock provider, so they need no AWS credentials and create
nothing.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11, < 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.0 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.tls_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_abort_incomplete_multipart_upload_days"></a> [abort\_incomplete\_multipart\_upload\_days](#input\_abort\_incomplete\_multipart\_upload\_days) | Days after which an unfinished multipart upload is cleaned up. Abandoned parts are invisible but still billed. | `number` | `7` | no |
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the bucket. S3 names are global across all AWS accounts, so include something unique such as the account ID. | `string` | n/a | yes |
| <a name="input_force_destroy"></a> [force\_destroy](#input\_force\_destroy) | Delete the bucket even if it still contains objects. Leave false for anything holding data you would miss. | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN of a KMS key to encrypt objects with. Null uses S3-managed keys (SSE-S3), which cost nothing. | `string` | `null` | no |
| <a name="input_noncurrent_version_expiration_days"></a> [noncurrent\_version\_expiration\_days](#input\_noncurrent\_version\_expiration\_days) | Days after which old object versions are permanently deleted. Only has an effect while versioning is enabled. | `number` | `30` | no |
| <a name="input_versioning_enabled"></a> [versioning\_enabled](#input\_versioning\_enabled) | Keep previous versions of overwritten or deleted objects, so a bad write can be rolled back. | `bool` | `true` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the bucket, for use in IAM policies. |
| <a name="output_bucket_id"></a> [bucket\_id](#output\_bucket\_id) | Name of the bucket. |
| <a name="output_bucket_regional_domain_name"></a> [bucket\_regional\_domain\_name](#output\_bucket\_regional\_domain\_name) | Region-specific domain name of the bucket. |
<!-- END_TF_DOCS -->
