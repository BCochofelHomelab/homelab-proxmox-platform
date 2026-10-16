# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  policy_id = "otel-demo"
  spec      = yamldecode(file("${path.module}/agent-policy.yaml"))
}
resource "elasticstack_fleet_agent_policy" "this" {
  description     = "${local.spec.description} (homelab-proxmox-platform, agent-policies/otel-demo)"
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
  integration_name    = each.value.package
  integration_version = local.fleet_packages[each.value.package]
  name                = "${each.key}-${local.policy_id}"
  namespace           = each.value.namespace
}
