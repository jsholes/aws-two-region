############################################################
# Gateway Load Balancer endpoints
#
# One endpoint per AZ. Route tables send traffic at the AZ-local
# endpoint, which tunnels it over GENEVE to the GWLB in the inspection
# VPC and returns it here after the firewall has passed it.
#
# Kept in its own module so route tables can depend on the endpoint IDs
# without creating a cycle back to the VPC that hosts the GWLB.
############################################################

resource "aws_vpc_endpoint" "this" {
  for_each = var.subnet_ids

  vpc_id            = var.vpc_id
  service_name      = var.service_name
  vpc_endpoint_type = "GatewayLoadBalancer"
  subnet_ids        = [each.value]

  tags = merge(var.tags, { Name = "${var.name}-gwlbe-${each.key}" })
}
