############################################################
# prod / us-east-2
#
# Address plan - 10.102.0.0/16, one /22 per VPC:
#
#   10.102.0.0/22    inspection
#   10.102.4.0/22    ingress landing zone
#   10.102.8.0/22    spoke-01
#   10.102.12.0/22   spoke-02
#   10.102.16.0/22   spoke-03
#   10.102.20.0/22   spoke-04
#   10.102.24.0/22   spoke-05
#   10.102.28.0/22   spoke-06
#   10.102.32.0/19   free for growth
#
# Cross-region traffic is inspected in us-east-1, so this region
# propagates its prefixes into its own peering route table and routes
# 10.101.0.0/16 straight at the peering attachment.
############################################################

locals {
  tags = merge({
    Environment = var.environment
    Region      = var.region
    ManagedBy   = "terraform"
    Component   = "network-platform"
  }, var.extra_tags)

  spoke_vpc_cidrs = {
    "spoke-01" = "10.102.8.0/22"
    "spoke-02" = "10.102.12.0/22"
    "spoke-03" = "10.102.16.0/22"
    "spoke-04" = "10.102.20.0/22"
    "spoke-05" = "10.102.24.0/22"
    "spoke-06" = "10.102.28.0/22"
  }
}

module "network" {
  source = "../../../modules/region-stack"

  name_prefix        = var.name_prefix
  availability_zones = var.availability_zones
  amazon_side_asn    = var.amazon_side_asn

  region_supernet     = var.region_supernet
  remote_supernets    = var.remote_supernets
  inspection_vpc_cidr = "10.102.0.0/22"
  ingress_vpc_cidr    = "10.102.4.0/22"
  spoke_vpc_cidrs     = local.spoke_vpc_cidrs

  # us-east-1 inspects cross-region flows; this region delivers
  # traffic arriving over the peering attachment directly.
  propagate_into_peering_route_table = true

  log_archive_bucket_name = var.log_archive_bucket_name

  vmseries          = var.vmseries
  ingress_listeners = var.ingress_listeners

  tags = local.tags
}
