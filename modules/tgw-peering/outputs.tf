output "peering_attachment_id" {
  description = "Transit Gateway peering attachment ID."
  value       = aws_ec2_transit_gateway_peering_attachment.this.id
}

output "inspection_side" {
  description = "Region side that inspects cross-region traffic."
  value       = var.inspection_side
}
