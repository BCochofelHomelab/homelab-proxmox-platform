# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  inputs = { for i in local.spec.integrations : i.name => { for id, input in try(i.inputs, {}) : id => {
    enabled = try(input.enabled, true)
    vars    = try(input.vars, null) == null ? null : format("{%s}", join(",", [for k, v in input.vars : format("%s:%s", jsonencode(k), can(v.secret) ? jsonencode(data.sops_file.secrets.data[v.secret]) : jsonencode(v))]))
    streams = length(try(input.streams, {})) == 0 ? null : { for sid, stream in input.streams : sid => {
      enabled = try(stream.enabled, true)
    } }
  } } }
  policy_id = "core-runner"
  spec      = yamldecode(file("${path.module}/agent-policy.yaml"))
}
data "sops_file" "secrets" {
  source_file = "${path.module}/../../ansible/inventory/group_vars/elastic.sops.yaml"
}
resource "elasticstack_fleet_agent_policy" "this" {
  description     = "${local.spec.description} (homelab-proxmox-platform, agent-policies/core-runner)"
  monitor_logs    = true
  monitor_metrics = true
  name            = local.spec.name
  namespace       = local.spec.namespace
  policy_id       = local.policy_id
}
resource "elasticstack_fleet_integration_policy" "this" {
  agent_policy_id     = elasticstack_fleet_agent_policy.this.policy_id
  description         = try(each.value.description, null)
  for_each            = { for i in local.spec.integrations : i.name => i }
  inputs              = length(local.inputs[each.key]) > 0 ? local.inputs[each.key] : null
  integration_name    = each.value.package
  integration_version = local.fleet_packages[each.value.package]
  name                = "${each.key}-${local.policy_id}"
  namespace           = each.value.namespace
}
