locals {
  fleet = yamldecode(file("${path.module}/fleet.yaml"))
}

resource "elasticstack_fleet_integration" "this" {
  for_each = try(local.fleet.integrations, {})

  name    = each.key
  version = each.value
  # Never uninstall a package on destroy: data streams depend on it.
  skip_destroy = true
}

resource "elasticstack_fleet_output" "this" {
  for_each = try(local.fleet.outputs, {}) == null ? {} : try(local.fleet.outputs, {})

  output_id            = each.key
  name                 = each.value.name
  type                 = each.value.type
  hosts                = each.value.hosts
  default_integrations = try(each.value.default_integrations, false)
  default_monitoring   = try(each.value.default_monitoring, false)
}

resource "elasticstack_fleet_server_host" "this" {
  for_each = try(local.fleet.fleet_server_hosts, {}) == null ? {} : try(local.fleet.fleet_server_hosts, {})

  host_id = each.key
  name    = each.value.name
  hosts   = each.value.hosts
  default = try(each.value.default, false)
}
