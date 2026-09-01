############################################################
# Gateway Load Balancer + GENEVE target group + endpoint service
#
# The GWLB fronts the VM-Series auto scaling groups. It is exposed to
# the rest of the network as a VPC endpoint service, so consumers (the
# inspection VPC itself for east-west, and the ingress VPC for
# north-south) create Gateway Load Balancer endpoints against it.
#
# Cross-zone load balancing is off by default. Combined with
# appliance_mode_support on the inspection VPC's TGW attachment, that
# keeps both directions of a flow on the same AZ's firewall.
############################################################

data "aws_caller_identity" "current" {}

resource "aws_lb" "this" {
  name               = substr(var.name, 0, 32)
  load_balancer_type = "gateway"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_deletion_protection       = var.enable_deletion_protection

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_lb_target_group" "this" {
  name        = substr("${var.name}-tg", 0, 32)
  vpc_id      = var.vpc_id
  target_type = "instance"
  protocol    = "GENEVE"
  port        = var.target_port

  health_check {
    protocol            = var.health_check_protocol
    port                = var.health_check_port
    path                = contains(["HTTP", "HTTPS"], var.health_check_protocol) ? var.health_check_path : null
    interval            = var.health_check_interval
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }

  stickiness {
    type    = var.flow_stickiness
    enabled = true
  }

  target_failover {
    on_deregistration = var.target_failover_on_deregistration
    on_unhealthy      = var.target_failover_on_unhealthy
  }

  tags = merge(var.tags, { Name = "${var.name}-tg" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  tags = merge(var.tags, { Name = "${var.name}-listener" })
}

############################################################
# Endpoint service
############################################################

resource "aws_vpc_endpoint_service" "this" {
  acceptance_required        = var.endpoint_service_acceptance_required
  gateway_load_balancer_arns = [aws_lb.this.arn]

  tags = merge(var.tags, { Name = "${var.name}-endpoint-service" })
}

resource "aws_vpc_endpoint_service_allowed_principal" "this" {
  for_each = toset(
    length(var.endpoint_service_allowed_principals) > 0
    ? var.endpoint_service_allowed_principals
    : ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
  )

  vpc_endpoint_service_id = aws_vpc_endpoint_service.this.id
  principal_arn           = each.value
}
