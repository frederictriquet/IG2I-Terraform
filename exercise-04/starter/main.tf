terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate a random suffix for unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Create an S3 bucket
resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"

  tags = merge(
    {
      Name        = "${var.bucket_prefix}-${random_id.bucket_suffix.hex}"
      Environment = var.environment
      ManagedBy   = "Terraform"
    },
    var.tags
  )
}

# Enable versioning on the bucket (conditional)
resource "aws_s3_bucket_versioning" "my_bucket_versioning" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.my_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Configure server-side encryption (conditional)
resource "aws_s3_bucket_server_side_encryption_configuration" "my_bucket_encryption" {
  count  = var.enable_encryption ? 1 : 0
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = var.encryption_algorithm
    }
  }
}
