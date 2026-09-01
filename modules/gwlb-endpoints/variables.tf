variable "name" {
  description = "Name prefix for the endpoints (e.g. prod-use1-inspection)."
  type        = string
}

variable "vpc_id" {
  description = "VPC the endpoints are created in."
  type        = string
}

variable "service_name" {
  description = "GWLB VPC endpoint service name to connect to."
  type        = string
}

variable "subnet_ids" {
  description = "Map of AZ to the GWLB endpoint subnet ID in that AZ. One endpoint is created per entry."
  type        = map(string)
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
