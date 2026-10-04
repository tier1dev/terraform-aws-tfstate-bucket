terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# One bucket per environment, all in the same account. The account ID in the
# name keeps it globally unique without a random suffix.
module "state_bucket" {
  source   = "../.."
  for_each = toset(["dev", "prod", "core", "common"])

  bucket_name = "example-tfstate-${each.key}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Customer    = "example"
    Application = "terraform-state"
    Environment = each.key
    Owner       = "platform@example.com"
    Costcenter  = "platform"
  }
}

output "state_buckets" {
  description = "Bucket name per environment."
  value       = { for env, bucket in module.state_bucket : env => bucket.bucket_name }
}
