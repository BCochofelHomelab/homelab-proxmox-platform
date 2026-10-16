output "fleet_server_policy_id" {
  value       = elasticstack_fleet_agent_policy.fleet_server.policy_id
  description = "Fleet Server's agent policy (ansible/inventory/group_vars/fleet_server.yml)"
}

output "fleet_server_host" {
  value       = one(elasticstack_fleet_server_host.kibana.hosts)
  description = "Where agents enroll"
}

output "packages" {
  value = {
    for package in [elasticstack_fleet_integration.fleet_server, elasticstack_fleet_integration.system] :
    package.name => package.version
  }
  description = "Installed integration packages: name => version"
}
