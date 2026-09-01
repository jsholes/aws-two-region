output "gwlb_arn" {
  description = "ARN of the Gateway Load Balancer."
  value       = aws_lb.this.arn
}

output "gwlb_id" {
  description = "ID of the Gateway Load Balancer."
  value       = aws_lb.this.id
}

output "target_group_arn" {
  description = "ARN of the GENEVE target group. Attach the appliance ASGs to this."
  value       = aws_lb_target_group.this.arn
}

output "endpoint_service_id" {
  description = "VPC endpoint service ID."
  value       = aws_vpc_endpoint_service.this.id
}

output "endpoint_service_name" {
  description = "VPC endpoint service name. Consumers create Gateway Load Balancer endpoints against this."
  value       = aws_vpc_endpoint_service.this.service_name
}
