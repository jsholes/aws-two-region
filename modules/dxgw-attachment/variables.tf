variable "dx_gateway_id" {
  description = "Direct Connect gateway ID to associate this region's Transit Gateway with."
  type        = string
}

variable "transit_gateway_id" {
  description = "Transit Gateway in this region."
  type        = string
}

variable "create_association" {
  description = <<-EOT
    Create the Direct Connect gateway association. Set false when the
    association is owned elsewhere - a different account using the proposal
    and acceptance flow, or a pre-existing association you only want to route
    against. When false this module just looks the attachment up and wires the
    routing.
  EOT
  type        = bool
  default     = true
}

variable "allowed_prefixes" {
  description = <<-EOT
    Prefixes the Direct Connect gateway advertises FROM AWS TO on-premises.

    This direction is a static list, not BGP propagation - the TGW's known
    routes are not advertised automatically. Summarize: put the region
    supernet here, not each VPC /22. AWS caps this at 200 prefixes per
    transit gateway association.
  EOT
  type        = list(string)

  validation {
    condition     = length(var.allowed_prefixes) > 0 && length(var.allowed_prefixes) <= 200
    error_message = "allowed_prefixes must contain between 1 and 200 prefixes."
  }
}

############################################################
# Routing
############################################################

variable "hybrid_route_table_id" {
  description = "TGW route table the DX gateway attachment is associated with. Deliberately its own domain, not the spoke table."
  type        = string
}

variable "inspection_route_table_id" {
  description = "TGW inspection route table. On-premises prefixes are propagated here so post-firewall traffic can reach them."
  type        = string
}

variable "inspection_attachment_id" {
  description = "Inspection VPC TGW attachment ID, used as the next hop for on-premises traffic entering AWS."
  type        = string
}

variable "inspect_inbound" {
  description = <<-EOT
    Force on-premises to AWS traffic through the inspection VPC.

    Leave true unless the firewalls are deliberately out of the hybrid path.
    With it false, traffic from Direct Connect reaches the spokes directly
    using whatever prefixes are propagated into the hybrid route table.
  EOT
  type        = bool
  default     = true
}

variable "inspected_prefixes" {
  description = <<-EOT
    Destinations in the hybrid route table that are sent to the firewall.
    Normally just this region's supernet.

    Deliberately excludes the other region's supernet: both regional TGWs
    associate with the same DX gateway, so on-premises has a direct path into
    each region and should not hairpin cross-region traffic through whichever
    region it happened to land in.
  EOT
  type        = list(string)
}

variable "additional_propagation_route_table_ids" {
  description = "Extra TGW route tables to propagate on-premises prefixes into. Adding the spoke table here defeats the inspection default route - see the module header."
  type        = list(string)
  default     = []
}

variable "association_timeout" {
  description = "Timeout for the DX gateway association. These routinely take 10-30 minutes."
  type        = string
  default     = "60m"
}

