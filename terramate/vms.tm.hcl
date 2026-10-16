# Generated into every "proxmox" stack: its VMs, through
# homelab-proxmox-core's VM module at global.vm_module.ref, and their
# outputs. A VM stack holds only `local.vms` (main.tf). Imported by
# terramate.tm.hcl.
#
# Every VM is tagged "platform" (the Ansible inventory keeps only those),
# "terraform", and its Ansible groups: community.proxmox's inventory turns
# each tag into a group of the same name (ansible/inventory/).

generate_hcl "_terramate_generated_vms.tf" {
  condition = tm_contains(terramate.stack.tags, "proxmox")

  content {
    module "vm" {
      source   = "${global.vm_module.source}?ref=${global.vm_module.ref}"
      for_each = local.vms

      name          = each.key
      target_node   = local.target_node
      template_vmid = local.template_vmid
      description   = "Managed by OpenTofu (homelab-proxmox-platform, ${terramate.stack.path.relative})"
      tags          = concat(["platform", "terraform"], each.value.groups)

      cores  = each.value.cores
      memory = each.value.memory
      disk   = each.value.disk

      # Optional second disk (scsi1), created empty; null for none.
      data_disk = each.value.data_disk

      ip_cidr        = "${each.value.ip}/${global.network.prefix}"
      gateway        = global.network.gateway
      network_bridge = global.network.bridge
      nameserver     = global.network.nameservers
      searchdomain   = global.network.searchdomain

      ciuser     = global.ciuser
      cipassword = var.cipassword
      sshkeys    = tm_join("\n", global.sshkeys)
    }
  }
}

generate_hcl "outputs.tf" {
  condition = tm_contains(terramate.stack.tags, "proxmox")

  content {
    output "vms" {
      description = "The stack's VMs: name => VMID and IP"
      value       = { for name, vm in module.vm : name => { vmid = vm.vmid, ip = vm.ip } }
    }
  }
}
