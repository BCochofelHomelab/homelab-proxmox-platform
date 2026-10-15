stack {
  name        = "workspace-platform"
  description = "Workspace: the platform's own telemetry"
  id          = "a1753b8d-76cb-563f-aa88-c16034b725ab"
  tags        = ["workspace", "elasticstack"]
  after       = ["tag:shared"]
}
