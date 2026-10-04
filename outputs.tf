output "bucket_name" {
  description = "Name of the state bucket, for the `bucket` argument of an S3 backend block."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the state bucket, for scoping IAM policies to a state key prefix."
  value       = aws_s3_bucket.this.arn
}

output "bucket_region" {
  description = "Region of the state bucket, for the `region` argument of an S3 backend block."
  value       = aws_s3_bucket.this.region
}
