output "transit_gateway_attachment_id" {
  description = "TGW attachment ID for the Direct Connect gateway."
  value       = data.aws_ec2_transit_gateway_dx_gateway_attachment.this.id
}

output "dx_gateway_association_id" {
  description = "Direct Connect gateway association ID, when this module created it."
  value       = try(aws_dx_gateway_association.this[0].id, null)
}

output "allowed_prefixes" {
  description = "Prefixes advertised from AWS to on-premises."
  value       = var.allowed_prefixes
}
