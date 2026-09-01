output "state_buckets" {
  description = "State bucket name per region. Copy into each root module's backend.tf."
  value = {
    "us-east-1" = aws_s3_bucket.use1.id
    "us-east-2" = aws_s3_bucket.use2.id
  }
}

output "lock_tables" {
  description = "DynamoDB lock table name per region."
  value = {
    "us-east-1" = aws_dynamodb_table.use1.name
    "us-east-2" = aws_dynamodb_table.use2.name
  }
}

output "account_id" {
  description = "Account the backends were created in."
  value       = local.account_id
}
