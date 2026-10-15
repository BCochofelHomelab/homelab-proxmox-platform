stack {
  name        = "shared-data"
  description = "ILM, component and index templates, ingest pipelines (incl. @custom reroute)"
  id          = "210f7351-0a96-5746-8224-fd0673da6e51"
  tags        = ["shared", "elasticstack"]
  after       = ["tag:platform"]
}
