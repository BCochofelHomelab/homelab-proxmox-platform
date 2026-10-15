stack {
  name        = "agent-policy-proxmox_vms"
  description = "Elastic Agent on every Proxmox VM"
  id          = "10ad4384-51c9-5cc2-baf5-2322e9ef87f7"
  tags        = ["agent-policy", "elasticstack"]
  after       = ["tag:shared"]
}
