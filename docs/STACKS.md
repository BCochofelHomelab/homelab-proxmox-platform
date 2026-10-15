# Stacks

## Scopes

Every resource belongs to one of three scopes, and goes in **the narrowest
scope that contains everyone its change affects**.

| Scope | Examples | A change affects | Folder |
| --- | --- | --- | --- |
| Shared | integration packages and versions, Fleet outputs and Fleet Server hosts, ILM, index templates, ingest pipelines, platform roles, service accounts | everyone | `shared/` |
| Per host group | agent policy, its integration policies | hosts in that group | `agent-policies/<group>/` |
| Per workspace | space, data views, dashboards, rules, workspace roles and bindings | one workspace | `workspaces/<id>/` |

Upgrading the `system` package touches every policy, so it's shared.
Adding an integration to one group's policy touches only those hosts.

## What is a stack

A folder is a Terramate stack only if it needs **its own state** and has
at least one of: its own change cadence, its own credential or target, or
its own owner.

| Stack | Not a stack |
| --- | --- |
| One per platform VM role (`platform/elasticsearch` holds all 3 nodes) | A single VM |
| `shared/security`, `shared/data`, `shared/fleet` | Ansible: it runs between layers |
| One per host group | An integration policy (inside its host group) |
| One per workspace | A dashboard or a rule (content inside its workspace) |
| `apps/k3s`, `apps/otel-demo` | An app or service: `service.name` content inside a workspace |
| | Modules, Terramate config, globals |

One stack per workspace, never one stack with `for_each` over all of them:
otherwise every change plans every workspace, and one broken rule blocks
every apply. The same reason keeps agent policies out of `shared/fleet`.

## Layers and order

```text
platform/        tags platform, proxmox
   ↓ Ansible configures the VMs (not a stack)
shared/          tags shared, elasticstack           after tag:platform
   ├→ agent-policies/   tags agent-policy, elasticstack   after tag:shared
   └→ workspaces/       tags workspace, elasticstack      after tag:shared
apps/            tag apps                            homelab only
```

`terramate list --run-order` prints the order. Terramate generates each
stack's backend (`_terramate_backend.tf`) and its providers **by tag**, so
an agent-policy or workspace stack only ever gets the Elastic provider,
never Proxmox credentials.

## State and credentials

- **State:** HCP Terraform organization `homelab-bcochofel-com`, one
  workspace per stack named `platform-<stack path>` (for example
  `platform-workspaces-otel_demo`), execution mode Local, as in core.
  Create each workspace before its first `tofu:init`.
- **Credentials:** `~/.secrets/homelab.yaml`, through `sops exec-env`
  (mise.toml). Proxmox stacks read `TF_VAR_proxmox_api_token` and
  `TF_VAR_cipassword`; Elastic stacks read `ELASTICSEARCH_ENDPOINTS`,
  `ELASTICSEARCH_API_KEY`, `KIBANA_ENDPOINT` and `KIBANA_API_KEY`.
- **Target: one API key per stack.** `shared/security` will mint one key
  per stack, scoped to what that stack manages. Until then every Elastic
  stack uses one bootstrap key.
- **Lock files:** each stack commits its `.terraform.lock.hcl` after its
  first `tofu:init`.

## Day to day

| I want to | I change | What plans |
| --- | --- | --- |
| add a dashboard to a workspace | `workspaces/<id>/dashboards/<name>.ndjson` | that workspace |
| add a rule to a workspace | `workspaces/<id>/rules/<name>.yaml` | that workspace |
| change who can see a workspace | `access.bindings` in its `workspace.yaml` | that workspace |
| onboard a workspace | a new `workspaces/<id>/` (docs/WORKSPACES.md) | that workspace |
| add an integration to a host group | its `agent-policy.yaml` | that host group |
| upgrade an integration package | `shared/fleet/fleet.yaml` and every policy using it | shared/fleet and those groups |
| canary a new workspace baseline | `module_ref` in one `workspace.yaml` | that workspace |
| roll it out to every workspace | `workspace_module_ref` in `terramate.tm.hcl` | every workspace without its own pin |
| resize Logstash | `platform/logstash`, then `ansible:site` | platform/logstash |

After changing a `workspace.yaml`'s `module_ref` or any `.tm.hcl` file, run
`mise run tm:generate` and commit the generated files: the pre-commit hook
and CI fail on stale generated code.
