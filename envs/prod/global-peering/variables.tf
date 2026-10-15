variable "environment" {
  description = "Environment name used in tags."
  type        = string
  default     = "prod"
}

variable "requester_region" {
  description = "Region that initiates the peering attachment."
  type        = string
  default     = "us-east-1"
}

variable "accepter_region" {
  description = "Region that accepts the peering attachment."
  type        = string
  default     = "us-east-2"
}

variable "inspection_side" {
  description = "Which side inspects cross-region traffic: requester or accepter. Must line up with propagate_into_peering_route_table in the two region roots - the inspecting side sets it to false."
  type        = string
  default     = "requester"
}

variable "state_bucket_requester" {
  description = "S3 bucket holding the requester region's state."
  type        = string
}

variable "state_key_requester" {
  description = "State key for the requester region."
  type        = string
  default     = "prod/us-east-1/network/terraform.tfstate"
}

variable "state_bucket_accepter" {
  description = "S3 bucket holding the accepter region's state."
  type        = string
}

variable "state_key_accepter" {
  description = "State key for the accepter region."
  type        = string
  default     = "prod/us-east-2/network/terraform.tfstate"
}

variable "extra_tags" {
  description = "Additional tags merged into the defaults."
  type        = map(string)
  default     = {}
}
