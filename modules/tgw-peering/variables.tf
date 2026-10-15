variable "name" {
  description = "Name for the peering attachment."
  type        = string
}

variable "inspection_side" {
  description = <<-EOT
    Which region's firewalls inspect cross-region traffic: "requester" or "accepter".

    Cross-region flows are inspected in exactly one region so that both
    directions land on the same stateful firewall. The other region routes
    the remote supernet straight at the peering attachment, bypassing its
    own inspection VPC for that traffic.
  EOT
  type        = string
  default     = "requester"

  validation {
    condition     = contains(["requester", "accepter"], var.inspection_side)
    error_message = "inspection_side must be either requester or accepter."
  }
}

############################################################
# Requester side
############################################################

variable "requester_transit_gateway_id" {
  description = "Transit Gateway ID in the requester region."
  type        = string
}

variable "requester_supernet" {
  description = "Summary prefix covering every VPC in the requester region (e.g. 10.100.0.0/16)."
  type        = string
}

variable "requester_peering_route_table_id" {
  description = "TGW route table in the requester region that the peering attachment is associated with."
  type        = string
}

variable "requester_inspection_route_table_id" {
  description = "TGW inspection route table in the requester region."
  type        = string
}

variable "requester_spoke_route_table_id" {
  description = "TGW spoke route table in the requester region."
  type        = string
}

variable "requester_inspection_attachment_id" {
  description = "Inspection VPC TGW attachment ID in the requester region."
  type        = string
}

############################################################
# Accepter side
############################################################

variable "accepter_transit_gateway_id" {
  description = "Transit Gateway ID in the accepter region."
  type        = string
}

variable "accepter_region" {
  description = "Accepter region name."
  type        = string
}

variable "accepter_supernet" {
  description = "Summary prefix covering every VPC in the accepter region (e.g. 10.200.0.0/16)."
  type        = string
}

variable "accepter_peering_route_table_id" {
  description = "TGW route table in the accepter region that the peering attachment is associated with."
  type        = string
}

variable "accepter_inspection_route_table_id" {
  description = "TGW inspection route table in the accepter region."
  type        = string
}

variable "accepter_spoke_route_table_id" {
  description = "TGW spoke route table in the accepter region."
  type        = string
}

variable "accepter_inspection_attachment_id" {
  description = "Inspection VPC TGW attachment ID in the accepter region."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
