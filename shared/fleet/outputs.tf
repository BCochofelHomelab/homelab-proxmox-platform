output "integration_versions" {
  description = "Installed integration packages and their versions."
  value       = { for k, v in elasticstack_fleet_integration.this : k => v.version }
}
