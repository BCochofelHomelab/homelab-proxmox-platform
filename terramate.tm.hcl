# Terramate root. Every folder with a stack.tm.hcl is a stack: its own
# state (one HCP Terraform workspace), plan and credentials. What is and
# isn't a stack: docs/STACKS.md.
terramate {
  required_version = ">= 0.17.3"

  config {
    git {
      default_branch = "main"
    }

    # `#` comments in generated files, as tflint's
    # terraform_comment_syntax rule expects.
    generate {
      hcl_magic_header_comment_style = "#"
    }
  }
}

# Code generation (backend, providers, the workspace and agent-policy
# calls) lives in terramate/ and applies by stack tag.
import {
  source = "/terramate/*.tm.hcl"
}

globals {
  # HCP Terraform: state only (execution mode Local), one workspace per
  # stack, named platform-<stack path>, e.g. platform-workspaces-otel_demo.
  hcp_organization = "homelab-bcochofel-com"
  hcp_workspace    = "platform-${tm_replace(tm_trimprefix(terramate.stack.path.relative, "/"), "/", "-")}"

  # Root configurations pin providers (and commit .terraform.lock.hcl).
  proxmox_provider_version      = "~> 0.85" # same as homelab-proxmox-core
  elasticstack_provider_version = "~> 0.16.6"

  # Modules, consumed by exact tag (Git sources aren't in the lock file).
  core_vm_module   = "git::https://github.com/BCochofelHomelab/homelab-proxmox-core.git//terraform/modules/vm?ref=8.0.3"
  workspace_module = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git"
  # Default module version for every workspace; a workspace.yaml can pin
  # its own (module_ref) to canary a new baseline.
  workspace_module_ref = "v1.0.0"
}
