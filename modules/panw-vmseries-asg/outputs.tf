output "ami_id" {
  description = "VM-Series AMI in use."
  value       = local.ami_id
}

output "bootstrap_bucket_name" {
  description = "S3 bootstrap bucket name."
  value       = local.bucket_name
}

output "autoscaling_group_names" {
  description = "Map of AZ to Auto Scaling group name."
  value       = { for az, asg in aws_autoscaling_group.this : az => asg.name }
}

output "launch_template_ids" {
  description = "Map of AZ to launch template ID."
  value       = { for az, lt in aws_launch_template.this : az => lt.id }
}

output "data_security_group_id" {
  description = "Security group on the data plane interface."
  value       = aws_security_group.data.id
}

output "mgmt_security_group_id" {
  description = "Security group on the management interface."
  value       = aws_security_group.mgmt.id
}

output "iam_role_arn" {
  description = "IAM role assumed by the firewalls."
  value       = aws_iam_role.this.arn
}
