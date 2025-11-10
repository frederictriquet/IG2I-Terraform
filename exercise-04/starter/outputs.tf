output "bucket_name" {
  value       = aws_s3_bucket.my_bucket.id
  description = "The name of the S3 bucket"
}

output "bucket_arn" {
  value       = aws_s3_bucket.my_bucket.arn
  description = "The ARN of the S3 bucket"
}

output "bucket_region" {
  value       = aws_s3_bucket.my_bucket.region
  description = "The AWS region where the bucket is located"
}

output "versioning_enabled" {
  value       = var.enable_versioning
  description = "Whether versioning is enabled on the bucket"
}

output "encryption_enabled" {
  value       = var.enable_encryption
  description = "Whether encryption is enabled on the bucket"
}
