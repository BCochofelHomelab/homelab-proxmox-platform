output "space_id" {
  value       = module.workspace.space_id
  description = "The workspace's Kibana space"
}

output "role_names" {
  value       = module.workspace.role_names
  description = "The workspace's roles, by kind: assign them to native users in Kibana"
}

output "rule_ids" {
  value       = module.workspace.rule_ids
  description = "The workspace's alerting rules"
}
