stack {
  name        = "agent-policies-elasticsearch"
  description = "Host group elasticsearch: its Fleet agent policy and integrations (agent-policy.yaml)"
  tags        = ["elastic", "agent-policy", "fleet"]
  after       = ["/shared/fleet"]
  id          = "f18d3e47-5761-4516-b8f6-f707d643bb97"
}
