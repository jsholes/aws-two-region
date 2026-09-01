############################################################
# Routes whose next hop is a Gateway Load Balancer endpoint.
#
# These live here rather than inside the VPC modules because the
# endpoints depend on the endpoint service, which depends on the GWLB,
# which lives inside the inspection VPC. Declaring them in the VPC
# modules would close a dependency cycle.
############################################################

locals {
  # (az, supernet) pairs, used where a route is needed per AZ per
  # internal prefix.
  az_supernet_pairs = {
    for pair in setproduct(var.availability_zones, local.internal_supernets) :
    "${pair[0]}-${pair[1]}" => { az = pair[0], cidr = pair[1] }
  }
}

############################################################
# Inspection VPC - east-west and egress
############################################################

# Everything arriving from the Transit Gateway is handed to the
# AZ-local firewall endpoint. This is the east-west enforcement point.
resource "aws_route" "inspection_tgw_to_gwlbe" {
  for_each = toset(var.availability_zones)

  route_table_id         = module.inspection_vpc.tgw_route_table_ids[each.value]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.gwlbe_inspection.endpoint_ids[each.value]
}

# After inspection, internal destinations go back to the Transit
# Gateway. Internet-bound traffic falls through to the NAT gateway
# default route created inside the inspection VPC module.
resource "aws_route" "inspection_gwlbe_to_tgw" {
  for_each = local.az_supernet_pairs

  route_table_id         = module.inspection_vpc.gwlbe_route_table_ids[each.value.az]
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = module.tgw.transit_gateway_id

  depends_on = [module.inspection_vpc]
}

# Return traffic from the NAT gateways toward internal prefixes is sent
# back through the firewall so egress flows are inspected in both
# directions by the same appliance.
resource "aws_route" "inspection_public_to_gwlbe" {
  for_each = local.az_supernet_pairs

  route_table_id         = module.inspection_vpc.public_route_table_ids[each.value.az]
  destination_cidr_block = each.value.cidr
  vpc_endpoint_id        = module.gwlbe_inspection.endpoint_ids[each.value.az]
}

############################################################
# Ingress VPC - north-south
############################################################

# IGW ingress routing: inbound traffic destined for an NLB subnet is
# redirected into that AZ's firewall endpoint before it can reach the
# load balancer.
resource "aws_route" "ingress_igw_to_gwlbe" {
  for_each = toset(var.availability_zones)

  route_table_id         = module.ingress_vpc.igw_ingress_route_table_id
  destination_cidr_block = module.ingress_vpc.public_subnet_cidrs[each.value]
  vpc_endpoint_id        = module.gwlbe_ingress.endpoint_ids[each.value]
}

# Return traffic from the NLB toward the internet is inspected on the
# way out by the same endpoint. Internal prefixes are more specific and
# are routed to the TGW inside the ingress VPC module.
resource "aws_route" "ingress_public_to_gwlbe" {
  for_each = toset(var.availability_zones)

  route_table_id         = module.ingress_vpc.public_route_table_ids[each.value]
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = module.gwlbe_ingress.endpoint_ids[each.value]
}
