stack {
  name        = "apps-otel-demo"
  description = "OTel Astronomy Shop bootstrap (homelab only)"
  id          = "d5be2f7e-0076-5b45-8c0b-96a171d6cdd5"
  tags        = ["apps"]
  after       = ["/apps/k3s", "/workspaces/otel_demo"]
}
