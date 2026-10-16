# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

output "vms" {
  description = "The stack's VMs: name => VMID and IP"
  value = { for name, vm in module.vm : name => {
    vmid = vm.vmid
    ip   = vm.ip
  } }
}
