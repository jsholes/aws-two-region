output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "Transit Gateway ARN."
  value       = aws_ec2_transit_gateway.this.arn
}

output "amazon_side_asn" {
  description = "ASN of the Amazon side of the Transit Gateway."
  value       = aws_ec2_transit_gateway.this.amazon_side_asn
}

output "route_table_ids" {
  description = "Map of routing domain name to Transit Gateway route table ID."
  value       = { for k, rt in aws_ec2_transit_gateway_route_table.this : k => rt.id }
}

output "spoke_route_table_id" {
  description = "Route table associated with workload VPC attachments."
  value       = aws_ec2_transit_gateway_route_table.this["spoke"].id
}

output "inspection_route_table_id" {
  description = "Route table associated with the inspection VPC attachment."
  value       = aws_ec2_transit_gateway_route_table.this["inspection"].id
}

output "ingress_route_table_id" {
  description = "Route table associated with the ingress VPC attachment."
  value       = aws_ec2_transit_gateway_route_table.this["ingress"].id
}

output "peering_route_table_id" {
  description = "Route table associated with the cross-region peering attachment."
  value       = aws_ec2_transit_gateway_route_table.this["peering"].id
}

output "hybrid_route_table_id" {
  description = "Route table associated with Direct Connect gateway and VPN attachments."
  value       = aws_ec2_transit_gateway_route_table.this["hybrid"].id
}
