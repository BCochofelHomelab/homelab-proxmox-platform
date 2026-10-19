stack {
  name        = "shared-data"
  description = "Retention: the ILM policy and the @custom component templates every logs, metrics and traces data stream uses"
  tags        = ["elastic", "shared"]
  after       = ["/stacks/platform/elastic"]
  id          = "e1302216-6f6d-473c-a72e-8747c5621e29"
}
