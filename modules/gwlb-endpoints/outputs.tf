output "endpoint_ids" {
  description = "Map of AZ to GWLB endpoint ID. Use as vpc_endpoint_id in aws_route."
  value       = { for az, ep in aws_vpc_endpoint.this : az => ep.id }
}

output "endpoint_network_interface_ids" {
  description = "Map of AZ to the endpoint's ENI IDs."
  value       = { for az, ep in aws_vpc_endpoint.this : az => ep.network_interface_ids }
}
