variable "region" {
  description = "AWS region for this root module."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name used in resource names and tags."
  type        = string
  default     = "prod"
}

variable "name_prefix" {
  description = "Prefix for every resource in this region."
  type        = string
  default     = "prod-use1"
}

variable "availability_zones" {
  description = "AZs to build into, in order."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "amazon_side_asn" {
  description = "Transit Gateway ASN for this region."
  type        = number
  default     = 64512
}

variable "region_supernet" {
  description = "Summary prefix for this region."
  type        = string
  default     = "10.101.0.0/16"
}

variable "remote_supernets" {
  description = "Supernets of the other regions, reachable over TGW peering."
  type        = list(string)
  default     = ["10.102.0.0/16"]
}

variable "log_archive_bucket_name" {
  description = "Name of this region's log archive bucket. Must be globally unique."
  type        = string
}

variable "vmseries" {
  description = "VM-Series fleet settings for this region."
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

variable "ingress_listeners" {
  description = "Services published by the ingress NLB."
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

variable "extra_tags" {
  description = "Additional tags merged into the defaults."
  type        = map(string)
  default     = {}
}
