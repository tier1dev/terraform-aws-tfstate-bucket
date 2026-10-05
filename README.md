# terraform-aws-tfstate-bucket

One S3 bucket for Terraform state, locked with S3 native lockfiles instead of a
DynamoDB table.

Call it once per bucket. If you keep state for several environments and
regions in one account, call it with `for_each` and get one bucket for each
pair, so a role that can write dev state has no path to prod state and a
regional S3 outage only blocks applies for stacks in that region.

## Prerequisites

- Terraform 1.5 or newer and AWS provider 6.x to create the bucket.
- Terraform 1.10 or newer in every stack that stores state in it, because
  `use_lockfile` arrived in 1.10.
- AWS credentials from the standard provider chain. Check the identity with
  `aws sts get-caller-identity` before applying.

## Usage

Four environments in two regions is eight buckets from one module block and
one provider configuration:

```hcl
locals {
  environments = ["dev", "prod", "core", "common"]
  regions      = ["us-east-1", "us-west-2"]

  buckets = {
    for pair in setproduct(local.environments, local.regions) :
    "${pair[0]}/${pair[1]}" => { environment = pair[0], region = pair[1] }
  }
}

module "state_bucket" {
  source   = "git::https://github.com/tier1dev/terraform-aws-tfstate-bucket.git?ref=v0.2.0"
  for_each = local.buckets

  bucket_name = "example-tfstate-${each.value.environment}-123456789012-${each.value.region}"
  region      = each.value.region

  tags = {
    Customer    = "example"
    Application = "terraform-state"
    Environment = each.value.environment
    Owner       = "platform@example.com"
    Costcenter  = "platform"
  }
}
```

A runnable version is in
[`examples/per-environment-and-region`](examples/per-environment-and-region).
Leave `region` unset to create a single bucket in the provider's region.

The stack that creates the buckets has nowhere to store its own state on the
first run. Apply it with local state, add a backend block pointing at one of
the new buckets, then run `terraform init -migrate-state`.

## State key layout

The module doesn't enforce a key layout, but one bucket serves many stacks, so
pick a layout before the first stack lands. This one works when the buckets
hold state for more than one company:

```text
<company>/<app>/<environment or workspace>/<name>.tfstate
```

A stack that doesn't use workspaces writes the whole path as its key:

```hcl
terraform {
  backend "s3" {
    bucket       = "example-tfstate-prod-123456789012-us-east-1"
    key          = "acme/billing-api/prod/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
```

A stack that uses workspaces, where the workspace name is the environment,
gets the same path by moving the company and app into `workspace_key_prefix`:

```hcl
terraform {
  backend "s3" {
    bucket               = "example-tfstate-prod-123456789012-us-east-1"
    workspace_key_prefix = "acme/billing-api"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
    use_lockfile         = true
  }
}
```

Terraform stores a named workspace at `<workspace_key_prefix>/<workspace>/<key>`,
so the `prod` workspace lands on `acme/billing-api/prod/terraform.tfstate`. The
`default` workspace ignores the prefix and writes `terraform.tfstate` at the
bucket root, where every other stack doing the same would collide with it.
Always select a named workspace with this form.

An app with several stacks gives each its own file name in the same directory,
for example `acme/billing-api/prod/data.tfstate` and
`acme/billing-api/prod/backend.tfstate`.

## What you get

The bucket has versioning on, so a bad apply can be rolled back to the previous
state object. It is encrypted with SSE-S3, all four public access block
settings are on, ACLs are disabled, and the bucket policy denies any request
that isn't made over TLS.

Old versions expire after `noncurrent_version_expiration_days` (90 by default).
The five newest superseded versions of each object are kept however old they
are, so a stack that is applied once a year still has rollback copies.

The module adds no cross-account access. Grant it with IAM in the account that
owns the bucket. With the key layout above, a role for one app is scoped to
`<company>/<app>/*`: `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on
that prefix (the delete is for the `.tflock` files), and `s3:ListBucket` on the
bucket with an `s3:prefix` condition for the same prefix.

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
| <a name="input_region"></a> [region](#input\_region) | Region the bucket is created in. Null uses the provider's region. Set it to create buckets in several regions from one provider configuration. | `string` | `null` | no |
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
