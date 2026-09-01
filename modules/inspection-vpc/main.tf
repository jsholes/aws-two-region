############################################################
# Inspection VPC
#
# /22 layout, three AZs:
#   appliance data  x.x.0.0/26,  x.x.0.64/26,  x.x.0.128/26
#   appliance mgmt  x.x.1.0/26,  x.x.1.64/26,  x.x.1.128/26
#   public / NAT    x.x.2.0/26,  x.x.2.64/26,  x.x.2.128/26
#   gwlb endpoint   x.x.3.0/28,  x.x.3.16/28,  x.x.3.32/28
#   tgw attachment  x.x.3.64/28, x.x.3.80/28,  x.x.3.96/28
#
# Routes that reference the GWLB endpoints are created by the
# calling root module (routes.tf) because the endpoints depend on
# the endpoint service, which depends on the GWLB, which lives in
# this VPC's appliance data subnets. Creating them here would be a
# dependency cycle.
############################################################

locals {
  azs = { for idx, az in var.availability_zones : az => idx }

  data_cidrs   = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 4, idx) }
  mgmt_cidrs   = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 4, 4 + idx) }
  public_cidrs = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 4, 8 + idx) }
  gwlbe_cidrs  = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 6, 48 + idx) }
  tgw_cidrs    = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 6, 52 + idx) }

  flow_logs_enabled = var.flow_log_bucket_arn != ""
  nat_azs           = var.enable_nat_gateway ? local.azs : {}
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
    Tier = "inspection"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

############################################################
# Subnets
############################################################

resource "aws_subnet" "data" {
  for_each = local.data_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name}-appliance-data-${each.key}"
    Tier = "appliance-data"
  })
}

resource "aws_subnet" "mgmt" {
  for_each = local.mgmt_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name}-appliance-mgmt-${each.key}"
    Tier = "appliance-mgmt"
  })
}

resource "aws_subnet" "public" {
  for_each = local.public_cidrs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${each.key}"
    Tier = "public"
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
# NAT gateways - centralized egress, one per AZ
############################################################

resource "aws_eip" "nat" {
  for_each = local.nat_azs

  domain = "vpc"

  tags = merge(var.tags, { Name = "${var.name}-nat-eip-${each.key}" })
}

resource "aws_nat_gateway" "this" {
  for_each = local.nat_azs

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, { Name = "${var.name}-nat-${each.key}" })

  depends_on = [aws_internet_gateway.this]
}

############################################################
# Route tables
#
# Only the local / IGW / NAT routes are created here. Routes whose
# next hop is a GWLB endpoint are added by the root module.
############################################################

# Appliance data plane: local only. GENEVE traffic arrives from the
# GWLB and is returned to it inside the VPC.
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-appliance-data" })
}

resource "aws_route_table_association" "data" {
  for_each = aws_subnet.data

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}

# Appliance management: outbound through NAT for licensing, updates
# and Panorama connectivity.
resource "aws_route_table" "mgmt" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-appliance-mgmt-${each.key}" })
}

resource "aws_route_table_association" "mgmt" {
  for_each = aws_subnet.mgmt

  subnet_id      = each.value.id
  route_table_id = aws_route_table.mgmt[each.key].id
}

resource "aws_route" "mgmt_default" {
  for_each = local.nat_azs

  route_table_id         = aws_route_table.mgmt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# Public / NAT subnets: default to the IGW. Return traffic toward the
# internal supernets is sent back through the GWLB endpoint by the
# root module so that egress flows are inspected symmetrically.
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

resource "aws_route" "public_default" {
  for_each = local.azs

  route_table_id         = aws_route_table.public[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# GWLB endpoint subnets: post-inspection traffic lands here. The root
# module adds "internal supernets -> TGW" and "0.0.0.0/0 -> NAT".
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
  for_each = local.nat_azs

  route_table_id         = aws_route_table.gwlbe[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# TGW attachment subnets: everything arriving from the Transit Gateway
# is pushed into the AZ-local GWLB endpoint by the root module.
resource "aws_route_table" "tgw" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-tgw-${each.key}" })
}

resource "aws_route_table_association" "tgw" {
  for_each = aws_subnet.tgw

  subnet_id      = each.value.id
  route_table_id = aws_route_table.tgw[each.key].id
}

############################################################
# Transit Gateway attachment
#
# appliance_mode_support is mandatory here: it pins a flow to a single
# AZ's endpoint for both directions, which is what keeps the stateful
# firewall from seeing half a conversation.
############################################################

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = [for az in var.availability_zones : aws_subnet.tgw[az].id]

  dns_support                                     = "enable"
  appliance_mode_support                          = "enable"
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
