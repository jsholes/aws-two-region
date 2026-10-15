############################################################
# Direct Connect gateway attachment to the regional Transit Gateway
#
# The two directions are not symmetric, and conflating them is the
# usual source of hybrid routing bugs:
#
#   on-premises -> AWS   real BGP propagation. Routes learned from the
#                        customer router land in whichever TGW route
#                        tables you enable propagation on.
#
#   AWS -> on-premises   NOT propagation. var.allowed_prefixes is a
#                        static list on the association; the DX gateway
#                        advertises exactly that and nothing else.
#
# Routing model, which mirrors the cross-region peering design:
#
#   hybrid rt      local supernet -> inspection attachment
#   inspection rt  on-premises prefixes propagated
#   spoke rt       nothing - 0.0.0.0/0 already points at the firewall
#
# The spoke table is the trap. Propagating on-premises prefixes there
# makes them more specific than the spoke default route, so spoke to
# on-premises traffic would leave over Direct Connect without ever
# reaching an appliance. Appliance mode on the inspection attachment
# keeps both directions of an inspected flow on the same firewall.
#
# Nothing here takes tags: aws_dx_gateway_association and the implicit
# TGW attachment it creates are not taggable resources.
############################################################

resource "aws_dx_gateway_association" "this" {
  count = var.create_association ? 1 : 0

  dx_gateway_id         = var.dx_gateway_id
  associated_gateway_id = var.transit_gateway_id
  allowed_prefixes      = var.allowed_prefixes

  timeouts {
    create = var.association_timeout
    update = var.association_timeout
    delete = var.association_timeout
  }
}

# AWS creates the TGW attachment implicitly as part of the association -
# there is no aws_ec2_transit_gateway_*_attachment resource for Direct
# Connect, so it has to be looked up before it can be routed against.
data "aws_ec2_transit_gateway_dx_gateway_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  dx_gateway_id      = var.dx_gateway_id

  depends_on = [aws_dx_gateway_association.this]
}

############################################################
# Association: the attachment lives in the hybrid domain
############################################################

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_dx_gateway_attachment.this.id
  transit_gateway_route_table_id = var.hybrid_route_table_id
}

############################################################
# Propagation: on-premises prefixes into the inspection domain, so
# traffic that has cleared the firewall knows how to get back out.
############################################################

resource "aws_ec2_transit_gateway_route_table_propagation" "inspection" {
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_dx_gateway_attachment.this.id
  transit_gateway_route_table_id = var.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "additional" {
  for_each = toset(var.additional_propagation_route_table_ids)

  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_dx_gateway_attachment.this.id
  transit_gateway_route_table_id = each.value
}

############################################################
# Static routes: everything arriving from Direct Connect and destined
# for this region goes to the firewall first.
############################################################

resource "aws_ec2_transit_gateway_route" "inbound_to_inspection" {
  for_each = var.inspect_inbound ? toset(var.inspected_prefixes) : toset([])

  transit_gateway_route_table_id = var.hybrid_route_table_id
  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = var.inspection_attachment_id

  depends_on = [aws_ec2_transit_gateway_route_table_association.this]
}
