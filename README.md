# terraform-aws-tfstate-bucket

One S3 bucket for Terraform state, locked with S3 native lockfiles instead of a
DynamoDB table.

Call it once per bucket. If you keep state for several environments in one
account, call it with `for_each` and get one bucket per environment, so a role
that can write dev state has no path to prod state.

## Prerequisites

- Terraform 1.5 or newer and AWS provider 6.x to create the bucket.
- Terraform 1.10 or newer in every stack that stores state in it, because
  `use_lockfile` arrived in 1.10.
- AWS credentials from the standard provider chain. Check the identity with
  `aws sts get-caller-identity` before applying.

## Usage

```hcl
module "state_bucket" {
  source   = "git::https://github.com/tier1dev/terraform-aws-tfstate-bucket.git?ref=v0.1.0"
  for_each = toset(["dev", "prod", "core", "common"])

  bucket_name = "example-tfstate-${each.key}-123456789012"

  tags = {
    Customer    = "example"
    Application = "terraform-state"
    Environment = each.key
    Owner       = "platform@example.com"
    Costcenter  = "platform"
  }
}
```

A runnable version is in [`examples/per-environment`](examples/per-environment).

Then point a stack at one of the buckets:

```hcl
terraform {
  backend "s3" {
    bucket       = "example-tfstate-prod-123456789012"
    key          = "my-app/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
```

The stack that creates the buckets has nowhere to store its own state on the
first run. Apply it with local state, add a backend block pointing at one of
the new buckets, then run `terraform init -migrate-state`.

## What you get

The bucket has versioning on, so a bad apply can be rolled back to the previous
state object. It is encrypted with SSE-S3, all four public access block
settings are on, ACLs are disabled, and the bucket policy denies any request
that isn't made over TLS.

Old versions expire after `noncurrent_version_expiration_days` (90 by default).
The five newest superseded versions of each object are kept however old they
are, so a stack that is applied once a year still has rollback copies.

The module adds no cross-account access. Grant it with IAM in the account that
owns the bucket. A role limited to one state key needs `s3:GetObject` and
`s3:PutObject` on `<key>`, those two plus `s3:DeleteObject` on `<key>.tflock`,
and `s3:ListBucket` on the bucket.

## Cost

A bucket costs nothing until it holds objects, and state files are small.
Expect cents per month for storage and requests. The module uses SSE-S3 rather
than a customer managed KMS key because each key is billed monthly; that is the
`AVD-AWS-0132` finding suppressed in `main.tf`.

## Repository validation

```sh
terraform fmt -check -recursive
terraform init -backend=false && terraform validate
terraform test
tflint --init && tflint --recursive
trivy config --exit-code 1 .
```

The tests use a mocked AWS provider, so they need no credentials and create
nothing.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.67.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_s3_bucket.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_lifecycle_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration) | resource |
| [aws_s3_bucket_ownership_controls.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_ownership_controls) | resource |
| [aws_s3_bucket_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_bucket_name"></a> [bucket\_name](#input\_bucket\_name) | Name of the state bucket. It is written into every backend block that uses it, so choose it once. Dots are rejected because they break TLS on virtual-hosted S3 endpoints. | `string` | n/a | yes |
| <a name="input_noncurrent_version_expiration_days"></a> [noncurrent\_version\_expiration\_days](#input\_noncurrent\_version\_expiration\_days) | Days a superseded state version is kept before it expires. The five newest superseded versions of each object are kept regardless of age. | `number` | `90` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the bucket. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bucket_arn"></a> [bucket\_arn](#output\_bucket\_arn) | ARN of the state bucket, for scoping IAM policies to a state key prefix. |
| <a name="output_bucket_name"></a> [bucket\_name](#output\_bucket\_name) | Name of the state bucket, for the `bucket` argument of an S3 backend block. |
| <a name="output_bucket_region"></a> [bucket\_region](#output\_bucket\_region) | Region of the state bucket, for the `region` argument of an S3 backend block. |
<!-- END_TF_DOCS -->

## License

AGPL-3.0. See [LICENSE](LICENSE).
