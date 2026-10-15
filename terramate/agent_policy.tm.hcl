# Every agent-policy stack gets the same generated code: one Fleet agent
# policy for the host group (policy id = folder name) and one integration
# policy per integration in agent-policy.yaml, each written to its owning
# workspace's namespace. Host owners edit the YAML, never HCL.
#
# Plain resources, not a module: the YAML is the interface; nothing here
# encodes a decision worth versioning separately (docs/STACKS.md).

generate_hcl "_terramate_agent_policy.tf" {
  condition = tm_contains(terramate.stack.tags, "agent-policy")

  content {
    locals {
      group  = terramate.stack.path.basename
      policy = yamldecode(file("${path.module}/agent-policy.yaml"))

      integrations = try(local.policy.integrations, {})
    }

    resource "elasticstack_fleet_agent_policy" "this" {
      policy_id       = local.group
      name            = try(local.policy.name, local.group)
      description     = try(local.policy.description, null)
      namespace       = local.policy.namespace
      monitor_logs    = try(local.policy.monitor_logs, true)
      monitor_metrics = try(local.policy.monitor_metrics, true)
      # Integrations are explicit (below), never the implicit system one.
      sys_monitoring = false
    }

    resource "elasticstack_fleet_integration_policy" "this" {
      for_each = local.integrations

      policy_id           = "${local.group}-${each.key}"
      name                = "${local.group}-${each.key}"
      agent_policy_id     = elasticstack_fleet_agent_policy.this.policy_id
      namespace           = each.value.namespace
      integration_name    = each.value.package
      integration_version = each.value.version
      description         = try(each.value.description, null)

      # Inputs and streams as in the package; vars are plain YAML maps,
      # turned into the JSON strings the provider expects.
      inputs = try({
        for input_id, input in each.value.inputs : input_id => {
          enabled = try(input.enabled, true)
          vars    = try(jsonencode(input.vars), null)
          streams = try({
            for stream_id, stream in input.streams : stream_id => {
              enabled = try(stream.enabled, true)
              vars    = try(jsonencode(stream.vars), null)
            }
          }, null)
        }
      }, null)
    }

    output "agent_policy_id" {
      description = "Fleet agent policy id (= the host group's folder name). Ansible enrolls hosts with it."
      value       = elasticstack_fleet_agent_policy.this.policy_id
    }
  }
}
