variable "name" {
  description = "Name of the inspection VPC (e.g. prod-use1-inspection)."
  type        = string
}

variable "cidr_block" {
  description = "Primary CIDR of the inspection VPC. The subnet math in this module assumes a /22."
  type        = string

  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) == 22
    error_message = "This module's subnet plan assumes a /22 VPC CIDR."
  }
}

variable "availability_zones" {
  description = "AZ names to build into, in order. One of each subnet type per AZ."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2 && length(var.availability_zones) <= 3
    error_message = "This module's subnet plan carves a /22 into at most three AZs."
  }
}

variable "transit_gateway_id" {
  description = "Transit Gateway to attach this VPC to."
  type        = string
}

variable "transit_gateway_association_route_table_id" {
  description = "TGW route table this attachment is associated with (the inspection domain)."
  type        = string
}

variable "transit_gateway_propagation_route_table_ids" {
  description = "TGW route tables this VPC's prefix is propagated into. Normally empty - spokes reach the firewall via a static default route, not a propagated prefix."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Create one NAT gateway per AZ for centralized egress after inspection."
  type        = bool
  default     = true
}

variable "flow_log_bucket_arn" {
  description = "ARN of the centralized S3 bucket for VPC flow logs. Empty string disables flow logs."
  type        = string
  default     = ""
}

variable "flow_log_traffic_type" {
  description = "Flow log traffic type: ACCEPT, REJECT or ALL."
  type        = string
  default     = "ALL"
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
