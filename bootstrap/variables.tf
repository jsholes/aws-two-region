variable "org_prefix" {
  description = "Short prefix for state resource names."
  type        = string
  default     = "netplat"
}

variable "tags" {
  description = "Default tags applied to bootstrap resources."
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Component = "tf-backend"
  }
}
