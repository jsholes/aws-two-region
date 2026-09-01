############################################################
# Ingress landing zone VPC
#
# /22 layout, three AZs:
#   public / NLB    x.x.0.0/26,  x.x.0.64/26,  x.x.0.128/26
#   private         x.x.1.0/26,  x.x.1.64/26,  x.x.1.128/26
#   gwlb endpoint   x.x.3.0/28,  x.x.3.16/28,  x.x.3.32/28
#   tgw attachment  x.x.3.64/28, x.x.3.80/28,  x.x.3.96/28
#
# North-south path:
#   client -> IGW -> (IGW ingress route table) -> GWLB endpoint
#          -> GWLB (inspection VPC) -> VM-Series -> GWLB endpoint
#          -> NLB -> TGW -> spoke workload
#
# The IGW ingress route table below is the piece that forces inbound
# traffic through inspection before it can reach the load balancer.
############################################################

locals {
  azs = { for idx, az in var.availability_zones : az => idx }

  public_cidrs  = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 4, idx) }
  private_cidrs = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 4, 4 + idx) }
  gwlbe_cidrs   = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 6, 48 + idx) }
  tgw_cidrs     = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 6, 52 + idx) }

  flow_logs_enabled   = var.flow_log_bucket_arn != ""
  access_logs_enabled = var.access_logs_bucket != ""

  # Flattened list of (listener, target IP) pairs for target registration.
  target_registrations = merge([
    for lname, l in var.listeners : {
      for ip in l.targets : "${lname}-${ip}" => { listener = lname, ip = ip }
    }
  ]...)
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
    Tier = "ingress"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

############################################################
# Subnets
############################################################

resource "aws_subnet" "public" {
  for_each = local.public_cidrs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public-nlb"
  })
}

resource "aws_subnet" "private" {
  for_each = local.private_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name}-private-${each.key}"
    Tier = "private"
  })
}

resource "aws_subnet" "gwlbe" {
  for_each = local.gwlbe_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name}-gwlbe-${each.key}"
    Tier = "gwlb-endpoint"
  })
}

resource "aws_subnet" "tgw" {
  for_each = local.tgw_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-${each.key}"
    Tier = "tgw"
  })
}

############################################################
# Route tables
#
# Routes whose next hop is a GWLB endpoint are created by the root
# module. Everything else lives here.
############################################################

# Public / NLB subnets. The root module adds 0.0.0.0/0 -> GWLB endpoint.
resource "aws_route_table" "public" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-public-${each.key}" })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}

resource "aws_route" "public_to_tgw" {
  for_each = {
    for pair in setproduct(keys(local.azs), var.internal_supernets) :
    "${pair[0]}-${pair[1]}" => { az = pair[0], cidr = pair[1] }
  }

  route_table_id         = aws_route_table.public[each.value.az].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# GWLB endpoint subnets. Post-inspection inbound traffic lands here and
# resolves the NLB through the VPC local route; the default route sends
# post-inspection outbound traffic to the internet.
resource "aws_route_table" "gwlbe" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-gwlbe-${each.key}" })
}

resource "aws_route_table_association" "gwlbe" {
  for_each = aws_subnet.gwlbe

  subnet_id      = each.value.id
  route_table_id = aws_route_table.gwlbe[each.key].id
}

resource "aws_route" "gwlbe_default" {
  for_each = local.azs

  route_table_id         = aws_route_table.gwlbe[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# Private subnets: any landing zone workload egresses through the
# Transit Gateway so it is inspected centrally like a spoke.
resource "aws_route_table" "private" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-private-${each.key}" })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route" "private_default" {
  for_each = local.azs

  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# TGW attachment subnets: local route only.
resource "aws_route_table" "tgw" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-tgw" })
}

resource "aws_route_table_association" "tgw" {
  for_each = aws_subnet.tgw

  subnet_id      = each.value.id
  route_table_id = aws_route_table.tgw.id
}

############################################################
# IGW ingress routing
#
# Associated with the internet gateway itself rather than a subnet.
# Traffic entering the VPC destined for an NLB subnet is redirected
# into the AZ-local GWLB endpoint first. The endpoint routes are added
# by the root module.
############################################################

resource "aws_route_table" "igw_ingress" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-igw-ingress" })
}

resource "aws_route_table_association" "igw_ingress" {
  gateway_id     = aws_internet_gateway.this.id
  route_table_id = aws_route_table.igw_ingress.id
}

############################################################
# Transit Gateway attachment
############################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = [for az in var.availability_zones : aws_subnet.tgw[az].id]

  dns_support                                     = "enable"
  appliance_mode_support                          = "disable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, { Name = "${var.name}-attach" })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = var.transit_gateway_association_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = toset(var.transit_gateway_propagation_route_table_ids)

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this.id
  transit_gateway_route_table_id = each.value
}

############################################################
# Internet-facing Network Load Balancer
############################################################

resource "aws_lb" "this" {
  name               = substr("${var.name}-nlb", 0, 32)
  load_balancer_type = "network"
  internal           = false
  ip_address_type    = "ipv4"

  subnets = [for az in var.availability_zones : aws_subnet.public[az].id]

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_deletion_protection       = var.enable_deletion_protection

  dynamic "access_logs" {
    for_each = local.access_logs_enabled ? [1] : []
    content {
      bucket  = var.access_logs_bucket
      prefix  = var.access_logs_prefix
      enabled = true
    }
  }

  tags = merge(var.tags, { Name = "${var.name}-nlb" })
}

resource "aws_lb_target_group" "this" {
  for_each = var.listeners

  name        = substr("${var.name}-${each.key}", 0, 32)
  vpc_id      = aws_vpc.this.id
  target_type = "ip"
  port        = each.value.target_port
  protocol    = each.value.target_protocol

  deregistration_delay = each.value.deregistration_delay
  preserve_client_ip   = each.value.preserve_client_ip

  health_check {
    protocol            = each.value.health_check_protocol
    port                = each.value.health_check_port
    path                = each.value.health_check_path
    interval            = each.value.health_check_interval
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }

  tags = merge(var.tags, { Name = "${var.name}-tg-${each.key}" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "this" {
  for_each = var.listeners

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol
  certificate_arn   = each.value.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }

  tags = merge(var.tags, { Name = "${var.name}-listener-${each.key}" })
}

# availability_zone = "all" is required for target IPs that live outside
# this VPC - here, workloads in the spoke VPCs reached over the TGW.
resource "aws_lb_target_group_attachment" "this" {
  for_each = local.target_registrations

  target_group_arn  = aws_lb_target_group.this[each.value.listener].arn
  target_id         = each.value.ip
  availability_zone = "all"
}

############################################################
# Flow logs
############################################################

resource "aws_flow_log" "this" {
  count = local.flow_logs_enabled ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  traffic_type             = var.flow_log_traffic_type
  log_destination_type     = "s3"
  log_destination          = "${var.flow_log_bucket_arn}/vpc-flow-logs/"
  max_aggregation_interval = 60

  destination_options {
    file_format                = "parquet"
    hive_compatible_partitions = true
    per_hour_partition         = true
  }

  tags = merge(var.tags, { Name = "${var.name}-flowlogs" })
}
