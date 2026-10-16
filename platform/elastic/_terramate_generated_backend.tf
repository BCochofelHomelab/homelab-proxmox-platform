# TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  required_version = "> 1.9.0, < 2.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111.1"
    }
  }
  cloud {
    hostname     = "app.terraform.io"
    organization = "homelab-bcochofel-com"
    workspaces {
      name = "platform-platform-elastic"
    }
  }
}
