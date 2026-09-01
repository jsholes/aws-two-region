output "vpc_id" {
  description = "Inspection VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Inspection VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "Internet gateway ID."
  value       = aws_internet_gateway.this.id
}

output "data_subnet_ids" {
  description = "Map of AZ to appliance data plane subnet ID. These carry the GWLB."
  value       = { for az, s in aws_subnet.data : az => s.id }
}

output "mgmt_subnet_ids" {
  description = "Map of AZ to appliance management subnet ID."
  value       = { for az, s in aws_subnet.mgmt : az => s.id }
}

output "public_subnet_ids" {
  description = "Map of AZ to public / NAT subnet ID."
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "gwlbe_subnet_ids" {
  description = "Map of AZ to GWLB endpoint subnet ID."
  value       = { for az, s in aws_subnet.gwlbe : az => s.id }
}

output "tgw_subnet_ids" {
  description = "Map of AZ to TGW attachment subnet ID."
  value       = { for az, s in aws_subnet.tgw : az => s.id }
}

output "public_route_table_ids" {
  description = "Map of AZ to public route table ID."
  value       = { for az, rt in aws_route_table.public : az => rt.id }
}

output "gwlbe_route_table_ids" {
  description = "Map of AZ to GWLB endpoint route table ID."
  value       = { for az, rt in aws_route_table.gwlbe : az => rt.id }
}

output "tgw_route_table_ids" {
  description = "Map of AZ to TGW subnet route table ID."
  value       = { for az, rt in aws_route_table.tgw : az => rt.id }
}

output "mgmt_route_table_ids" {
  description = "Map of AZ to appliance management route table ID."
  value       = { for az, rt in aws_route_table.mgmt : az => rt.id }
}

output "nat_gateway_ids" {
  description = "Map of AZ to NAT gateway ID."
  value       = { for az, ngw in aws_nat_gateway.this : az => ngw.id }
}

output "transit_gateway_attachment_id" {
  description = "TGW VPC attachment ID for the inspection VPC."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}
