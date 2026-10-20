stack {
  name        = "agent-policies-core"
  description = "Host group core: its Fleet agent policy and integrations (agent-policy.yaml)"
  tags        = ["elastic", "agent-policy", "fleet"]
  after       = ["/stacks/shared/fleet"]
  id          = "32a490a9-a6d7-4cd3-b107-eeef16cef163"
  # A file outside this folder that it reads ({secret: ...} values): a
  # change to it marks this stack changed (mise run tofu:plan).
  watch = [
    "/ansible/inventory/group_vars/elastic.sops.yaml",
  ]
}
