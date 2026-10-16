stack {
  name        = "workspaces-core"
  description = "Workspace core: its space, data views, roles, content and alerts (workspace.yaml)"
  tags        = ["elastic", "workspace"]
  after       = ["tag:shared"]
  id          = "0b171d6e-db32-4d45-beb9-deb35687766e"
}
