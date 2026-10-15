variable "nodes" {
  description = "VMs of this role, keyed by VM name (the hostname). Move the definitions from homelab-proxmox-workloads."
  type = map(object({
    vmid    = optional(number)
    ip_cidr = string
    cores   = number
    memory  = number # MB
    disk    = number # GB
  }))
}
