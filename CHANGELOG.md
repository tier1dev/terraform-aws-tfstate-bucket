# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-10-04

### Added

- Initial module: one S3 bucket for Terraform state, meant for S3 native
  lockfile locking (`use_lockfile = true`) with no DynamoDB table.
- Versioning, SSE-S3 encryption, a full public access block, disabled ACLs and
  a bucket policy that denies non-TLS requests.
- Lifecycle rule that expires superseded state versions after a configurable
  number of days while always keeping the five newest.
- Example that creates one bucket per environment with `for_each`.
