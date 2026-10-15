# Workspaces and host groups

## What a workspace is

A container for observability data and resources that share **one owner
and one audience**: the unit of access, alert ownership and automation. A
good workspace passes four tests:

1. One accountable owner.
2. It outlives a reorganisation: named after what is observed, not the team.
3. One audience: anyone who may see part of it may see all of it.
4. One default alert destination.

The id (the folder name) is permanent: it's the **namespace** of every data
stream the workspace receives, `<type>-<dataset>-<id>`. Ids allow only
`[a-z0-9_]` and can't be `default`. The display name can change at any
time. Apps and services are content inside a workspace (`service.name`),
never workspaces themselves.

The workspace module's own documentation covers what a workspace receives:
[terraform-elasticstack-workspace](https://github.com/BCochofelHomelab/terraform-elasticstack-workspace).

## Onboarding a workspace

```bash
id=payments
terramate create "workspaces/$id" --name "workspace-$id" \
  --tags workspace,elasticstack --after tag:shared
mkdir -p "workspaces/$id/dashboards" "workspaces/$id/rules"
$EDITOR "workspaces/$id/workspace.yaml"   # at least: owner
mise run tm:generate && mise run contract
```

Then a pull request: CI plans nothing it can't see, and `tofu:plan` after
merge touches only the new stack. Point the workspace's data at it by
setting `namespace: <id>` on the integrations that collect it (below).

## `workspace.yaml`

```yaml
display_name: Payments          # optional; defaults to the id in title case
owner: payments-platform        # required: one accountable owner
description: Payments services  # optional
color: "#1BA9F5"                # optional space colour
solution: oblt                  # optional Kibana solution view
disabled_features: [siem]       # optional
data_types: [logs, metrics, traces]   # must include logs
access:
  realm: oidc                   # optional: limit mappings to one realm
  bindings:                     # identity-provider group -> viewer | editor
    grp-payments-engineers: editor
read_from: [platform]           # other workspaces' data its roles may read
alerting:
  destinations:                 # existing connectors notified by every rule
    - connector_id: <id>
      params: { ... }
  error_threshold: 50
module_ref: v1.1.0              # optional: pin this workspace's module version
```

Every key except `owner` is optional and falls back to the module's
default. `rules/<name>.yaml` holds one workspace rule each (`query`,
`threshold`, optional `data_type`, `comparator`, `window_minutes`, `name`);
`dashboards/<name>.ndjson` holds Kibana saved-object exports.

## Host groups and `agent-policy.yaml`

A host group is the set of hosts sharing one Fleet agent policy, owned by
whoever owns the hosts. One host group can write to several workspaces:
each integration names its own namespace.

```yaml
name: Proxmox VMs
description: Elastic Agent on every Proxmox VM.
namespace: platform            # the agent's own monitoring data
integrations:
  system:
    package: system
    version: "2.6.0"           # must match shared/fleet/fleet.yaml
    namespace: platform        # the owning workspace
    inputs:                    # optional, as in the package; vars as YAML
      system-logfile:
        streams:
          system.syslog:
            vars: { paths: [/var/log/syslog*] }
```

The policy id is the folder name; Ansible enrolls hosts with it.

## The namespace contract

The namespace convention is the only coupling between this repo and the
module: data for workspace `<id>` is written with `namespace = <id>`. It is
set in three places only: Fleet integration policies (`agent-policies/`),
the APM path, and Logstash pipelines (`ansible/`). It is checked three
ways:

1. **Ids:** `scripts/check_contract.py` (pre-commit and CI) checks every
   workspace id against `[a-z0-9_]`, not `default`.
2. **References:** the same script checks every agent policy's and
   integration's namespace, and every `read_from`, names an existing
   workspace, and every integration's version matches `shared/fleet`.
3. **Data:** a rule in the `platform` workspace alerts on data arriving in
   a namespace with no workspace (to add once the platform workspace is
   live).

### APM caveat

A shared APM Server writes one namespace per integration policy. Routing
APM data per workspace needs a reroute processor in a `@custom` ingest
pipeline in `shared/data`. Verify that before onboarding the first APM
workspace; until then OTel data goes through the collector, which sets
`data_stream.namespace` itself.
