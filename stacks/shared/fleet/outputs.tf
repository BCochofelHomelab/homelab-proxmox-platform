output "fleet_server_policy_id" {
  value       = elasticstack_fleet_agent_policy.fleet_server.policy_id
  description = "Fleet Server's agent policy (ansible/inventory/group_vars/fleet_server.yml)"
}

output "fleet_server_host" {
  value       = one(elasticstack_fleet_server_host.kibana.hosts)
  description = "Where agents enroll"
}

output "outputs" {
  value = {
    default       = elasticstack_fleet_output.logstash.output_id
    elasticsearch = elasticstack_fleet_output.elasticsearch.output_id
  }
  description = "Fleet outputs: the default (Logstash) and Elasticsearch (Fleet Server's)"
}

output "packages" {
  value = {
    for name, package in elasticstack_fleet_integration.packages : name => package.version
  }
  description = "Installed integration packages: name => version"
}
