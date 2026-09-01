variable "bucket_name" {
  description = "Name of the centralized log archive bucket."
  type        = string
}

variable "flow_log_prefix" {
  description = "Key prefix used by VPC flow logs."
  type        = string
  default     = "vpc-flow-logs"
}

variable "lb_access_log_prefix" {
  description = "Key prefix used by load balancer access logs."
  type        = string
  default     = "nlb-access-logs"
}

variable "retention_days" {
  description = "Days before log objects expire. Zero disables the lifecycle rule."
  type        = number
  default     = 365
}

variable "transition_to_ia_days" {
  description = "Days before log objects move to STANDARD_IA."
  type        = number
  default     = 30
}

variable "force_destroy" {
  description = "Allow Terraform to delete a non-empty bucket."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "enable_legacy_elb_log_delivery" {
  description = "Also grant the regional ELB service account write access to the load balancer log prefix. Regions launched before August 2022 - us-east-1 and us-east-2 among them - still deliver ELB access logs under that principal rather than delivery.logs.amazonaws.com."
  type        = bool
  default     = true
}
