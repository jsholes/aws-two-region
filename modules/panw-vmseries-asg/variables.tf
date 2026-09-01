variable "name" {
  description = "Name prefix for the firewall fleet (e.g. prod-use1-vmseries)."
  type        = string
}

variable "vpc_id" {
  description = "Inspection VPC ID."
  type        = string
}

variable "vpc_cidr_block" {
  description = "Inspection VPC CIDR. Used to scope the data plane security group."
  type        = string
}

variable "data_subnet_ids" {
  description = "Map of AZ to appliance data plane subnet ID. eth0 (post mgmt-interface-swap) lands here and is what the GWLB target group registers."
  type        = map(string)
}

variable "mgmt_subnet_ids" {
  description = "Map of AZ to appliance management subnet ID. eth1 (post mgmt-interface-swap) lands here."
  type        = map(string)
}

variable "target_group_arn" {
  description = "GENEVE target group ARN from the gwlb module."
  type        = string
}

############################################################
# Image and instance
############################################################

variable "ami_id" {
  description = "Explicit VM-Series AMI ID. Leave empty to look one up from the Marketplace using the filters below."
  type        = string
  default     = ""
}

variable "panos_version" {
  description = "PAN-OS version used to build the Marketplace AMI name filter."
  type        = string
  default     = "11.1.4"
}

variable "license_type" {
  description = "VM-Series Marketplace listing: byol, bundle1 or bundle2."
  type        = string
  default     = "byol"

  validation {
    condition     = contains(["byol", "bundle1", "bundle2"], var.license_type)
    error_message = "license_type must be one of: byol, bundle1, bundle2."
  }
}

variable "ami_name_filter_override" {
  description = "Override the generated Marketplace AMI name filter entirely."
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type. VM-Series with GWLB requires a type that supports at least two ENIs and the DPDK drivers - m5.xlarge / c5.xlarge and up."
  type        = string
  default     = "m5.xlarge"
}

variable "key_name" {
  description = "EC2 key pair name for the VM-Series management interface. Empty means no key pair."
  type        = string
  default     = ""
}

variable "ebs_encrypted" {
  description = "Encrypt the root volume."
  type        = bool
  default     = true
}

variable "ebs_kms_key_id" {
  description = "KMS key for root volume encryption. Empty uses the AWS managed EBS key."
  type        = string
  default     = ""
}

############################################################
# Scaling
############################################################

variable "min_size" {
  description = "Minimum firewalls per AZ."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum firewalls per AZ."
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired firewalls per AZ."
  type        = number
  default     = 2
}

variable "health_check_grace_period" {
  description = "Seconds before ASG health checks count. PAN-OS takes several minutes to boot and commit its bootstrap config."
  type        = number
  default     = 900
}

variable "enable_target_tracking_scaling" {
  description = "Attach a CPU target tracking policy to each ASG."
  type        = bool
  default     = false
}

variable "target_cpu_utilization" {
  description = "Target average CPU for the scaling policy."
  type        = number
  default     = 60
}

############################################################
# Bootstrap and management access
############################################################

variable "bootstrap_bucket_name" {
  description = "Name of the S3 bootstrap bucket. Empty generates one from the account ID and region."
  type        = string
  default     = ""
}

variable "create_bootstrap_bucket" {
  description = "Create the bootstrap bucket and its folder structure. Set false to point at an existing bucket."
  type        = bool
  default     = true
}

variable "bootstrap_xml_path" {
  description = "Local path to a bootstrap.xml uploaded to config/. Empty skips it - the firewalls then come up with the init-cfg.txt settings only, or register to Panorama for their config."
  type        = string
  default     = ""
}

variable "panorama_server" {
  description = "Primary Panorama IP or FQDN."
  type        = string
  default     = ""
}

variable "panorama_server_2" {
  description = "Secondary Panorama IP or FQDN."
  type        = string
  default     = ""
}

variable "panorama_template_stack" {
  description = "Panorama template stack name (tplname)."
  type        = string
  default     = ""
}

variable "panorama_device_group" {
  description = "Panorama device group name (dgname)."
  type        = string
  default     = ""
}

variable "vm_auth_key" {
  description = "Panorama VM auth key used for bootstrap registration. Supply through a secret store, not a checked-in tfvars file."
  type        = string
  default     = ""
  sensitive   = true
}

variable "vm_series_auth_codes" {
  description = "BYOL authcode written to license/authcodes in the bootstrap bucket. Empty skips it."
  type        = string
  default     = ""
  sensitive   = true
}

variable "mgmt_allowed_cidrs" {
  description = "CIDRs allowed to reach the VM-Series management interface on TCP 22 and 443."
  type        = list(string)
  default     = []
}

variable "health_check_ingress_port" {
  description = "Port on the data plane interface that answers GWLB health checks. Must match the gwlb module's health_check_port."
  type        = number
  default     = 80
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}
