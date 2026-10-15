# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  ws = yamldecode(file("${path.module}/workspace.yaml"))
}
module "workspace" {
  access              = try(local.ws.access, null)
  alerting            = try(local.ws.alerting, null)
  color               = try(local.ws.color, null)
  data_types          = try(local.ws.data_types, null)
  description         = try(local.ws.description, null)
  disabled_features   = try(local.ws.disabled_features, null)
  display_name        = try(local.ws.display_name, null)
  extra_saved_objects = { for f in fileset("${path.module}/dashboards", "*.ndjson") : trimsuffix(f, ".ndjson") => file("${path.module}/dashboards/${f}") }
  owner               = local.ws.owner
  read_from           = try(local.ws.read_from, null)
  rules               = { for f in fileset("${path.module}/rules", "*.yaml") : trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/rules/${f}")) }
  solution            = try(local.ws.solution, null)
  source              = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git?ref=v1.0.0"
  workspace           = "otel_demo"
}
output "space_id" {
  description = "The workspace's Kibana space."
  value       = module.workspace.space_id
}
output "role_names" {
  description = "The workspace's roles, per access level."
  value       = module.workspace.role_names
}
