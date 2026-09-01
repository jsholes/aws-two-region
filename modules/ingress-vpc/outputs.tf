output "vpc_id" {
  description = "Ingress VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "Ingress VPC CIDR."
  value       = aws_vpc.this.cidr_block
}

output "internet_gateway_id" {
  description = "Internet gateway ID."
  value       = aws_internet_gateway.this.id
}

output "public_subnet_ids" {
  description = "Map of AZ to public (NLB) subnet ID."
  value       = { for az, s in aws_subnet.public : az => s.id }
}

output "public_subnet_cidrs" {
  description = "Map of AZ to public (NLB) subnet CIDR. Used as the destination in the IGW ingress route table."
  value       = { for az, s in aws_subnet.public : az => s.cidr_block }
}

output "private_subnet_ids" {
  description = "Map of AZ to private subnet ID."
  value       = { for az, s in aws_subnet.private : az => s.id }
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

output "igw_ingress_route_table_id" {
  description = "Route table associated with the internet gateway for ingress redirection."
  value       = aws_route_table.igw_ingress.id
}

output "nlb_arn" {
  description = "ARN of the ingress NLB."
  value       = aws_lb.this.arn
}

output "nlb_dns_name" {
  description = "DNS name of the ingress NLB."
  value       = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  description = "Hosted zone ID of the ingress NLB, for Route 53 alias records."
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "Map of listener name to target group ARN."
  value       = { for k, tg in aws_lb_target_group.this : k => tg.arn }
}

output "transit_gateway_attachment_id" {
  description = "TGW VPC attachment ID for the ingress VPC."
  value       = aws_ec2_transit_gateway_vpc_attachment.this.id
}
