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
<!-- END_TF_DOCS -->
