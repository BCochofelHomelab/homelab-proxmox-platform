# Generated into every stack: OpenTofu's version, the stack's one provider
# (by tag) and its HCP Terraform workspace. Imported by terramate.tm.hcl.

# Every stack is "proxmox" or "elastic", never both and never neither: VM
# stacks never get Elastic credentials, and Elastic stacks never get Proxmox
# ones.
assert {
  assertion = tm_length(tm_setintersection(terramate.stack.tags, ["proxmox", "elastic"])) == 1
  message   = "${terramate.stack.path.absolute}: tag the stack \"proxmox\" or \"elastic\", exactly one of them"
}

generate_hcl "_terramate_generated_backend.tf" {
  content {
    terraform {
      required_version = global.opentofu_version

      tm_dynamic "required_providers" {
        attributes = tm_contains(terramate.stack.tags, "proxmox") ? global.providers.proxmox : global.providers.elastic
      }

      # OpenTofu has no default hostname for the cloud backend.
      cloud {
        hostname     = "app.terraform.io"
        organization = global.hcp_organization

        workspaces {
          name = global.hcp_workspace
        }
      }
    }
  }
}
