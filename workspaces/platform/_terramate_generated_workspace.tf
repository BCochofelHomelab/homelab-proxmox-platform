# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

locals {
  file_rules = { for f in fileset("${path.module}/rules", "*.yaml") : trimsuffix(f, ".yaml") => merge(yamldecode(file("${path.module}/rules/${f}")), {
    params = jsonencode(yamldecode(file("${path.module}/rules/${f}")).params)
  }) }
  spec = yamldecode(file("${path.module}/workspace.yaml"))
}
module "workspace" {
  access = try(local.spec.access, {})
  alert_actions = [for a in try(local.spec.alert_actions, [
    ]) : merge(a, {
    params = jsonencode(a.params)
  })]
  baseline_content = try(local.spec.baseline_content, true)
  baseline_rules   = try(local.spec.baseline_rules, {})
  color            = try(local.spec.color, null)
  connectors = { for k, c in try(local.spec.connectors, {}) : k => merge(c, {
    config = try(jsonencode(c.config), null)
  }) }
  data_types = try(local.spec.data_types, [
    "logs",
    "metrics",
    "traces",
  ])
  default_data_type = try(local.spec.default_data_type, "logs")
  description       = try(local.spec.description, null)
  display_name      = local.spec.display_name
  initials          = try(local.spec.initials, null)
  read_from = try(local.spec.read_from, [
  ])
  rules = merge(local.file_rules, {
    unknown_namespace = {
      interval     = "5m"
      name         = "Data in a namespace with no workspace"
      params       = "{\"esQuery\":\"{\\\"query\\\":{\\\"bool\\\":{\\\"must_not\\\":[{\\\"terms\\\":{\\\"data_stream.namespace\\\":[\\\"core\\\",\\\"otel_demo\\\",\\\"platform\\\"]}},{\\\"prefix\\\":{\\\"data_stream.dataset\\\":\\\"fleet_server.\\\"}}]}}}\",\"excludeHitsFromPreviousRun\":true,\"index\":[\"logs-*\",\"metrics-*\",\"traces-*\"],\"searchType\":\"esQuery\",\"size\":10,\"threshold\":[0],\"thresholdComparator\":\"\\u003e\",\"timeField\":\"@timestamp\",\"timeWindowSize\":15,\"timeWindowUnit\":\"m\"}"
      rule_type_id = ".es-query"
      tags = [
        "contract",
      ]
    }
  })
  saved_objects = { for f in fileset("${path.module}/dashboards", "*.ndjson") : f => file("${path.module}/dashboards/${f}") }
  source        = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git?ref=1.0.0"
  workspace_id  = "platform"
}
