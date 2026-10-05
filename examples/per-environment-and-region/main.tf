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

locals {
  environments = ["dev", "prod", "core", "common"]
  regions      = ["us-east-1", "us-west-2"]

  buckets = {
    for pair in setproduct(local.environments, local.regions) :
    "${pair[0]}/${pair[1]}" => { environment = pair[0], region = pair[1] }
  }
}

# One bucket per environment per region, all in the same account and from one
# provider configuration. The account ID and region in the name keep it
# globally unique without a random suffix.
module "state_bucket" {
  source   = "../.."
  for_each = local.buckets

  bucket_name = "example-tfstate-${each.value.environment}-${data.aws_caller_identity.current.account_id}-${each.value.region}"
  region      = each.value.region

  tags = {
    Customer    = "example"
    Application = "terraform-state"
    Environment = each.value.environment
    Owner       = "platform@example.com"
    Costcenter  = "platform"
  }
}

output "state_buckets" {
  description = "Bucket name per environment and region."
  value       = { for key, bucket in module.state_bucket : key => bucket.bucket_name }
}
