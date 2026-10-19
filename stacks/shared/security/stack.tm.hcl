stack {
  name        = "shared-security"
  description = "Platform roles: who administers and who views the whole platform"
  tags        = ["elastic", "shared"]
  after       = ["/stacks/platform/elastic"]
  id          = "e13139b2-141e-45d8-82f4-b1cd28ddfdda"
}
