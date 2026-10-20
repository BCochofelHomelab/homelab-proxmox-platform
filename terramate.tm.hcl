# Terramate project root: the project settings and the globals. The code
# generators live next to what they generate, and Terramate applies each
# .tm.hcl file to the stacks in its directory and below:
#   stacks/*.tm.hcl                       every stack: backend, providers (by
#                                         tag: "proxmox" or "elastic", exactly
#                                         one), VM module call, Fleet packages
#   stacks/agent-policies/*.tm.hcl        the host groups' agent policies
#   stacks/workspaces/workspace.tm.hcl    the workspaces' module call
# Shared values reach a stack only through these globals and the generated
# files, so change detection sees them. Edit a generator or a global, then
# `terramate generate`; never edit a _terramate_generated_*.tf file by hand.

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

# Non-secret inputs only. Secrets (TF_VAR_proxmox_api_token,
# TF_VAR_cipassword, ELASTICSEARCH_API_KEY, TF_TOKEN_app_terraform_io) come
# from ~/.secrets/homelab.yaml through the `mise run tofu:*` tasks.
globals {
  # The stack's path under stacks/: stacks/shared/fleet -> shared/fleet.
  # Names and descriptions use it, so they read (and stayed) the same as
  # before the stacks moved into stacks/: HCP workspaces, VM and agent
  # policy descriptions.
  stack_path = tm_trimprefix(tm_trimprefix(terramate.stack.path.relative, "/"), "stacks/")

  # HCP Terraform, state only (execution mode Local): one workspace per
  # stack, named after its path: stacks/platform/elastic -> platform-platform-elastic,
  # stacks/workspaces/otel_demo -> platform-workspaces-otel_demo.
  hcp_organization = "homelab-bcochofel-com"
  hcp_workspace    = "platform-${tm_replace(global.stack_path, "/", "-")}"

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

  # Providers a single stack adds to its tag's (stacks/shared/fleet: sops, for the
  # agents' client key), set in that stack's stack.tm.hcl.
  extra_providers = {}

  # Fleet integration packages, one version each for the whole platform:
  # stacks/shared/fleet installs them, every agent policy's integrations use them
  # (stacks/fleet.tm.hcl). Bumping one changes every stack that uses it,
  # which is the change's scope. Versions compatible with Kibana 9.5.4 (the
  # package registry, kibana.version=9.5.4).
  fleet_packages = {
    fleet_server  = "1.6.1"
    system        = "3.0.0"
    elasticsearch = "1.23.3"
    kibana        = "2.9.0"
    logstash      = "2.11.3"
    docker        = "2.16.0"
  }

  proxmox = {
    endpoint = "https://192.168.68.20:8006/"
    insecure = true # self-signed certificate
    node     = "pve1"
    # homelab-proxmox-core's template (packer/ubuntu-26.04), cloned through
    # core's VM module at the tag in vm_module below.
    template = "ubuntu-26.04-core"
  }

  # Every VM's network and cloud-init user, as homelab-proxmox-core's
  # (terraform/variables.tf): CoreDNS then Pi-hole, the template's user,
  # and your public key (nothing to encrypt).
  network = {
    gateway      = "192.168.68.1"
    bridge       = "vmbr0"
    nameservers  = ["192.168.68.2", "192.168.68.5"]
    searchdomain = "homelab.bcochofel.com"
    prefix       = 22
  }
  ciuser = "ubuntu"
  sshkeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEZGQwHOs8V9ndmLn3NuQXxuD0Ht4zaz+c6/WaEMAA6S bcochofel@NUC12WSHi7",
  ]

  # homelab-proxmox-core's VM module, by tag (core's tags are X.Y.Z): 8.1.0+
  # adds data_disk, the optional second disk.
  vm_module = {
    source = "git::https://github.com/BCochofelHomelab/homelab-proxmox-core.git//terraform/modules/vm"
    ref    = "8.1.1"
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
