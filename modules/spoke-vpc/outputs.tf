output "vpc_id" {
  description = "Spoke VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Spoke VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "workload_subnet_ids" {
  description = "Map of AZ to workload subnet ID."
  value       = { for az, s in aws_subnet.workload : az => s.id }
}

output "tgw_subnet_ids" {
  description = "Map of AZ to TGW attachment subnet ID."
  value       = { for az, s in aws_subnet.tgw : az => s.id }
}

output "workload_route_table_ids" {
  description = "Map of AZ to workload route table ID."
  value       = { for az, rt in aws_route_table.workload : az => rt.id }
}

output "transit_gateway_attachment_id" {
  description = "TGW VPC attachment ID for this spoke."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}
