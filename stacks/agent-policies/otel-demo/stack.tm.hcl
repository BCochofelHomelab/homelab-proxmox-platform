stack {
  name        = "agent-policies-otel-demo"
  description = "Host group otel-demo: its Fleet agent policy and integrations (agent-policy.yaml)"
  tags        = ["elastic", "agent-policy", "fleet"]
  after       = ["/stacks/shared/fleet"]
  id          = "191638fe-9028-4c90-bed0-0fce26c7c796"
}
