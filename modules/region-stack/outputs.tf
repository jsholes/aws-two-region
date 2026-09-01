output "transit_gateway_id" {
  description = "Transit Gateway ID for this region."
  value       = module.tgw.transit_gateway_id
}

output "transit_gateway_route_table_ids" {
  description = "Map of routing domain to TGW route table ID."
  value       = module.tgw.route_table_ids
}

output "inspection_attachment_id" {
  description = "Inspection VPC TGW attachment ID. Needed by the cross-region peering module."
  value       = module.inspection_vpc.transit_gateway_attachment_id
}

output "inspection_vpc_id" {
  description = "Inspection VPC ID."
  value       = module.inspection_vpc.vpc_id
}

output "ingress_vpc_id" {
  description = "Ingress VPC ID."
  value       = module.ingress_vpc.vpc_id
}

output "spoke_vpc_ids" {
  description = "Map of spoke name to VPC ID."
  value       = { for k, m in module.spoke : k => m.vpc_id }
}

output "spoke_workload_subnet_ids" {
  description = "Map of spoke name to a map of AZ to workload subnet ID."
  value       = { for k, m in module.spoke : k => m.workload_subnet_ids }
}

output "gwlb_endpoint_service_name" {
  description = "GWLB endpoint service name. Consume this from any additional VPC that needs inspection."
  value       = module.gwlb.endpoint_service_name
}

output "gwlb_target_group_arn" {
  description = "GENEVE target group ARN."
  value       = module.gwlb.target_group_arn
}

output "nlb_dns_name" {
  description = "Ingress NLB DNS name."
  value       = module.ingress_vpc.nlb_dns_name
}

output "nlb_zone_id" {
  description = "Ingress NLB hosted zone ID."
  value       = module.ingress_vpc.nlb_zone_id
}

output "ingress_target_group_arns" {
  description = "Map of ingress listener name to target group ARN."
  value       = module.ingress_vpc.target_group_arns
}

output "vmseries_bootstrap_bucket" {
  description = "S3 bucket holding the VM-Series bootstrap package."
  value       = module.vmseries.bootstrap_bucket_name
}

output "vmseries_ami_id" {
  description = "VM-Series AMI selected for this region."
  value       = module.vmseries.ami_id
}

output "log_archive_bucket_name" {
  description = "Centralized log bucket for this region."
  value       = module.log_archive.bucket_name
}
