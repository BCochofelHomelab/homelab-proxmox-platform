# Generated into every stack tagged "workspace" (workspaces/<id>/): the call
# to terraform-elasticstack-workspace, from the workspace's folder. The
# folder holds data; this is the code, the same for every workspace.
# Imported by terramate.tm.hcl.
#
#   workspace.yaml     the module's inputs (below); module_ref pins the
#                      module's release for this workspace (default:
#                      global.workspace_module.default_ref), so a new
#                      baseline can be tried on one workspace first
#   dashboards/*.ndjson  Kibana exports from the workspace's space
#   rules/*.yaml       one rule each, keyed by file name (the module's
#                      `rules` entry; `params` as YAML)
#
# The workspace id is the folder's name: the Kibana space id and the data
# stream namespace (scripts/check_contract.py checks it).

generate_hcl "_terramate_generated_workspace.tf" {
  condition = tm_contains(terramate.stack.tags, "workspace")

  lets {
    # Read at generate time for module_ref only: a module source can't be an
    # expression. Every other input is read by OpenTofu (locals below). The
    # file only exists in workspace stacks; lets are evaluated in every one.
    spec = tm_try(tm_yamldecode(tm_file("${terramate.root.path.fs.absolute}${terramate.stack.path.absolute}/workspace.yaml")), {})
    ref  = tm_try(let.spec.module_ref, global.workspace_module.default_ref)

    # Every workspace, for the platform workspace's rule below.
    workspace_ids = [for p in terramate.stacks.list : tm_basename(p) if tm_startswith(p, "/workspaces/")]

    # The contract's third check, in the platform workspace only: data
    # arriving in a namespace that no workspace owns (a typo in an
    # integration policy, an app that sets none and lands in "default").
    # Fleet Server's own status data streams are always in "default".
    platform_rules = terramate.stack.path.basename != "platform" ? {} : {
      unknown_namespace = {
        name         = "Data in a namespace with no workspace"
        rule_type_id = ".es-query"
        interval     = "5m"
        tags         = ["contract"]
        params = tm_jsonencode({
          searchType = "esQuery"
          index      = ["logs-*", "metrics-*", "traces-*"]
          timeField  = "@timestamp"
          esQuery = tm_jsonencode({
            query = {
              bool = {
                must_not = [
                  { terms = { "data_stream.namespace" = let.workspace_ids } },
                  { prefix = { "data_stream.dataset" = "fleet_server." } },
                ]
              }
            }
          })
          size                       = 10
          threshold                  = [0]
          thresholdComparator        = ">"
          timeWindowSize             = 15
          timeWindowUnit             = "m"
          excludeHitsFromPreviousRun = true
        })
      }
    }
  }

  content {
    locals {
      spec = yamldecode(file("${path.module}/workspace.yaml"))

      # rules/<key>.yaml -> the module's rules[<key>], params as JSON.
      file_rules = {
        for f in fileset("${path.module}/rules", "*.yaml") :
        trimsuffix(f, ".yaml") => merge(
          yamldecode(file("${path.module}/rules/${f}")),
          { params = jsonencode(yamldecode(file("${path.module}/rules/${f}")).params) },
        )
      }
    }

    module "workspace" {
      source = "${global.workspace_module.source}?ref=${let.ref}"

      workspace_id = terramate.stack.path.basename
      display_name = local.spec.display_name
      description  = try(local.spec.description, null)
      color        = try(local.spec.color, null)
      initials     = try(local.spec.initials, null)

      data_types        = try(local.spec.data_types, ["logs", "metrics", "traces"])
      default_data_type = try(local.spec.default_data_type, "logs")
      read_from         = try(local.spec.read_from, [])
      access            = try(local.spec.access, {})

      baseline_content = try(local.spec.baseline_content, true)
      saved_objects = {
        for f in fileset("${path.module}/dashboards", "*.ndjson") : f => file("${path.module}/dashboards/${f}")
      }

      # connectors[*].config and alert_actions[*].params are YAML objects in
      # workspace.yaml, JSON for the module.
      connectors = {
        for k, c in try(local.spec.connectors, {}) :
        k => merge(c, { config = try(jsonencode(c.config), null) })
      }
      alert_actions = [
        for a in try(local.spec.alert_actions, []) :
        merge(a, { params = jsonencode(a.params) })
      ]
      baseline_rules = try(local.spec.baseline_rules, {})
      rules          = merge(local.file_rules, let.platform_rules)
    }
  }
}
