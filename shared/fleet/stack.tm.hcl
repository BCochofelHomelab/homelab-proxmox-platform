stack {
  name        = "shared-fleet"
  description = "Fleet outputs, Fleet Server hosts, integration packages"
  id          = "4aaf07cf-75ad-5e36-aa51-15f8e0b04b1f"
  tags        = ["shared", "elasticstack"]
  after       = ["tag:platform"]
}
