output "vm_ids" {
  description = "Proxmox VM ids, keyed by VM name."
  value       = { for k, m in module.vm : k => m.vm_id }
}
