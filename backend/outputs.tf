output "state_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state files."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_arn" {
  description = "ARN of the S3 state bucket — used for IAM policy definitions."
  value       = aws_s3_bucket.terraform_state.arn
}

output "dynamodb_lock_table_name" {
  description = "Name of the DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.terraform_state_lock.name
}

output "dynamodb_lock_table_arn" {
  description = "ARN of the DynamoDB lock table — used for IAM policy definitions."
  value       = aws_dynamodb_table.terraform_state_lock.arn
}