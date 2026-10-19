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

VM stacks hold `local.vms` (`main.tf`) and `outputs.tf`, by hand: never
generate a file name another stack writes by hand (`terramate run`, so
every `tofu:*`, refuses it as outdated; the pre-commit hook runs that
check too). `terramate/vms.tm.hcl` generates core's module call (`data_disk`, core 8.1.0+: an empty scsi1
disk, `/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi1`, which
Ansible formats and mounts before Elasticsearch or Logstash writes data),
and tags every VM `platform`, `terraform` and its Ansible
groups. Ansible's inventory is `ansible/inventory/platform.proxmox.yml`
(community.proxmox, needs `requests` in `.venv`): VMs tagged `platform`,
one group per other tag (`kibana_server`, not `kibana`: a group can't
share the host's name), `ansible_host` from cloud-init's `ipconfig0`. Its
token is `inventory@pve!ansible` (role `AnsibleInventory`); user and token
id are in the file, only `PROXMOX_TOKEN_SECRET` comes from `homelab.yaml`.
Without it (the agent), the inventory is empty: `--syntax-check` still
works. `tofu:*` are `terramate run` from `{{cwd}}`; `ansible:site` passes
extra args through `printf %q` inside the `sops exec-env` command, only
when there are some (`printf '%q '` with none prints `''`).

Ansible (`ansible/`; see below for agents): DEBs for Elasticsearch, Kibana, Logstash; Elastic
Agent tarball (signature + SHA-512) for Fleet Server (servers flavor, the
template has no agent) and the EDOT gateway (`elastic-agent otel`); Docker
Compose only for the OTel demo (Docker is in core's template, on every
VM). Internal CA: `ansible/pki/elastic-ca.crt` + `elastic-ca.key.sops`
(human + `ci` keys), from `mise run pki:init` (denied to the agent);
`elastic_pki` signs CSRs on the controller. Secrets per group:
`elastic.sops.yaml` (`elastic_password`; `elastic` is a composed group of
every Elastic VM, in the inventory file), `kibana_server.sops.yaml`
(`kibana_system_password`, `kibana_encryption_key`), `logstash.sops.yaml`
(`logstash_writer_password`), `edot_gateway.sops.yaml`
(`edot_writer_password`). Fleet Server ends its host's play (`meta:
end_host`, with a message) until `shared/fleet` has created
`fleet-server-policy`. The demo's namespace: `OTEL_RESOURCE_ATTRIBUTES=
data_stream.namespace=otel_demo` on its collector container (upstream's
`resource_detection` env detector, first in every pipeline); it's in the
role's defaults, not group_vars, until `workspaces/otel_demo` exists for
the contract check. The inventory reaches Proxmox through core's Caddy
(`https://pve1.homelab.bcochofel.com`, Let's Encrypt, verified).
Stack monitoring: `elasticsearch` (agent-policies/elasticsearch, HTTPS to
localhost, scope node), `kibana` (on `fleet-server-policy` in
`shared/fleet`: Kibana listens on 192.168.68.33, not localhost) and
`logstash` (agent-policies/ingest: its `logstash/metrics` stack-monitoring
streams are off by default) log in as `remote_monitoring_user`, whose
password is `remote_monitoring_password` in `group_vars/elastic.sops.yaml`:
Ansible sets it (10-elasticsearch.yml), OpenTofu reads the same file
(`sops` provider; in agent-policy.yaml as `{secret: <key>}`, every
agent-policy stack gets the provider from `agent-policies/agent-policies.tm.hcl`).

Shared stacks (tag `elastic` + `shared`; `shared/fleet` also `fleet`): `shared/security` (roles
`platform-admin`, `platform-viewer`: native users, no SSO; no users or API
keys managed here), `shared/data` (ILM `platform-30d` via `logs|metrics|
traces@custom`, which the OTel templates compose too, checked in ES
v9.5.4's source), `shared/fleet` (packages `fleet_server` 1.6.1, `system`
3.0.0; Fleet Server host; `fleet-default-output` imported; policy
`fleet-server-policy` in namespace `platform`; the Logstash output, see
below). Order: `shared/data` and `shared/security` after
`/platform/elastic`, `shared/fleet` after `/shared/data`. Elastic stacks
get a comment-only generated `variables.tf` (TFLint). The OpenTofu API key
is the human's (`ELASTICSEARCH_API_KEY` in `homelab.yaml`), scoped in
`docs/ELASTIC-API-KEY.md` (monitor, manage_ilm, manage_index_templates,
manage_security; read on logs/metrics/traces; Kibana `all` on `*`, which
spaces need): a resource type needing another privilege updates that
page's table and request. Rules created with it keep it (Kibana 9.5.4),
so rotating it runs `scripts/elastic_rekey_rules.py`.

Agent policies and workspaces (PR 10): `agent-policies/<group>/`
(`elasticsearch`, `ingest`, `otel-demo`; and core's hosts: `core` for proxy
and server01 with system + docker, `core-runner` for runner01 with system
only since Docker is masked there, `proxmox` for pve1, all into workspace
`core`; core's Ansible installs and enrolls those agents; tags `elastic`, `agent-policy`,
`fleet`; after `/shared/fleet`) hold `agent-policy.yaml`;
`workspaces/<id>/` (`platform`, `otel_demo`, `core`; tags `elastic`, `workspace`;
after `tag:shared`) hold `workspace.yaml`, optional `dashboards/`,
`rules/`. Both read their YAML at plan time (`yamldecode(file())`), so
`tofu validate` catches YAML errors; only `module_ref` is read by
Terramate (a module source can't be an expression; `lets` are evaluated
in every stack, hence `tm_try`). Their `main.tf` and `outputs.tf` are
hand-written (TFLint wants them, and generating a name other stacks write
by hand breaks `terramate run`). Package versions: `global.fleet_packages`,
generated as `local.fleet_packages` into stacks tagged `fleet`;
`shared/fleet` installs every one (`elasticstack_fleet_integration.packages`). The
platform workspace's `unknown_namespace` rule is generated from
`terramate.stacks.list` (every workspace id; Fleet Server's `fleet_server.*`
datasets excluded). `shared/fleet` has the Logstash output (default, after
Fleet Server's integration; Fleet keeps Elasticsearch for the Fleet Server
policy) with the agents' shared client certificate (`mise run
pki:agent-client`, the human's; key read by the `carlpett/sops` provider,
`global.extra_providers` in its stack.tm.hcl). Ansible: `elastic_agent`
installs the tarball and enrolls into `elastic_agent_policy_id`, skipping
the host until the policy exists; the health check polls Fleet for every
agent (`online`), with retries. `scripts/check_contract.py` also checks
`.tf` namespace literals and `elastic_agent_policy_id`s. Rules run with
OpenTofu's API key: it needs read on the data streams.

Dry-run (core's, SRE-AI.md A10): `.github/workflows/dry-run.yml` (the
human's to commit) runs `mise run ci:plan` (every stack, `terramate run
--continue-on-error`, `-refresh=false`, never `-out`) and `ci:check`
(`site.yml --check --diff`) on core's runner01 after the `dry-run`
environment's approval, as `ci`: `ci/dry-run.sops.yaml` (human + ci keys:
`TF_VAR_proxmox_api_token` ci@pve!plan, `TF_VAR_cipassword`,
`TF_TOKEN_app_terraform_io`, a read-only `ELASTICSEARCH_API_KEY`,
`PROXMOX_TOKEN_SECRET`) and `ci/ssh_ed25519.key.sops` (core's automation
key; its public half in `roles/ci_ssh_key`, play `01-ci-ssh-key.yml`).
Both tasks denied to the agent. `site.yml`'s first play refuses a real
run where `HOMELAB_DRY_RUN=1`. Check mode: `uri` is skipped under
`--check`, and a later task templated from its result fails, so a
read-only one gets `check_mode: false # read-only: ...`; a download,
unpack or enrollment block gets `and not ansible_check_mode`, after a
`debug` with `changed_when: true` saying what a real run would do;
version asserts get `ignore_errors: "{{ ansible_check_mode }}"` (a
version bump isn't installed by a dry-run).

Releases: semantic-release as core's (`.releaserc.js`, `package.json`,
`package-lock.json` copied from core; `release.yml` is the human's to
commit), tags `X.Y.Z` with no `v`, first release `1.0.0`.

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

`docs/SETUP.md` is the human's record of everything configured by hand
(Proxmox, HCP, Elastic, GitHub, secret files), in rebuild order: a pull
request that adds or changes such a step updates it too, and lists the
step in its description. Its *Open items* hold proposals not yet built
(the agent's read-only Elasticsearch MCP server, decided: standalone
v0.4.6, free tier).
