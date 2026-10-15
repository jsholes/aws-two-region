output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = module.network.transit_gateway_id
}

output "transit_gateway_route_table_ids" {
  description = "Map of routing domain to TGW route table ID."
  value       = module.network.transit_gateway_route_table_ids
}

output "inspection_attachment_id" {
  description = "Inspection VPC TGW attachment ID."
  value       = module.network.inspection_attachment_id
}

output "vpc_cidr_plan" {
  description = "Resolved address plan for this region - the CIDR actually assigned to every VPC."
  value = merge(
    {
      inspection = local.inspection_vpc_cidr
      ingress    = local.ingress_vpc_cidr
    },
    local.spoke_vpc_cidrs,
  )
}

output "region_supernet" {
  description = "Summary prefix for this region."
  value       = var.region_supernet
}

output "spoke_vpc_ids" {
  description = "Map of spoke name to VPC ID."
  value       = module.network.spoke_vpc_ids
}

output "spoke_workload_subnet_ids" {
  description = "Map of spoke name to AZ to workload subnet ID."
  value       = module.network.spoke_workload_subnet_ids
}

output "gwlb_endpoint_service_name" {
  description = "GWLB endpoint service name."
  value       = module.network.gwlb_endpoint_service_name
}

output "nlb_dns_name" {
  description = "Ingress NLB DNS name."
  value       = module.network.nlb_dns_name
}

output "vmseries_bootstrap_bucket" {
  description = "VM-Series bootstrap bucket."
  value       = module.network.vmseries_bootstrap_bucket
}

output "log_archive_bucket_name" {
  description = "Log archive bucket."
  value       = module.network.log_archive_bucket_name
}

output "dx_gateway_attachment_id" {
  description = "TGW attachment ID for the Direct Connect gateway, null when DX is not configured."
  value       = module.network.dx_gateway_attachment_id
}
