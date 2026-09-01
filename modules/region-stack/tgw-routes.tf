############################################################
# Transit Gateway static routes
#
# Propagation handles everything that should be reachable directly.
# These two static routes are what force traffic through inspection.
############################################################

# Spoke domain: no propagated defaults, so a single static default
# route sends spoke-to-spoke, spoke-to-internet and any unknown
# destination into the inspection VPC. The ingress VPC prefix is
# propagated into this table and is more specific, so NLB return
# traffic goes straight back without a second trip through the
# firewall.
resource "aws_ec2_transit_gateway_route" "spoke_default" {
  transit_gateway_route_table_id = module.tgw.spoke_route_table_id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.transit_gateway_attachment_id
}

# Ingress domain: egress from landing zone workloads is inspected the
# same way spoke egress is.
resource "aws_ec2_transit_gateway_route" "ingress_default" {
  transit_gateway_route_table_id = module.tgw.ingress_route_table_id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.transit_gateway_attachment_id
}
