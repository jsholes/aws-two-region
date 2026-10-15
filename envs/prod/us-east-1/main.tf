############################################################
# prod / us-east-1
#
# Address plan - one /22 per VPC, all derived from
# var.region_supernet (see locals below):
#
#   slot 0   inspection
#   slot 1   ingress landing zone
#   slot 2+  spoke-01 .. spoke-NN
#
# With the default 10.100.0.0/16 that lands as 10.100.0.0/22,
# 10.100.4.0/22, 10.100.8.0/22 and so on. Run
# `terraform output vpc_cidr_plan` to see the resolved plan.
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

  # The whole address plan derives from var.region_supernet. A /16 split into
  # /22s gives 64 VPC slots; slot 0 is inspection, slot 1 is ingress, and the
  # spokes take slots 2 upward. Change the supernet and the entire region
  # moves with it - nothing else in this file carries an address.
  inspection_vpc_cidr = cidrsubnet(var.region_supernet, 6, 0)
  ingress_vpc_cidr    = cidrsubnet(var.region_supernet, 6, 1)

  spoke_vpc_cidrs = {
    for i in range(var.spoke_count) :
    format("spoke-%02d", i + 1) => cidrsubnet(var.region_supernet, 6, 2 + i)
  }
}

module "network" {
  source = "../../../modules/region-stack"

  name_prefix        = var.name_prefix
  availability_zones = var.availability_zones
  amazon_side_asn    = var.amazon_side_asn

  region_supernet     = var.region_supernet
  remote_supernets    = var.remote_supernets
  inspection_vpc_cidr = local.inspection_vpc_cidr
  ingress_vpc_cidr    = local.ingress_vpc_cidr
  spoke_vpc_cidrs     = local.spoke_vpc_cidrs

  # This region inspects cross-region flows.
  propagate_into_peering_route_table = false

  dx_gateway_id       = var.dx_gateway_id
  dx_allowed_prefixes = var.dx_allowed_prefixes

  log_archive_bucket_name = var.log_archive_bucket_name

  vmseries          = var.vmseries
  ingress_listeners = var.ingress_listeners

  tags = local.tags
}
