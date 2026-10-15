############################################################
# Transit Gateway
#
# Default association and propagation are disabled on purpose:
# every attachment is placed in an explicit route table by the
# module that creates it, so the routing domain is auditable.
#
# Route domains:
#   spoke      - all workload VPC attachments
#   inspection - the centralized firewall / GWLB VPC attachment
#   ingress    - the internet ingress landing zone VPC attachment
#   peering    - the cross-region TGW peering attachment
#   hybrid     - Direct Connect gateway and VPN attachments
#
# peering and hybrid exist so that off-cloud and cross-region prefixes
# never get propagated into the spoke table. A propagated prefix there
# would be more specific than the spoke default route and would send
# traffic around the firewall instead of through it.
############################################################

resource "aws_ec2_transit_gateway" "this" {
  description = "${var.name_prefix} transit gateway"

  amazon_side_asn                 = var.amazon_side_asn
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments ? "enable" : "disable"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = var.enable_dns_support ? "enable" : "disable"
  vpn_ecmp_support                = var.enable_vpn_ecmp_support ? "enable" : "disable"
  multicast_support               = var.enable_multicast_support ? "enable" : "disable"

  tags = merge(var.tags, { Name = "${var.name_prefix}-tgw" })
}

locals {
  route_tables = ["spoke", "inspection", "ingress", "peering", "hybrid"]
}

resource "aws_ec2_transit_gateway_route_table" "this" {
  for_each = toset(local.route_tables)

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, { Name = "${var.name_prefix}-tgw-rt-${each.value}" })
}
