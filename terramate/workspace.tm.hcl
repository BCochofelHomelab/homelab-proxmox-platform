# Every workspace stack gets the same generated code: read workspace.yaml,
# call the workspace module, add the folder's dashboards and rules. The
# workspace id is the folder name. Owners edit data (workspace.yaml,
# dashboards/*.ndjson, rules/*.yaml), never HCL.
#
# The module ref is read from workspace.yaml at generate time (a module
# source must be a literal): change module_ref, run `terramate generate`.

generate_hcl "_terramate_workspace.tf" {
  condition = tm_contains(terramate.stack.tags, "workspace")

  # Evaluated for every stack, before the condition: tm_try covers stacks
  # without a workspace.yaml.
  lets {
    module_ref = tm_try(
      tm_yamldecode(tm_file("${terramate.root.path.fs.absolute}${terramate.stack.path.absolute}/workspace.yaml")).module_ref,
      global.workspace_module_ref,
    )
  }

  content {
    locals {
      ws = yamldecode(file("${path.module}/workspace.yaml"))
    }

    module "workspace" {
      source = "${global.workspace_module}?ref=${let.module_ref}"

      workspace = terramate.stack.path.basename
      owner     = local.ws.owner

      # null falls back to the module's defaults (nullable = false inputs).
      display_name      = try(local.ws.display_name, null)
      description       = try(local.ws.description, null)
      color             = try(local.ws.color, null)
      solution          = try(local.ws.solution, null)
      disabled_features = try(local.ws.disabled_features, null)
      data_types        = try(local.ws.data_types, null)
      access            = try(local.ws.access, null)
      read_from         = try(local.ws.read_from, null)
      alerting          = try(local.ws.alerting, null)

      rules = {
        for f in fileset("${path.module}/rules", "*.yaml") :
        trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/rules/${f}"))
      }

      extra_saved_objects = {
        for f in fileset("${path.module}/dashboards", "*.ndjson") :
        trimsuffix(f, ".ndjson") => file("${path.module}/dashboards/${f}")
      }
    }

    output "space_id" {
      description = "The workspace's Kibana space."
      value       = module.workspace.space_id
    }

    output "role_names" {
      description = "The workspace's roles, per access level."
      value       = module.workspace.role_names
    }
  }
}
