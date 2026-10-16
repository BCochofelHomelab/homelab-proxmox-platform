# Terramate project root. Every stack gets its backend and its providers
# generated from terramate/*.tm.hcl, by tag: "proxmox" (VMs) or "elastic"
# (Elastic content), exactly one per stack. Shared values reach a stack only
# through these globals and the generated files, so change detection sees
# them. Edit here or in terramate/, then `terramate generate`; never edit a
# _terramate_generated_*.tf file by hand.

terramate {
  required_version = "~> 0.17.0"

  config {
    git {
      default_branch = "main"
    }

    # `terramate run` refuses uncommitted or untracked files by default.
    # Plans are made on a branch while editing, before committing; the plan
    # is still reviewed before `tofu:apply`.
    disable_safeguards = ["git-uncommitted", "git-untracked"]

    # TFLint's terraform_comment_syntax wants `#`, not `//`, in .tf files.
    generate {
      hcl_magic_header_comment_style = "#"
    }
  }
}

import {
  source = "/terramate/*.tm.hcl"
}

# Non-secret inputs only. Secrets (TF_VAR_proxmox_api_token,
# TF_VAR_cipassword, ELASTICSEARCH_API_KEY, TF_TOKEN_app_terraform_io) come
# from ~/.secrets/homelab.yaml through the `mise run tofu:*` tasks.
globals {
  # HCP Terraform, state only (execution mode Local): one workspace per
  # stack, named after its path: platform/elastic -> platform-platform-elastic,
  # workspaces/otel_demo -> platform-workspaces-otel_demo.
  hcp_organization = "homelab-bcochofel-com"
  hcp_workspace    = "platform-${tm_replace(tm_trimprefix(terramate.stack.path.relative, "/"), "/", "-")}"

  # Provider versions, one place for every stack, keyed by stack tag: a
  # stack gets only its tag's providers. bpg/proxmox as in
  # homelab-proxmox-core's terraform/.terraform.lock.hcl.
  opentofu_version = "> 1.9.0, < 2.0"
  providers = {
    proxmox = {
      proxmox = {
        source  = "bpg/proxmox"
        version = "~> 0.111.1" # patch releases only: bpg iterates fast
      }
    }
    elastic = {
      elasticstack = {
        source  = "elastic/elasticstack"
        version = "~> 0.16.5"
      }
    }
  }

  proxmox = {
    endpoint = "https://192.168.68.20:8006/"
    insecure = true # self-signed certificate
    node     = "pve1"
    # homelab-proxmox-core's template (packer/ubuntu-26.04), cloned through
    # core's VM module at the tag in vm_module below.
    template = "ubuntu-26.04-core"
  }

  # homelab-proxmox-core's VM module, by tag (core's tags are X.Y.Z).
  vm_module = {
    source = "git::https://github.com/BCochofelHomelab/homelab-proxmox-core.git//terraform/modules/vm"
    ref    = "8.0.5"
  }

  # The workspace module. Each workspace pins its own ref in workspace.yaml
  # (to canary a new baseline on one workspace); this is the default.
  workspace_module = {
    source      = "git::https://github.com/BCochofelHomelab/terraform-elasticstack-workspace.git"
    default_ref = "1.0.0"
  }

  # The Elastic Stack the "elastic" stacks talk to, over TLS verified
  # against the internal CA (its certificate's path from the repo root).
  elastic = {
    version         = "9.5.4"
    es_endpoints    = ["https://192.168.68.30:9200", "https://192.168.68.31:9200", "https://192.168.68.32:9200"]
    kibana_endpoint = "https://192.168.68.33:5601"
    ca_cert         = "ansible/pki/elastic-ca.crt"
  }
}
