############################################################
# Palo Alto VM-Series behind a Gateway Load Balancer
#
# Deployment shape:
#   * One Auto Scaling group per AZ. The launch template pins both
#     ENIs to that AZ's subnets, so an ASG cannot span AZs.
#   * mgmt-interface-swap is enabled, which makes eth0 the data plane
#     interface. That matters because a GWLB target group with
#     target_type = "instance" registers the primary ENI - without the
#     swap it would register the management interface and never see
#     GENEVE traffic.
#   * One-arm mode: a single data plane interface receives and returns
#     the tunnelled traffic.
############################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  azs = keys(var.data_subnet_ids)

  ami_name_filters = {
    byol    = "PA-VM-AWS-${var.panos_version}*"
    bundle1 = "PA-VM-AWS-BUND1-${var.panos_version}*"
    bundle2 = "PA-VM-AWS-BUND2-${var.panos_version}*"
  }

  ami_name_filter = var.ami_name_filter_override != "" ? var.ami_name_filter_override : local.ami_name_filters[var.license_type]

  ami_id = var.ami_id != "" ? var.ami_id : try(data.aws_ami.vmseries[0].id, "")

  bucket_name = var.bootstrap_bucket_name != "" ? var.bootstrap_bucket_name : lower(substr(
    "${var.name}-bootstrap-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}",
  0, 63))

  init_cfg = <<-EOT
    type=dhcp-client
    ip-address=
    default-gateway=
    netmask=
    ipv6-address=
    ipv6-default-gateway=
    hostname=
    vm-auth-key=${var.vm_auth_key}
    panorama-server=${var.panorama_server}
    panorama-server-2=${var.panorama_server_2}
    tplname=${var.panorama_template_stack}
    dgname=${var.panorama_device_group}
    dns-primary=
    dns-secondary=
    op-command-modes=mgmt-interface-swap
    dhcp-send-hostname=yes
    dhcp-send-client-id=yes
    dhcp-accept-server-hostname=yes
    dhcp-accept-server-domain=yes
  EOT

  # PAN-OS reads these key=value pairs from EC2 user data at first boot.
  user_data = join("\n", [
    "mgmt-interface-swap=enable",
    "vmseries-bootstrap-aws-s3bucket=${local.bucket_name}",
  ])
}

