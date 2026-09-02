############################################################
# prod / us-east-1
############################################################

region             = "us-east-1"
name_prefix        = "prod-use1"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
amazon_side_asn    = 64512

region_supernet  = "10.101.0.0/16"
remote_supernets = ["10.102.0.0/16"]

# Must be globally unique - append your account ID or org name.
log_archive_bucket_name = "netplat-logs-CHANGEME-us-east-1"

vmseries = {
  panos_version    = "11.1.4"
  license_type     = "byol"
  instance_type    = "m5.xlarge"
  min_size         = 1
  max_size         = 4
  desired_capacity = 2

  # Restrict this to your management network before the first apply.
  mgmt_allowed_cidrs = ["10.101.0.0/16"]

  # Panorama registration. Supply vm_auth_key from a secret store,
  # not from this file.
  # panorama_server         = "10.101.x.x"
  # panorama_template_stack = "aws-gwlb-stack"
  # panorama_device_group   = "aws-use1"
}

# Example published service. targets are workload IPs in the spoke
# VPCs, reached over the Transit Gateway.
ingress_listeners = {
  # https = {
  #   port                  = 443
  #   protocol              = "TCP"
  #   target_port           = 443
  #   target_protocol       = "TCP"
  #   health_check_protocol = "TCP"
  #   targets               = ["10.101.8.20", "10.101.9.20"]
  # }
}
