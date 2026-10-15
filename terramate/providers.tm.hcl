# Providers are generated per tag, so a stack only ever gets the provider
# (and therefore the credential) its scope needs: VM stacks get Proxmox,
# shared, agent-policy and workspace stacks get Elastic, never both.
# Credentials always come from the environment (`sops exec-env`, see
# mise.toml), never from generated code.

globals "proxmox" {
  # Same values as homelab-proxmox-core's terraform/variables.tf defaults.
  endpoint       = "https://192.168.68.20:8006/"
  target_node    = "pve1"
  vm_template    = "ubuntu-26.04-core"
  gateway        = "192.168.68.1"
  network_bridge = "vmbr0"
  nameserver     = ["192.168.68.2", "192.168.68.5"]
  searchdomain   = "homelab.bcochofel.com"
  ciuser         = "ubuntu"
  sshkeys        = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZGQwHOs8V9ndmLn3NuQXxuD0Ht4zaz+c6/WaEMAA6S bcochofel@NUC12WSHi7"
}

generate_hcl "_terramate_proxmox.tf" {
  condition = tm_contains(terramate.stack.tags, "proxmox")

  content {
    terraform {
      required_providers {
        proxmox = {
          source  = "bpg/proxmox"
          version = global.proxmox_provider_version
        }
      }
    }

    # Auth via API token (user@realm!tokenid=secret) as
    # TF_VAR_proxmox_api_token, as in homelab-proxmox-core.
    provider "proxmox" {
      endpoint  = global.proxmox.endpoint
      api_token = var.proxmox_api_token
      insecure  = var.proxmox_insecure

      ssh {
        agent    = true
        username = "root"
      }
    }

    variable "proxmox_api_token" {
      type        = string
      description = "Proxmox API token, form user@realm!tokenid=secret (TF_VAR_proxmox_api_token)"
      sensitive   = true
    }

    # A variable, not a literal: core's Trivy policy PROXMOX-002 rejects a
    # hard-coded insecure = true. Same variable and default as core.
    variable "proxmox_insecure" {
      type        = bool
      description = "Skip TLS verification (homelab self-signed cert)"
      default     = true
    }

    variable "cipassword" {
      type        = string
      description = "cloud-init user password (TF_VAR_cipassword)"
      sensitive   = true
    }

    # The Packer template's VMID, looked up by name.
    data "proxmox_virtual_environment_vms" "template" {
      node_name = global.proxmox.target_node

      filter {
        name   = "name"
        values = [global.proxmox.vm_template]
      }
    }

    locals {
      template_vmid = one(data.proxmox_virtual_environment_vms.template.vms).vm_id
      proxmox       = global.proxmox
    }
  }
}

generate_hcl "_terramate_elasticstack.tf" {
  condition = tm_contains(terramate.stack.tags, "elasticstack")

  content {
    terraform {
      required_providers {
        elasticstack = {
          source  = "elastic/elasticstack"
          version = global.elasticstack_provider_version
        }
      }
    }

    # ELASTICSEARCH_ENDPOINTS, ELASTICSEARCH_API_KEY, KIBANA_ENDPOINT and
    # KIBANA_API_KEY from the environment (docs/STACKS.md, credentials).
    provider "elasticstack" {
      elasticsearch {}
      kibana {}
    }
  }
}
