# Generated into every stack tagged "agent-policy" (stacks/agent-policies/<group>/):
# one host group's Fleet agent policy and its integrations, from the
# group's agent-policy.yaml. The folder holds data; this is the code, the
# same for every group. Imported by terramate.tm.hcl.
#
# agent-policy.yaml:
#   name:        the policy's name in Fleet
#   description: what the hosts are
#   namespace:   the workspace the agents' own logs and metrics belong to
#   integrations:
#     - name:      unique within the group ([a-z0-9-])
#       package:   a key of global.fleet_packages (installed by stacks/shared/fleet)
#       namespace: the workspace this integration's data belongs to
#       description: optional
#       inputs:    optional, by input id (<policy template>-<input type>,
#                  the package's manifest): only what differs from the
#                  package's defaults
#         <input id>:
#           enabled: true (default)
#           vars:    the input's variables; `{secret: <key>}` is read from
#                    ansible/inventory/group_vars/elastic.sops.yaml
#           streams: by data stream (<package>.<dataset>):
#             <stream>: {enabled: true}
#
# The policy id is the folder's name; Ansible enrolls each VM into its
# group's (elastic_agent_policy_id, group_vars). Every namespace must name a
# workspace (scripts/check_contract.py).

generate_hcl "_terramate_generated_agent_policy.tf" {
  condition = tm_contains(terramate.stack.tags, "agent-policy")

  content {
    locals {
      policy_id = terramate.stack.path.basename
      spec      = yamldecode(file("${path.module}/agent-policy.yaml"))

      # A variables map as the JSON the provider wants, with every
      # `{secret: <key>}` replaced by that key's value. Built as text: a
      # value's type differs from one variable to the next.
      inputs = {
        for i in local.spec.integrations : i.name => {
          for id, input in try(i.inputs, {}) : id => {
            enabled = try(input.enabled, true)
            vars = try(input.vars, null) == null ? null : format("{%s}", join(",", [
              for k, v in input.vars : format("%s:%s", jsonencode(k),
              can(v.secret) ? jsonencode(data.sops_file.secrets.data[v.secret]) : jsonencode(v))
            ]))
            # null, not {}: no streams listed means the package's defaults.
            streams = length(try(input.streams, {})) == 0 ? null : {
              for sid, stream in input.streams : sid => {
                enabled = try(stream.enabled, true)
              }
            }
          }
        }
      }
    }

    # Read only for `{secret: ...}` values (stacks/agent-policies/agent-policies.tm.hcl).
    data "sops_file" "secrets" {
      source_file = "${path.module}/${terramate.stack.path.to_root}/ansible/inventory/group_vars/elastic.sops.yaml"
    }

    resource "elasticstack_fleet_agent_policy" "this" {
      policy_id       = local.policy_id
      name            = local.spec.name
      namespace       = local.spec.namespace
      description     = "${local.spec.description} (homelab-proxmox-platform, ${global.stack_path})"
      monitor_logs    = true
      monitor_metrics = true
    }

    # Integration policy names are unique across Fleet: suffixed with the
    # policy id.
    resource "elasticstack_fleet_integration_policy" "this" {
      for_each = { for i in local.spec.integrations : i.name => i }

      name                = "${each.key}-${local.policy_id}"
      namespace           = each.value.namespace
      description         = try(each.value.description, null)
      agent_policy_id     = elasticstack_fleet_agent_policy.this.policy_id
      integration_name    = each.value.package
      integration_version = local.fleet_packages[each.value.package]
      inputs              = length(local.inputs[each.key]) > 0 ? local.inputs[each.key] : null
    }
  }
}
