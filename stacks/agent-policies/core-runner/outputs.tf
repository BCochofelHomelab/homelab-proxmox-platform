output "policy_id" {
  value       = elasticstack_fleet_agent_policy.this.policy_id
  description = "The agent policy's id (elastic_agent_policy_id in Ansible's group_vars)"
}
