# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  group        = "proxmox_vms"
  integrations = try(local.policy.integrations, {})
  policy       = yamldecode(file("${path.module}/agent-policy.yaml"))
}
resource "elasticstack_fleet_agent_policy" "this" {
  description     = try(local.policy.description, null)
  monitor_logs    = try(local.policy.monitor_logs, true)
  monitor_metrics = try(local.policy.monitor_metrics, true)
  name            = try(local.policy.name, local.group)
  namespace       = local.policy.namespace
  policy_id       = local.group
  sys_monitoring  = false
}
resource "elasticstack_fleet_integration_policy" "this" {
  agent_policy_id = elasticstack_fleet_agent_policy.this.policy_id
  description     = try(each.value.description, null)
  for_each        = local.integrations
  inputs = try({ for input_id, input in each.value.inputs : input_id => {
    enabled = try(input.enabled, true)
    vars    = try(jsonencode(input.vars), null)
    streams = try({ for stream_id, stream in input.streams : stream_id => {
      enabled = try(stream.enabled, true)
      vars    = try(jsonencode(stream.vars), null)
    } }, null)
  } }, null)
  integration_name    = each.value.package
  integration_version = each.value.version
  name                = "${local.group}-${each.key}"
  namespace           = each.value.namespace
  policy_id           = "${local.group}-${each.key}"
}
output "agent_policy_id" {
  description = "Fleet agent policy id (= the host group's folder name). Ansible enrolls hosts with it."
  value       = elasticstack_fleet_agent_policy.this.policy_id
}