data "aws_ami" "vmseries" {
  count = var.ami_id == "" ? 1 : 0

  most_recent = true
  owners      = ["aws-marketplace"]

  filter {
    name   = "name"
    values = [local.ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

############################################################
# Bootstrap bucket
#
# PAN-OS expects four top-level prefixes. config/init-cfg.txt is the
# only mandatory object; the rest may be empty.
############################################################

resource "aws_s3_bucket" "bootstrap" {
  count = var.create_bootstrap_bucket ? 1 : 0

  bucket        = local.bucket_name
  force_destroy = false

  tags = merge(var.tags, { Name = local.bucket_name })
}

resource "aws_s3_bucket_public_access_block" "bootstrap" {
  count = var.create_bootstrap_bucket ? 1 : 0

  bucket = aws_s3_bucket.bootstrap[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "bootstrap" {
  count = var.create_bootstrap_bucket ? 1 : 0

  bucket = aws_s3_bucket.bootstrap[0].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "bootstrap" {
  count = var.create_bootstrap_bucket ? 1 : 0

  bucket = aws_s3_bucket.bootstrap[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "bootstrap" {
  count = var.create_bootstrap_bucket ? 1 : 0

  bucket = aws_s3_bucket.bootstrap[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_object" "folders" {
  for_each = var.create_bootstrap_bucket ? toset(["content/", "license/", "software/", "plugins/"]) : toset([])

  bucket  = aws_s3_bucket.bootstrap[0].id
  key     = each.value
  content = ""
}

resource "aws_s3_object" "init_cfg" {
  count = var.create_bootstrap_bucket ? 1 : 0

  bucket       = aws_s3_bucket.bootstrap[0].id
  key          = "config/init-cfg.txt"
  content      = local.init_cfg
  content_type = "text/plain"
}

resource "aws_s3_object" "bootstrap_xml" {
  count = var.create_bootstrap_bucket && var.bootstrap_xml_path != "" ? 1 : 0

  bucket = aws_s3_bucket.bootstrap[0].id
  key    = "config/bootstrap.xml"
  source = var.bootstrap_xml_path
  etag   = filemd5(var.bootstrap_xml_path)
}

resource "aws_s3_object" "authcodes" {
  count = var.create_bootstrap_bucket && var.vm_series_auth_codes != "" ? 1 : 0

  bucket       = aws_s3_bucket.bootstrap[0].id
  key          = "license/authcodes"
  content      = var.vm_series_auth_codes
  content_type = "text/plain"
}

############################################################
# IAM
############################################################

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = merge(var.tags, { Name = "${var.name}-role" })
}

data "aws_iam_policy_document" "this" {
  statement {
    sid    = "BootstrapBucketRead"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = ["arn:aws:s3:::${local.bucket_name}/*"]
  }

  statement {
    sid    = "BootstrapBucketList"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = ["arn:aws:s3:::${local.bucket_name}"]
  }

  statement {
    sid    = "PublishMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
    ]
    resources = ["*"]
  }

  # Read-only EC2 visibility used by the PAN-OS AWS plugin for
  # dynamic address groups and interface discovery.
  statement {
    sid    = "DescribeEc2"
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSubnets",
      "ec2:DescribeTags",
      "ec2:DescribeVpcs",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.this.name

  tags = merge(var.tags, { Name = "${var.name}-instance-profile" })
}

############################################################
# Security groups
############################################################

resource "aws_security_group" "data" {
  name        = "${var.name}-data"
  description = "VM-Series data plane interface - GENEVE from the GWLB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-data" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "data_geneve" {
  security_group_id = aws_security_group.data.id
  description       = "GENEVE from the Gateway Load Balancer nodes"
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = 6081
  to_port           = 6081
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "data_health_check" {
  security_group_id = aws_security_group.data.id
  description       = "GWLB target group health check"
  cidr_ipv4         = var.vpc_cidr_block
  from_port         = var.health_check_ingress_port
  to_port           = var.health_check_ingress_port
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "data_all" {
  security_group_id = aws_security_group.data.id
  description       = "Return traffic to the Gateway Load Balancer"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "mgmt" {
  name        = "${var.name}-mgmt"
  description = "VM-Series management interface"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, { Name = "${var.name}-mgmt" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "mgmt_https" {
  for_each = toset(var.mgmt_allowed_cidrs)

  security_group_id = aws_security_group.mgmt.id
  description       = "PAN-OS web interface"
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "mgmt_ssh" {
  for_each = toset(var.mgmt_allowed_cidrs)

  security_group_id = aws_security_group.mgmt.id
  description       = "PAN-OS CLI"
  cidr_ipv4         = each.value
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "mgmt_all" {
  security_group_id = aws_security_group.mgmt.id
  description       = "Licensing, content updates and Panorama"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

############################################################
# Launch templates and Auto Scaling groups - one pair per AZ
############################################################

resource "aws_launch_template" "this" {
  for_each = var.data_subnet_ids

  name_prefix   = "${var.name}-${each.key}-"
  image_id      = local.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null
  user_data     = base64encode(local.user_data)

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  # device_index 0 is the data plane after mgmt-interface-swap.
  network_interfaces {
    device_index                = 0
    subnet_id                   = each.value
    security_groups             = [aws_security_group.data.id]
    associate_public_ip_address = false
    delete_on_termination       = true
    description                 = "${var.name} data plane"
  }

  network_interfaces {
    device_index          = 1
    subnet_id             = var.mgmt_subnet_ids[each.key]
    security_groups       = [aws_security_group.mgmt.id]
    delete_on_termination = true
    description           = "${var.name} management"
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 60
      volume_type           = "gp3"
      encrypted             = var.ebs_encrypted
      kms_key_id            = var.ebs_kms_key_id != "" ? var.ebs_kms_key_id : null
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-${each.key}" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-${each.key}" })
  }

  tags = merge(var.tags, { Name = "${var.name}-${each.key}" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  for_each = var.data_subnet_ids

  name = "${var.name}-${each.key}"

  # The launch template pins the ENIs to this AZ's subnets, so the ASG
  # is declared with availability_zones rather than vpc_zone_identifier.
  availability_zones = [each.key]

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  health_check_type         = "EC2"
  health_check_grace_period = var.health_check_grace_period
  default_cooldown          = 300
  wait_for_capacity_timeout = "20m"

  target_group_arns = [var.target_group_arn]

  launch_template {
    id      = aws_launch_template.this[each.key].id
    version = aws_launch_template.this[each.key].latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = var.health_check_grace_period
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, { Name = "${var.name}-${each.key}" })

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  for_each = var.enable_target_tracking_scaling ? var.data_subnet_ids : {}

  name                   = "${var.name}-${each.key}-cpu"
  autoscaling_group_name = aws_autoscaling_group.this[each.key].name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.target_cpu_utilization
  }
}
