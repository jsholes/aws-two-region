variable "name" {
  description = "Short name for this spoke (e.g. prod-use1-spoke-01)."
  type        = string
}

variable "cidr_block" {
  description = "Primary CIDR of the spoke VPC. The subnet math in this module assumes a /22."
  type        = string

  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) == 22
    error_message = "This module's subnet plan assumes a /22 VPC CIDR."
  }
}

variable "availability_zones" {
  description = "AZ names to build into, in order. One workload subnet and one TGW attachment subnet per AZ."
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
  description = "TGW route table this attachment is associated with (the spoke domain)."
  type        = string
}

variable "transit_gateway_propagation_route_table_ids" {
  description = "TGW route tables this VPC's prefixes are propagated into (inspection, ingress, peering domains)."
  type        = list(string)
  default     = []
}

variable "default_route_to_tgw" {
  description = "Install 0.0.0.0/0 -> TGW in the workload route tables so all north-south and east-west traffic is centrally inspected."
  type        = bool
  default     = true
}

variable "enable_s3_gateway_endpoint" {
  description = "Create an S3 gateway endpoint so bulk S3 traffic bypasses the inspection path."
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
