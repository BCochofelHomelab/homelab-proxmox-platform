# homelab-proxmox-platform

The homelab's Elastic observability platform, operated with OpenTofu and
Terramate. It creates the platform VMs, configures them with Ansible, and
offers **workspaces**: a ready-to-use Kibana space per thing being
observed, with its data, access, baseline dashboards and alerts, built by
the [terraform-elasticstack-workspace](https://github.com/BCochofelHomelab/terraform-elasticstack-workspace)
module. Adding a dashboard to one workspace plans one stack and touches
nothing else.

It replaces homelab-proxmox-workloads. VM templates, DNS, TLS and the
reverse proxy stay in homelab-proxmox-core.

## Quickstart

```bash
mise trust && mise install   # pinned toolchain, .venv, git hooks, Ansible collections
mise run check               # pre-commit, gitleaks, Terramate generated code, namespace contract
mise run validate            # tofu validate in every stack, no credentials
```

Day to day (credentials through `sops exec-env`, yours only):

```bash
mise run tofu:plan           # stacks changed vs main; saves <stack>/tfplan
mise run tofu:apply          # applies those plans in run order
mise run ansible:site        # configures the platform VMs
```

## Layout

```text
terramate.tm.hcl     globals: providers, module versions, HCP organization
terramate/           code generation: backend, providers, workspace and agent-policy calls
platform/            Layer 1, Proxmox VMs: elasticsearch (3 nodes), kibana, fleet-server, logstash
shared/              platform-wide Elastic config: security, data, fleet
agent-policies/      one stack per host group: agent-policy.yaml
workspaces/          one stack per workspace: workspace.yaml, dashboards/, rules/
apps/                homelab-only consumers of the platform: k3s, the OTel demo
ansible/             configures platform/ VMs; inventory from Proxmox tags
scripts/             check_contract.py and the shared hygiene scripts
```

Run order: `platform/` → Ansible → `shared/` → `agent-policies/` and
`workspaces/` (independent of each other) → `apps/otel-demo`.

## Documentation

- [docs/STACKS.md](docs/STACKS.md): scopes, what is and isn't a stack,
  layers, credentials, day-to-day changes
- [docs/WORKSPACES.md](docs/WORKSPACES.md): onboarding a workspace or a
  host group, the YAML reference, the namespace contract
- [docs/ANSIBLE.md](docs/ANSIBLE.md): the dynamic inventory, enrollment
- [CONTRIBUTING.md](CONTRIBUTING.md): how a change flows, checks, toolchain
