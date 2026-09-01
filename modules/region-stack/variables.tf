variable "name_prefix" {
  description = "Prefix for every resource in this region (e.g. prod-use1)."
  type        = string
}

variable "availability_zones" {
  description = "AZ names to build into, in order. Two or three - the /22 subnet plan does not stretch to a fourth."
  type        = list(string)
}

variable "region_supernet" {
  description = "Summary prefix covering every VPC in this region (e.g. 10.101.0.0/16)."
  type        = string
}

variable "remote_supernets" {
  description = "Supernets of the other regions, reachable over TGW peering."
  type        = list(string)
  default     = []
}

variable "amazon_side_asn" {
  description = "Private ASN for this region's Transit Gateway. Must differ from the other region's."
  type        = number
}

variable "inspection_vpc_cidr" {
  description = "CIDR of the inspection VPC (/22)."
  type        = string
}

variable "ingress_vpc_cidr" {
  description = "CIDR of the ingress landing zone VPC (/22)."
  type        = string
}

variable "spoke_vpc_cidrs" {
  description = "Map of spoke name to CIDR (/22 each)."
  type        = map(string)
}

variable "propagate_into_peering_route_table" {
  description = <<-EOT
    Propagate this region's VPC prefixes into its own TGW peering route table.

    True in the region that does NOT inspect cross-region traffic, so traffic
    arriving from the peer is delivered straight to the local VPCs. False in the
    inspecting region, where the peering route table instead carries a single
    static route to the inspection attachment - a propagated, more specific
    prefix there would silently bypass the firewall.
  EOT
  type        = bool
  default     = true
}

############################################################
# Logging
############################################################

variable "log_archive_bucket_name" {
  description = "Name of this region's log archive bucket."
  type        = string
}

variable "log_retention_days" {
  description = "Days before log objects expire."
  type        = number
  default     = 365
}

variable "enable_nlb_access_logs" {
  description = "Send ingress NLB access logs to the log archive bucket."
  type        = bool
  default     = true
}

############################################################
# Inspection
############################################################

variable "gwlb_health_check_protocol" {
  description = "GWLB target group health check protocol."
  type        = string
  default     = "HTTP"
}

variable "gwlb_health_check_port" {
  description = "GWLB target group health check port on the appliance data plane interface."
  type        = string
  default     = "80"
}

variable "gwlb_health_check_path" {
  description = "GWLB target group health check path."
  type        = string
  default     = "/php/login.php"
}

variable "vmseries" {
  description = "Palo Alto VM-Series fleet settings. See modules/panw-vmseries-asg for the meaning of each field."
  type = object({
    ami_id                         = optional(string, "")
    panos_version                  = optional(string, "11.1.4")
    license_type                   = optional(string, "byol")
    instance_type                  = optional(string, "m5.xlarge")
    key_name                       = optional(string, "")
    min_size                       = optional(number, 1)
    max_size                       = optional(number, 4)
    desired_capacity               = optional(number, 2)
    enable_target_tracking_scaling = optional(bool, false)
    mgmt_allowed_cidrs             = optional(list(string), [])
    bootstrap_xml_path             = optional(string, "")
    panorama_server                = optional(string, "")
    panorama_server_2              = optional(string, "")
    panorama_template_stack        = optional(string, "")
    panorama_device_group          = optional(string, "")
    vm_auth_key                    = optional(string, "")
    vm_series_auth_codes           = optional(string, "")
  })
  default = {}
}

############################################################
# Ingress
############################################################

variable "ingress_listeners" {
  description = "Services published by the ingress NLB. See modules/ingress-vpc for the object shape."
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

variable "enable_spoke_s3_gateway_endpoints" {
  description = "Create an S3 gateway endpoint in each spoke so bulk S3 traffic bypasses inspection."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
