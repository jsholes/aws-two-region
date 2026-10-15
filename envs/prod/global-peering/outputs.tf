output "peering_attachment_id" {
  description = "Transit Gateway peering attachment ID."
  value       = module.peering.peering_attachment_id
}

output "inspection_side" {
  description = "Region side inspecting cross-region traffic."
  value       = module.peering.inspection_side
}
