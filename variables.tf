variable "bucket_name" {
  description = "Name of the state bucket. It is written into every backend block that uses it, so choose it once. Dots are rejected because they break TLS on virtual-hosted S3 endpoints."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "The bucket_name value must be 3-63 characters of lowercase letters, digits and hyphens, starting and ending with a letter or digit."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days a superseded state version is kept before it expires. The five newest superseded versions of each object are kept regardless of age."
  type        = number
  default     = 90

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "The noncurrent_version_expiration_days value must be at least 1."
  }
}

variable "tags" {
  description = "Tags applied to the bucket."
  type        = map(string)
  default     = {}
}

variable "region" {
  description = "Region the bucket is created in. Null uses the provider's region. Set it to create buckets in several regions from one provider configuration."
  type        = string
  default     = null
}
