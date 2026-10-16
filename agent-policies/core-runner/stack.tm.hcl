stack {
  name        = "agent-policies-core-runner"
  description = "Host group core-runner: its Fleet agent policy and integrations (agent-policy.yaml)"
  tags        = ["elastic", "agent-policy", "fleet"]
  after       = ["/shared/fleet"]
  id          = "2a6324d6-9d52-4200-a784-2bdfdf5de856"
}
