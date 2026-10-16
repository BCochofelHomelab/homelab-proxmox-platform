# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

module "vm" {
  cipassword  = var.cipassword
  ciuser      = "ubuntu"
  cores       = each.value.cores
  description = "Managed by OpenTofu (homelab-proxmox-platform, apps/otel-demo)"
  disk        = each.value.disk
  for_each    = local.vms
  gateway     = "192.168.68.1"
  ip_cidr     = "${each.value.ip}/22"
  memory      = each.value.memory
  name        = each.key
  nameserver = [
    "192.168.68.2",
    "192.168.68.5",
  ]
  network_bridge = "vmbr0"
  searchdomain   = "homelab.bcochofel.com"
  source         = "git::https://github.com/BCochofelHomelab/homelab-proxmox-core.git//terraform/modules/vm?ref=8.0.5"
  sshkeys        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZGQwHOs8V9ndmLn3NuQXxuD0Ht4zaz+c6/WaEMAA6S bcochofel@NUC12WSHi7"
  tags = concat([
    "platform",
    "terraform",
  ], each.value.groups)
  target_node   = local.target_node
  template_vmid = local.template_vmid
}
