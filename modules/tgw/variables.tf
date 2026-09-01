variable "name_prefix" {
  description = "Prefix applied to all resource names (e.g. prod-use1)."
  type        = string
}

variable "amazon_side_asn" {
  description = "Private ASN for the Amazon side of the Transit Gateway. Must be unique per region when TGWs are peered."
  type        = number
}

variable "auto_accept_shared_attachments" {
  description = "Auto-accept cross-account attachments. Left disabled for the single-account model."
  type        = bool
  default     = false
}

variable "enable_dns_support" {
  description = "Enable DNS support on the Transit Gateway."
  type        = bool
  default     = true
}

variable "enable_vpn_ecmp_support" {
  description = "Enable ECMP across VPN attachments."
  type        = bool
  default     = true
}

variable "enable_multicast_support" {
  description = "Enable multicast on the Transit Gateway. Cannot be changed after creation."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
