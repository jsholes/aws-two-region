############################################################
# Cross-region Transit Gateway peering
#
# Applied after both region roots. It reads their state rather than
# duplicating any of their inputs, so the only thing to keep in sync by
# hand is which side inspects: var.inspection_side here must match
# propagate_into_peering_route_table in the region roots (the
# inspecting region sets it to false).
############################################################

locals {
  tags = merge({
    Environment = var.environment
    ManagedBy   = "terraform"
    Component   = "network-platform"
  }, var.extra_tags)
}

data "terraform_remote_state" "requester" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_requester
    key    = var.state_key_requester
    region = var.requester_region
  }
}

data "terraform_remote_state" "accepter" {
  backend = "s3"

  config = {
    bucket = var.state_bucket_accepter
    key    = var.state_key_accepter
    region = var.accepter_region
  }
}

module "peering" {
  source = "../../../modules/tgw-peering"

  providers = {
    aws.requester = aws.requester
    aws.accepter  = aws.accepter
  }

  name            = "${var.environment}-${var.requester_region}-to-${var.accepter_region}"
  inspection_side = var.inspection_side

  requester_transit_gateway_id        = data.terraform_remote_state.requester.outputs.transit_gateway_id
  requester_supernet                  = data.terraform_remote_state.requester.outputs.region_supernet
  requester_peering_route_table_id    = data.terraform_remote_state.requester.outputs.transit_gateway_route_table_ids["peering"]
  requester_inspection_route_table_id = data.terraform_remote_state.requester.outputs.transit_gateway_route_table_ids["inspection"]
  requester_spoke_route_table_id      = data.terraform_remote_state.requester.outputs.transit_gateway_route_table_ids["spoke"]
  requester_inspection_attachment_id  = data.terraform_remote_state.requester.outputs.inspection_attachment_id

  accepter_transit_gateway_id        = data.terraform_remote_state.accepter.outputs.transit_gateway_id
  accepter_region                    = var.accepter_region
  accepter_supernet                  = data.terraform_remote_state.accepter.outputs.region_supernet
  accepter_peering_route_table_id    = data.terraform_remote_state.accepter.outputs.transit_gateway_route_table_ids["peering"]
  accepter_inspection_route_table_id = data.terraform_remote_state.accepter.outputs.transit_gateway_route_table_ids["inspection"]
  accepter_spoke_route_table_id      = data.terraform_remote_state.accepter.outputs.transit_gateway_route_table_ids["spoke"]
  accepter_inspection_attachment_id  = data.terraform_remote_state.accepter.outputs.inspection_attachment_id

  tags = local.tags
}
