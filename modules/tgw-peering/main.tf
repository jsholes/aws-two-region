############################################################
# Inter-region Transit Gateway peering
#
# Routing model - cross-region traffic is inspected once, in the
# region named by var.inspection_side, so that both directions of a
# flow hit the same stateful firewall:
#
#   inspecting region
#     spoke rt       remote supernet -> inspection attachment
#     inspection rt  remote supernet -> peering attachment
#     peering rt     local supernet  -> inspection attachment
#
#   bypass region
#     spoke rt       remote supernet -> peering attachment
#     peering rt     local prefixes learned by propagation
#
# The bypass region must NOT propagate its spoke prefixes into the
# inspecting region's peering route table, or the more specific
# propagated routes would win and skip the firewall.
############################################################

data "aws_caller_identity" "current" {
  provider = aws.requester
}

locals {
  requester_inspects = var.inspection_side == "requester"
  accepter_inspects  = var.inspection_side == "accepter"
}

resource "aws_ec2_transit_gateway_peering_attachment" "this" {
  provider = aws.requester

  transit_gateway_id      = var.requester_transit_gateway_id
  peer_transit_gateway_id = var.accepter_transit_gateway_id
  peer_region             = var.accepter_region
  peer_account_id         = data.aws_caller_identity.current.account_id

  tags = merge(var.tags, {
    Name = var.name
    Side = "requester"
  })
}

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "this" {
  provider = aws.accepter

  transit_gateway_attachment_id = aws_ec2_transit_gateway_peering_attachment.this.id

  tags = merge(var.tags, {
    Name = var.name
    Side = "accepter"
  })
}

############################################################
# Associate the peering attachment with the peering route table
# on both sides.
############################################################

resource "aws_ec2_transit_gateway_route_table_association" "requester" {
  provider = aws.requester

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id
  transit_gateway_route_table_id = var.requester_peering_route_table_id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.this]
}

resource "aws_ec2_transit_gateway_route_table_association" "accepter" {
  provider = aws.accepter

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.this.id
  transit_gateway_route_table_id = var.accepter_peering_route_table_id
}

############################################################
# Routes - requester region inspects
############################################################

resource "aws_ec2_transit_gateway_route" "req_spoke_to_inspection" {
  provider = aws.requester
  count    = local.requester_inspects ? 1 : 0

  transit_gateway_route_table_id = var.requester_spoke_route_table_id
  destination_cidr_block         = var.accepter_supernet
  transit_gateway_attachment_id  = var.requester_inspection_attachment_id
}

resource "aws_ec2_transit_gateway_route" "req_inspection_to_peer" {
  provider = aws.requester
  count    = local.requester_inspects ? 1 : 0

  transit_gateway_route_table_id = var.requester_inspection_route_table_id
  destination_cidr_block         = var.accepter_supernet
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id

  depends_on = [aws_ec2_transit_gateway_route_table_association.requester]
}

resource "aws_ec2_transit_gateway_route" "req_peering_to_inspection" {
  provider = aws.requester
  count    = local.requester_inspects ? 1 : 0

  transit_gateway_route_table_id = var.requester_peering_route_table_id
  destination_cidr_block         = var.requester_supernet
  transit_gateway_attachment_id  = var.requester_inspection_attachment_id

  depends_on = [aws_ec2_transit_gateway_route_table_association.requester]
}

resource "aws_ec2_transit_gateway_route" "acc_spoke_to_peer" {
  provider = aws.accepter
  count    = local.requester_inspects ? 1 : 0

  transit_gateway_route_table_id = var.accepter_spoke_route_table_id
  destination_cidr_block         = var.requester_supernet
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.this.id
}

############################################################
# Routes - accepter region inspects
############################################################

resource "aws_ec2_transit_gateway_route" "acc_spoke_to_inspection" {
  provider = aws.accepter
  count    = local.accepter_inspects ? 1 : 0

  transit_gateway_route_table_id = var.accepter_spoke_route_table_id
  destination_cidr_block         = var.requester_supernet
  transit_gateway_attachment_id  = var.accepter_inspection_attachment_id
}

resource "aws_ec2_transit_gateway_route" "acc_inspection_to_peer" {
  provider = aws.accepter
  count    = local.accepter_inspects ? 1 : 0

  transit_gateway_route_table_id = var.accepter_inspection_route_table_id
  destination_cidr_block         = var.requester_supernet
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.this.id

  depends_on = [aws_ec2_transit_gateway_route_table_association.accepter]
}

resource "aws_ec2_transit_gateway_route" "acc_peering_to_inspection" {
  provider = aws.accepter
  count    = local.accepter_inspects ? 1 : 0

  transit_gateway_route_table_id = var.accepter_peering_route_table_id
  destination_cidr_block         = var.accepter_supernet
  transit_gateway_attachment_id  = var.accepter_inspection_attachment_id

  depends_on = [aws_ec2_transit_gateway_route_table_association.accepter]
}

resource "aws_ec2_transit_gateway_route" "req_spoke_to_peer" {
  provider = aws.requester
  count    = local.accepter_inspects ? 1 : 0

  transit_gateway_route_table_id = var.requester_spoke_route_table_id
  destination_cidr_block         = var.accepter_supernet
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.this.id

  depends_on = [aws_ec2_transit_gateway_route_table_association.requester]
}
