# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.85"
    }
  }
}
provider "proxmox" {
  api_token = var.proxmox_api_token
  endpoint  = "https://192.168.68.20:8006/"
  insecure  = var.proxmox_insecure
  ssh {
    agent    = true
    username = "root"
  }
}
variable "proxmox_api_token" {
  description = "Proxmox API token, form user@realm!tokenid=secret (TF_VAR_proxmox_api_token)"
  sensitive   = true
  type        = string
}
variable "proxmox_insecure" {
  default     = true
  description = "Skip TLS verification (homelab self-signed cert)"
  type        = bool
}
variable "cipassword" {
  description = "cloud-init user password (TF_VAR_cipassword)"
  sensitive   = true
  type        = string
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
  proxmox = {
    ciuser   = "ubuntu"
    endpoint = "https://192.168.68.20:8006/"
    gateway  = "192.168.68.1"
    nameserver = [
      "192.168.68.2",
      "192.168.68.5",
    ]
    network_bridge = "vmbr0"
    searchdomain   = "homelab.bcochofel.com"
    sshkeys        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZGQwHOs8V9ndmLn3NuQXxuD0Ht4zaz+c6/WaEMAA6S bcochofel@NUC12WSHi7"
    target_node    = "pve1"
    vm_template    = "ubuntu-26.04-core"
  }
  template_vmid = one(data.proxmox_virtual_environment_vms.template.vms).vm_id
}
