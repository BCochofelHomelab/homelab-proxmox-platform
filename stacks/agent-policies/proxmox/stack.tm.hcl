stack {
  name        = "agent-policies-proxmox"
  description = "Host group proxmox: its Fleet agent policy and integrations (agent-policy.yaml)"
  tags        = ["elastic", "agent-policy", "fleet"]
  after       = ["/stacks/shared/fleet"]
  id          = "5e1e693c-4e24-4d73-8a13-775ee048a7bb"
  # A file outside this folder that it reads ({secret: ...} values): a
  # change to it marks this stack changed (mise run tofu:plan).
  watch = [
    "/ansible/inventory/group_vars/elastic.sops.yaml",
  ]
}
