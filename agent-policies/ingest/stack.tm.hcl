stack {
  name        = "agent-policies-ingest"
  description = "Host group ingest: its Fleet agent policy and integrations (agent-policy.yaml)"
  tags        = ["elastic", "agent-policy", "fleet"]
  after       = ["/shared/fleet"]
  id          = "3d937125-4f8c-46d0-8968-d46ba9892ce0"
}
