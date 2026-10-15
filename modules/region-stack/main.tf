############################################################
# One complete region of the network platform:
#
#   Transit Gateway with four routing domains
#   Inspection VPC  - GWLB + Palo Alto VM-Series + NAT egress
#   Ingress VPC     - internet-facing NLB behind GWLB endpoints
#   Six spoke VPCs  - workloads, default route to the TGW
#   Log archive     - VPC flow logs and NLB access logs
############################################################

locals {
  internal_supernets = concat([var.region_supernet], var.remote_supernets)

  # Spoke prefixes are propagated into the inspection and ingress route
  # tables so post-inspection traffic and NLB return traffic can find
  # them, and optionally into the peering table (see the variable).
  spoke_propagation_route_table_ids = compact([
    module.tgw.inspection_route_table_id,
    module.tgw.ingress_route_table_id,
    var.propagate_into_peering_route_table ? module.tgw.peering_route_table_id : "",
  ])

  ingress_propagation_route_table_ids = compact([
    module.tgw.spoke_route_table_id,
    module.tgw.inspection_route_table_id,
    var.propagate_into_peering_route_table ? module.tgw.peering_route_table_id : "",
  ])
}

module "log_archive" {
  source = "../log-archive"

  bucket_name    = var.log_archive_bucket_name
  retention_days = var.log_retention_days
  tags           = var.tags
}

module "tgw" {
  source = "../tgw"

  name_prefix     = var.name_prefix
  amazon_side_asn = var.amazon_side_asn
  tags            = var.tags
}

############################################################
# Inspection VPC and the firewall fleet
############################################################

module "inspection_vpc" {
  source = "../inspection-vpc"

  name               = "${var.name_prefix}-inspection"
  cidr_block         = var.inspection_vpc_cidr
  availability_zones = var.availability_zones

  transit_gateway_id                          = module.tgw.transit_gateway_id
  transit_gateway_association_route_table_id  = module.tgw.inspection_route_table_id
  transit_gateway_propagation_route_table_ids = []

  enable_nat_gateway  = true
  flow_log_bucket_arn = module.log_archive.bucket_arn

  tags = var.tags
}

module "gwlb" {
  source = "../gwlb"

  name       = "${var.name_prefix}-gwlb"
  vpc_id     = module.inspection_vpc.vpc_id
  subnet_ids = [for az in var.availability_zones : module.inspection_vpc.data_subnet_ids[az]]

  health_check_protocol = var.gwlb_health_check_protocol
  health_check_port     = var.gwlb_health_check_port
  health_check_path     = var.gwlb_health_check_path

  tags = var.tags
}

module "vmseries" {
  source = "../panw-vmseries-asg"

  name             = "${var.name_prefix}-vmseries"
  vpc_id           = module.inspection_vpc.vpc_id
  vpc_cidr_block   = module.inspection_vpc.vpc_cidr_block
  data_subnet_ids  = module.inspection_vpc.data_subnet_ids
  mgmt_subnet_ids  = module.inspection_vpc.mgmt_subnet_ids
  target_group_arn = module.gwlb.target_group_arn

  ami_id        = var.vmseries.ami_id
  panos_version = var.vmseries.panos_version
  license_type  = var.vmseries.license_type
  instance_type = var.vmseries.instance_type
  key_name      = var.vmseries.key_name

  min_size                       = var.vmseries.min_size
  max_size                       = var.vmseries.max_size
  desired_capacity               = var.vmseries.desired_capacity
  enable_target_tracking_scaling = var.vmseries.enable_target_tracking_scaling

  mgmt_allowed_cidrs        = var.vmseries.mgmt_allowed_cidrs
  health_check_ingress_port = tonumber(var.gwlb_health_check_port)

  bootstrap_xml_path      = var.vmseries.bootstrap_xml_path
  panorama_server         = var.vmseries.panorama_server
  panorama_server_2       = var.vmseries.panorama_server_2
  panorama_template_stack = var.vmseries.panorama_template_stack
  panorama_device_group   = var.vmseries.panorama_device_group
  vm_auth_key             = var.vmseries.vm_auth_key
  vm_series_auth_codes    = var.vmseries.vm_series_auth_codes

  tags = var.tags
}

# East-west endpoints, inside the inspection VPC itself.
module "gwlbe_inspection" {
  source = "../gwlb-endpoints"

  name         = "${var.name_prefix}-inspection"
  vpc_id       = module.inspection_vpc.vpc_id
  service_name = module.gwlb.endpoint_service_name
  subnet_ids   = module.inspection_vpc.gwlbe_subnet_ids

  tags = var.tags
}

############################################################
# Ingress landing zone
############################################################

module "ingress_vpc" {
  source = "../ingress-vpc"

  name               = "${var.name_prefix}-ingress"
  cidr_block         = var.ingress_vpc_cidr
  availability_zones = var.availability_zones

  transit_gateway_id                          = module.tgw.transit_gateway_id
  transit_gateway_association_route_table_id  = module.tgw.ingress_route_table_id
  transit_gateway_propagation_route_table_ids = local.ingress_propagation_route_table_ids

  internal_supernets = local.internal_supernets
  listeners          = var.ingress_listeners

  access_logs_bucket  = var.enable_nlb_access_logs ? module.log_archive.bucket_name : ""
  access_logs_prefix  = module.log_archive.lb_access_log_prefix
  flow_log_bucket_arn = module.log_archive.bucket_arn

  tags = var.tags
}

# North-south endpoints, inside the ingress VPC, consuming the same
# endpoint service as the east-west path.
module "gwlbe_ingress" {
  source = "../gwlb-endpoints"

  name         = "${var.name_prefix}-ingress"
  vpc_id       = module.ingress_vpc.vpc_id
  service_name = module.gwlb.endpoint_service_name
  subnet_ids   = module.ingress_vpc.gwlbe_subnet_ids

  tags = var.tags
}

############################################################
# Spokes
############################################################

module "spoke" {
  source   = "../spoke-vpc"
  for_each = var.spoke_vpc_cidrs

  name               = "${var.name_prefix}-${each.key}"
  cidr_block         = each.value
  availability_zones = var.availability_zones

  transit_gateway_id                          = module.tgw.transit_gateway_id
  transit_gateway_association_route_table_id  = module.tgw.spoke_route_table_id
  transit_gateway_propagation_route_table_ids = local.spoke_propagation_route_table_ids

  default_route_to_tgw       = true
  enable_s3_gateway_endpoint = var.enable_spoke_s3_gateway_endpoints
  flow_log_bucket_arn        = module.log_archive.bucket_arn

  tags = var.tags
}

############################################################
# Hybrid connectivity
#
# Optional. The DX gateway itself is a global resource created outside
# this module - both regions associate with the same one.
############################################################

module "dxgw" {
  source = "../dxgw-attachment"
  count  = var.dx_gateway_id != "" ? 1 : 0

  dx_gateway_id      = var.dx_gateway_id
  transit_gateway_id = module.tgw.transit_gateway_id
  create_association = var.dx_create_association

  allowed_prefixes = length(var.dx_allowed_prefixes) > 0 ? var.dx_allowed_prefixes : [var.region_supernet]

  hybrid_route_table_id     = module.tgw.hybrid_route_table_id
  inspection_route_table_id = module.tgw.inspection_route_table_id
  inspection_attachment_id  = module.inspection_vpc.transit_gateway_attachment_id

  inspect_inbound = var.dx_inspect_inbound

  # Only this region's supernet. The other region has its own association
  # to the same DX gateway, so on-premises reaches it directly rather than
  # hairpinning through here.
  inspected_prefixes = [var.region_supernet]
}
