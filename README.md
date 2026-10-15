# homelab-proxmox-platform

Everything behind the homelab's edge: an Elastic Stack and the
OpenTelemetry demo that sends it data, on Proxmox VMs. The edge itself (the
Caddy reverse proxy and the CoreDNS + Pi-hole DNS pair) is
[`homelab-proxmox-core`](https://github.com/BCochofelHomelab/homelab-proxmox-core),
whose conventions and guardrails this repository follows.

| VM | IP | Runs |
| --- | --- | --- |
| `es-01`, `es-02`, `es-03` | `192.168.68.30`–`.32` | Elasticsearch |
| `kibana` | `.33` | Kibana and Fleet Server |
| `ingest` | `.34` | Logstash and the EDOT gateway |
| `otel-demo` | `.35` | The OpenTelemetry demo |

## How it's organized

Observability is offered as **workspaces**: a workspace is a Kibana space
with its own data, access, dashboards and alerts, for one owner and one
audience. Data reaches a workspace through its data stream namespace, which
is the workspace id. Each workspace comes from the
[`terraform-elasticstack-workspace`](https://github.com/BCochofelHomelab/terraform-elasticstack-workspace)
module.

Every resource belongs to one of three scopes, and goes in the narrowest
one that contains everyone its change affects:

| Scope | Examples |
| --- | --- |
| **Shared** | Integration packages, Fleet outputs and Fleet Server, ILM, index templates, ingest pipelines, platform roles |
| **Per host group** | An agent policy and its integrations |
| **Per workspace** | A space, its data views, dashboards, rules and roles |

[Terramate](https://terramate.io) splits them into stacks, each with its
own OpenTofu state, so a change plans and applies only where it belongs.

## Status

This repository is being set up: the toolchain and the checks come first,
then the stacks and the playbooks.

## Getting started

Everything a contributor needs, from a clone, on Linux (Ubuntu or WSL2):

```bash
mise trust && mise install   # the pinned toolchain, Ansible in .venv, git hooks
mise run check               # what CI runs
```

How a change flows, and the rules it follows:
[`CONTRIBUTING.md`](CONTRIBUTING.md).
