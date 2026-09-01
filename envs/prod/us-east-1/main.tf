############################################################
# prod / us-east-1
#
# Address plan - 10.101.0.0/16, one /22 per VPC:
#
#   10.101.0.0/22    inspection
#   10.101.4.0/22    ingress landing zone
#   10.101.8.0/22    spoke-01
#   10.101.12.0/22   spoke-02
#   10.101.16.0/22   spoke-03
#   10.101.20.0/22   spoke-04
#   10.101.24.0/22   spoke-05
#   10.101.28.0/22   spoke-06
#   10.101.32.0/19   free for growth
#
# This region inspects cross-region traffic, so it does not propagate
# its prefixes into its own TGW peering route table - see the peering
# root module for why.
############################################################

locals {
  tags = merge({
    Environment = var.environment
    Region      = var.region
    ManagedBy   = "terraform"
    Component   = "network-platform"
  }, var.extra_tags)

  spoke_vpc_cidrs = {
    "spoke-01" = "10.101.8.0/22"
    "spoke-02" = "10.101.12.0/22"
    "spoke-03" = "10.101.16.0/22"
    "spoke-04" = "10.101.20.0/22"
    "spoke-05" = "10.101.24.0/22"
    "spoke-06" = "10.101.28.0/22"
  }
}

module "network" {
  source = "../../../modules/region-stack"

  name_prefix        = var.name_prefix
  availability_zones = var.availability_zones
  amazon_side_asn    = var.amazon_side_asn

  region_supernet     = var.region_supernet
  remote_supernets    = var.remote_supernets
  inspection_vpc_cidr = "10.101.0.0/22"
  ingress_vpc_cidr    = "10.101.4.0/22"
  spoke_vpc_cidrs     = local.spoke_vpc_cidrs

  # This region inspects cross-region flows.
  propagate_into_peering_route_table = false

  log_archive_bucket_name = var.log_archive_bucket_name

  vmseries          = var.vmseries
  ingress_listeners = var.ingress_listeners

  tags = local.tags
}
