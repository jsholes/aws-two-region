variable "name" {
  description = "Name of the Gateway Load Balancer (e.g. prod-use1-gwlb)."
  type        = string
}

variable "vpc_id" {
  description = "Inspection VPC ID that hosts the GWLB and its targets."
  type        = string
}

variable "subnet_ids" {
  description = "Appliance data plane subnet IDs, one per AZ, that the GWLB places its nodes in."
  type        = list(string)
}

variable "enable_cross_zone_load_balancing" {
  description = "Cross-zone load balancing on the GWLB. Left off so a flow stays inside its own AZ, which is what appliance mode on the TGW attachment relies on."
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Deletion protection on the GWLB."
  type        = bool
  default     = false
}

variable "target_port" {
  description = "GENEVE port. Fixed at 6081 by the GWLB data plane."
  type        = number
  default     = 6081
}

variable "health_check_protocol" {
  description = "Health check protocol against the appliance data plane interface (TCP, HTTP or HTTPS)."
  type        = string
  default     = "HTTP"
}

variable "health_check_port" {
  description = "Health check port on the appliance. For VM-Series this is a port the dataplane interface management profile is configured to answer on."
  type        = string
  default     = "80"
}

variable "health_check_path" {
  description = "Health check path when the protocol is HTTP or HTTPS."
  type        = string
  default     = "/php/login.php"
}

variable "health_check_interval" {
  description = "Seconds between health checks."
  type        = number
  default     = 10
}

variable "healthy_threshold" {
  description = "Consecutive successes before a target is considered healthy."
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "Consecutive failures before a target is considered unhealthy."
  type        = number
  default     = 3
}

variable "flow_stickiness" {
  description = "GWLB flow stickiness: source_ip_dest_ip_proto (5-tuple minus ports, the default for stateful firewalls) or source_ip_dest_ip."
  type        = string
  default     = "source_ip_dest_ip_proto"
}

variable "target_failover_on_deregistration" {
  description = "What happens to existing flows when a target deregisters: rebalance or no_rebalance."
  type        = string
  default     = "rebalance"
}

variable "target_failover_on_unhealthy" {
  description = "What happens to existing flows when a target goes unhealthy: rebalance or no_rebalance."
  type        = string
  default     = "rebalance"
}

variable "endpoint_service_acceptance_required" {
  description = "Require manual acceptance of endpoint connections to the GWLB endpoint service."
  type        = bool
  default     = false
}

variable "endpoint_service_allowed_principals" {
  description = "IAM principal ARNs allowed to create endpoints against the GWLB endpoint service. Defaults to the current account when empty."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
