# CLAUDE.md

Project context for Claude Code sessions — **not for humans**: never link or
reference this file from `README.md`, `CONTRIBUTING.md` or anything under
`docs/`. In those, say "the AI agent", not "Claude Code", except where the
text is about the product itself.

## What this is

`homelab-proxmox-platform`: everything behind `homelab-proxmox-core`'s edge
(Caddy, CoreDNS, Pi-hole). Homelab only: one self-managed Elastic Stack and
the OTel demo, on Proxmox VMs, with no Elastic Cloud and no Entra ID.

| VM | IP | Runs |
| --- | --- | --- |
| `es-01`, `es-02`, `es-03` | `192.168.68.30`–`.32` | Elasticsearch |
| `kibana` | `.33` | Kibana and Fleet Server |
| `ingest` | `.34` | Logstash and the EDOT gateway |
| `otel-demo` | `.35` | The OpenTelemetry demo, in Docker Compose (no k3s) |

Elastic Stack version `9.5.4`; `elastic/elasticstack` provider `~> 0.16.5`.

## Layout (it arrives over several pull requests)

Terramate stacks, each with its own HCP Terraform workspace, plan and
credentials. A resource goes in the narrowest scope that contains
everyone its change affects:

| Path | Scope |
| --- | --- |
| `platform/elastic/` | The five Elastic VMs (core's VM module and template, by tag) |
| `apps/otel-demo/` | The OTel demo VM |
| `shared/security`, `shared/data`, `shared/fleet` | Everyone: roles and API keys; ILM, templates, ingest pipelines; Fleet outputs, Fleet Server host, integration packages |
| `agent-policies/<group>/` | One host group: its agent policy and integrations (`agent-policy.yaml`) |
| `workspaces/<id>/` | One workspace, through `terraform-elasticstack-workspace`, pinned per workspace (`workspace.yaml`) |
| `ansible/` | Configures the VMs; not a stack |

Run order: `platform/elastic`, `apps/otel-demo` → Ansible → `shared/` →
`agent-policies/` and `workspaces/`.

Terramate: `terramate.tm.hcl` holds the globals (provider pins, core's
template and VM module ref, the workspace module's source and default ref,
Elastic endpoints) and imports `terramate/*.tm.hcl`, which generate each
stack's backend (HCP workspace `platform-<path with / as ->`, execution
mode Local) and its one provider by tag: `proxmox` or `elastic`, exactly
one (an `assert` fails `generate` otherwise). Kibana and Fleet reuse
`ELASTICSEARCH_API_KEY` (provider v0.16.6's config fallback, checked in
its source). Core's tags are `X.Y.Z` since `2.0.0` (older ones are
`vX.Y.Z`). Pre-commit runs `terramate fmt`, `terramate generate` and
`scripts/check_contract.py` (ids and namespaces).

VM stacks hold only `local.vms` (`main.tf`); `terramate/vms.tm.hcl`
generates core's module call (one disk: core's module has no data disk),
`outputs.tf`, and tags every VM `platform`, `terraform` and its Ansible
groups. Ansible's inventory is `ansible/inventory/platform.proxmox.yml`
(community.proxmox, needs `requests` in `.venv`): VMs tagged `platform`,
one group per other tag (`kibana_server`, not `kibana`: a group can't
share the host's name), `ansible_host` from cloud-init's `ipconfig0`. Its
token is `inventory@pve!ansible` (role `AnsibleInventory`); user and token
id are in the file, only `PROXMOX_TOKEN_SECRET` comes from `homelab.yaml`.
Without it (the agent), the inventory is empty: `--syntax-check` still
works. `tofu:*` are `terramate run` from `{{cwd}}`; `ansible:site` passes
extra args through `printf %q` inside the `sops exec-env` command.

## Decisions that are deliberate (do not "fix" these)

- **Namespace = workspace id**, the only coupling with the module. Ids match
  `^[a-z0-9_]{1,64}$`, never `default`. Starting workspaces: `platform`
  and `otel_demo`.
- **One Elastic API key for OpenTofu**, in `~/.secrets/homelab.yaml`: one
  person, and each stack's separate state already isolates changes.
- **Two VM stacks** (`platform/elastic`, `apps/otel-demo`), not one per role.
- **The VM template and VM module are homelab-proxmox-core's**, consumed by
  tag: one template to patch.
- **Ansible's inventory is Proxmox's dynamic inventory, with its own
  read-only token** (`VM.Audit` + `VM.GuestAgent.Audit`) in
  `homelab.yaml`. Never the AI agent's token, and never OpenTofu state.
- **An internal CA** for TLS inside the stack; Caddy (core) trusts it for
  Kibana through `trusted_ca`.
- **One code owner**, `sre-lead`.
- Never name the repository this replaced, in any file.

## The guardrails (the same as homelab-proxmox-core's)

- **The AI agent works only in its devcontainer** (`.devcontainer/`), in its
  own clone (`~/Projects/ai-agent/homelab-proxmox-platform`), as the machine
  user `bcochofel-ai-agent`: only the `ai-agent` age key, `homelab-ro.yaml`
  and `ai-agent-git.yaml` are mounted. `mise run check:boundary` proves it.
- **The agent never writes `.github/workflows/`**: its token can't push
  them. Workflow changes go in the pull request's description, for the
  human to commit.
- **Every change is a pull request**; `sre-lead` (the human) owns every file
  and is the only one who merges, applies and runs playbooks.
- `.claude/settings.json` denies reading keys and secrets, decrypting, the
  credentialed mise tasks (`tofu:*`, `ansible:site`, `sops`) in every form,
  `mise exec`, destroying, merging, approving, tagging and `gh api` writes.
- Secrets: credentials for tools, or shared across repos, in `~/.secrets/`;
  Ansible-only secrets in `ansible/inventory/group_vars/<group>.sops.yaml`
  (your key + the `ci` key, never `ai-agent`; `.sops.yaml`). Never read,
  print or decrypt them.
- Every tool is pinned in `mise.toml` (locked in `mise.lock`), with core's
  versions. mise itself is `MISE_VERSION` in `.devcontainer/post-create.sh`
  and `version:` in every workflow's `jdx/mise-action` step; pre-commit
  `mise_version` fails when they differ.
- Every `check_mode: false` needs `# read-only: <why>` on the same line
  (pre-commit `check_mode_false_read_only`), for the dry-run to come.

## Commands

```bash
mise trust && mise install   # the pinned toolchain, .venv + collections, git hooks
mise run lint                # every pre-commit hook on every file
mise run check               # lint + gitleaks on the full history (what CI runs)
mise run check:boundary      # the agent's boundary holds
mise run sops -- <args>      # yours only: sops with your key
```
