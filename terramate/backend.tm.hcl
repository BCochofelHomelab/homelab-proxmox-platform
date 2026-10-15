# Every stack: the OpenTofu version floor and its own HCP Terraform
# workspace. `hostname` is required by OpenTofu, which has no default for
# the cloud block.
generate_hcl "_terramate_backend.tf" {
  content {
    terraform {
      required_version = ">= 1.8.0"

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
