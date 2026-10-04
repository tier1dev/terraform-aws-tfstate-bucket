mock_provider "aws" {
  mock_resource "aws_s3_bucket" {
    defaults = {
      id  = "example-tfstate-dev"
      arn = "arn:aws:s3:::example-tfstate-dev"
    }
  }
}

variables {
  bucket_name = "example-tfstate-dev"
}

run "keeps_every_state_version_recoverable" {
  command = apply

  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled so a bad apply can be rolled back."
  }
}

run "blocks_all_public_access" {
  command = apply

  assert {
    condition = alltrue([
      aws_s3_bucket_public_access_block.this.block_public_acls,
      aws_s3_bucket_public_access_block.this.block_public_policy,
      aws_s3_bucket_public_access_block.this.ignore_public_acls,
      aws_s3_bucket_public_access_block.this.restrict_public_buckets,
    ])
    error_message = "All four public access block settings must be on."
  }

  assert {
    condition     = aws_s3_bucket_ownership_controls.this.rule[0].object_ownership == "BucketOwnerEnforced"
    error_message = "ACLs must be disabled."
  }
}

run "encrypts_at_rest_without_a_billable_key" {
  command = apply

  assert {
    condition = one([
      for rule in aws_s3_bucket_server_side_encryption_configuration.this.rule :
      rule.apply_server_side_encryption_by_default[0].sse_algorithm
    ]) == "AES256"
    error_message = "State must be encrypted with SSE-S3."
  }
}

run "refuses_plain_http" {
  command = apply

  assert {
    condition = anytrue([
      for statement in jsondecode(aws_s3_bucket_policy.this.policy).Statement :
      statement.Effect == "Deny" &&
      statement.Action == "s3:*" &&
      statement.Condition.Bool["aws:SecureTransport"] == "false" &&
      contains(statement.Resource, "arn:aws:s3:::example-tfstate-dev") &&
      contains(statement.Resource, "arn:aws:s3:::example-tfstate-dev/*")
    ])
    error_message = "The bucket policy must deny every non-TLS request to the bucket and its objects."
  }
}

run "expires_old_versions_but_keeps_recent_ones" {
  command = apply

  variables {
    noncurrent_version_expiration_days = 30
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].noncurrent_version_expiration[0].noncurrent_days == 30
    error_message = "Noncurrent versions must expire after the configured number of days."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.this.rule[0].noncurrent_version_expiration[0].newer_noncurrent_versions == 5
    error_message = "The five newest noncurrent versions must survive expiry."
  }
}

run "rejects_bucket_name_with_dots" {
  command = plan

  variables {
    bucket_name = "tfstate.example.com"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_bucket_name_with_uppercase" {
  command = plan

  variables {
    bucket_name = "Example-TFState"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_bucket_name_longer_than_63_characters" {
  command = plan

  variables {
    bucket_name = "a-bucket-name-that-keeps-going-well-past-the-sixty-three-character-limit"
  }

  expect_failures = [var.bucket_name]
}

run "rejects_zero_day_version_expiry" {
  command = plan

  variables {
    noncurrent_version_expiration_days = 0
  }

  expect_failures = [var.noncurrent_version_expiration_days]
}
