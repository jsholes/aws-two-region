output "bucket_name" {
  description = "Log archive bucket name."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "Log archive bucket ARN. Pass to the VPC modules as flow_log_bucket_arn."
  value       = aws_s3_bucket.this.arn
}

output "flow_log_prefix" {
  description = "Prefix used by VPC flow logs."
  value       = var.flow_log_prefix
}

output "lb_access_log_prefix" {
  description = "Prefix used by load balancer access logs."
  value       = var.lb_access_log_prefix
}
