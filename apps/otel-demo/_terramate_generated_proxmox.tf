# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

provider "proxmox" {
  api_token = var.proxmox_api_token
  endpoint  = "https://192.168.68.20:8006/"
  insecure  = true
  ssh {
    agent    = true
    username = "root"
  }
}
data "proxmox_virtual_environment_vms" "template" {
  node_name = "pve1"
  filter {
    name = "name"
    values = [
      "ubuntu-26.04-core",
    ]
  }
}
locals {
  target_node   = "pve1"
  template_vmid = one(data.proxmox_virtual_environment_vms.template.vms).vm_id
}
