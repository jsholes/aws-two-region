variable "name" {
  description = "Name of the ingress landing zone VPC (e.g. prod-use1-ingress)."
  type        = string
}

variable "cidr_block" {
  description = "Primary CIDR of the ingress VPC. The subnet math in this module assumes a /22."
  type        = string

  validation {
    condition     = tonumber(split("/", var.cidr_block)[1]) == 22
    error_message = "This module's subnet plan assumes a /22 VPC CIDR."
  }
}

variable "availability_zones" {
  description = "AZ names to build into, in order."
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
  description = "TGW route table this attachment is associated with (the ingress domain)."
  type        = string
}

variable "transit_gateway_propagation_route_table_ids" {
  description = "TGW route tables this VPC's prefix is propagated into. Propagate into the spoke domain so backend return traffic goes straight back to the NLB instead of looping through the firewall a second time."
  type        = list(string)
  default     = []
}

variable "internal_supernets" {
  description = "Internal prefixes reachable through the Transit Gateway (local and remote region supernets)."
  type        = list(string)
  default     = []
}

variable "enable_cross_zone_load_balancing" {
  description = "Cross-zone load balancing on the ingress NLB. Safe to enable: the NLB is a proxy, so the return path stays pinned to the node that received the flow."
  type        = bool
  default     = true
}

variable "enable_deletion_protection" {
  description = "Deletion protection on the ingress NLB."
  type        = bool
  default     = false
}

variable "access_logs_bucket" {
  description = "S3 bucket name for NLB access logs. Empty string disables access logging."
  type        = string
  default     = ""
}

variable "access_logs_prefix" {
  description = "Key prefix for NLB access logs."
  type        = string
  default     = "nlb-access-logs"
}

variable "listeners" {
  description = <<-EOT
    Ingress services published by the NLB. Each entry creates one listener and one
    target group. Targets are IP addresses of workloads in the spoke VPCs, reached
    over the Transit Gateway, so target_type is always "ip".
  EOT
  type = map(object({
    port                  = number
    protocol              = optional(string, "TCP")
    target_port           = number
    target_protocol       = optional(string, "TCP")
    certificate_arn       = optional(string)
    deregistration_delay  = optional(number, 30)
    preserve_client_ip    = optional(bool, false)
    health_check_protocol = optional(string, "TCP")
    health_check_port     = optional(string, "traffic-port")
    health_check_path     = optional(string)
    health_check_interval = optional(number, 30)
    targets               = optional(list(string), [])
  }))
  default = {}
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
