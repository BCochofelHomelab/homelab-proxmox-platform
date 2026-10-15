# Fleet Server VM (Elastic Agent in Fleet Server mode).
# VMs only: Ansible configures them (ansible/, group `fleet_server` from the
# Proxmox tag below), and their Elastic-side configuration lives in shared/.

module "vm" {
  source   = "git::https://github.com/BCochofelHomelab/homelab-proxmox-core.git//terraform/modules/vm?ref=8.0.3"
  for_each = var.nodes

  name          = each.key
  vmid          = each.value.vmid
  target_node   = local.proxmox.target_node
  template_vmid = local.template_vmid

  cores  = each.value.cores
  memory = each.value.memory
  disk   = each.value.disk

  ip_cidr        = each.value.ip_cidr
  gateway        = local.proxmox.gateway
  network_bridge = local.proxmox.network_bridge
  nameserver     = local.proxmox.nameserver
  searchdomain   = local.proxmox.searchdomain

  ciuser     = local.proxmox.ciuser
  cipassword = var.cipassword
  sshkeys    = local.proxmox.sshkeys

  # Ansible's dynamic inventory groups hosts by these tags.
  tags = ["terraform", "platform", "fleet_server"]
}
