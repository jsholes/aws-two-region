############################################################
# Spoke (workload) VPC
#
# /22 layout, three AZs:
#   workload  x.x.0.0/24, x.x.1.0/24, x.x.2.0/24
#   tgw       x.x.3.0/28, x.x.3.16/28, x.x.3.32/28
#
# The workload route tables point 0.0.0.0/0 at the Transit
# Gateway. Everything - spoke-to-spoke, egress to the internet,
# and cross-region - is therefore steered to the inspection VPC
# by the TGW spoke route table.
############################################################

locals {
  azs = { for idx, az in var.availability_zones : az => idx }

  workload_cidrs = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 2, idx) }
  tgw_cidrs      = { for az, idx in local.azs : az => cidrsubnet(var.cidr_block, 6, 48 + idx) }

  flow_logs_enabled = var.flow_log_bucket_arn != ""
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.tags, {
    Name = var.name
    Tier = "spoke"
  })
}

############################################################
# Subnets
############################################################

resource "aws_subnet" "workload" {
  for_each = local.workload_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = merge(var.tags, {
    Name = "${var.name}-workload-${each.key}"
    Tier = "workload"
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
############################################################

resource "aws_route_table" "workload" {
  for_each = local.azs

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, { Name = "${var.name}-rt-workload-${each.key}" })
}

resource "aws_route_table_association" "workload" {
  for_each = aws_subnet.workload

  subnet_id      = each.value.id
  route_table_id = aws_route_table.workload[each.key].id
}

resource "aws_route" "workload_default" {
  for_each = var.default_route_to_tgw ? local.azs : {}

  route_table_id         = aws_route_table.workload[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# The TGW ENI subnets only need the VPC local route; return traffic
# to the workload subnets resolves locally.
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
# S3 gateway endpoint (optional bypass of the inspection path)
############################################################

data "aws_region" "current" {}

resource "aws_vpc_endpoint" "s3" {
  count = var.enable_s3_gateway_endpoint ? 1 : 0

  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for rt in aws_route_table.workload : rt.id]

  tags = merge(var.tags, { Name = "${var.name}-vpce-s3" })
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
