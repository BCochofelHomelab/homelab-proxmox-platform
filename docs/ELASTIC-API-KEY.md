# OpenTofu's Elastic API key

`ELASTICSEARCH_API_KEY`, in `~/.secrets/homelab.yaml` (your key only), is
the only credential that writes to the Elastic Stack. Every stack tagged
`elastic` uses it, through the `mise run tofu:*` tasks: `stacks/shared/security`,
`stacks/shared/data`, `stacks/shared/fleet`, `stacks/agent-policies/*` and `stacks/workspaces/*`. The
provider sends it to Elasticsearch, and to Kibana and Fleet as well (they
fall back to it when they have no credentials of their own).

It's one key for every stack, deliberately: one person applies, and each
stack's own state already keeps a change to its scope. What the key may
do is scoped to what those stacks manage, and nothing else: this page
records that scope, so it can be checked. The file it lives in, and every
other shared credential, are homelab-proxmox-core's
[`docs/CREDENTIALS.md`](https://github.com/BCochofelHomelab/homelab-proxmox-core/blob/main/docs/CREDENTIALS.md).

## What it may do

Checked against the sources and docs of the Elasticsearch and Kibana
version the platform runs (`elastic.version` in `terramate.tm.hcl`) and of
the `elastic/elasticstack` provider every stack locks
(`.terraform.lock.hcl`). Bumping either means checking this table again:

| Privilege | Needed by | Why |
| --- | --- | --- |
| cluster `monitor` | every stack | The provider reads the cluster's version (`GET /`, `cluster:monitor/main`) to decide what a resource may send. |
| cluster `manage_ilm` | `stacks/shared/data` | `elasticstack_elasticsearch_index_lifecycle` (`platform-30d`). |
| cluster `manage_index_templates` | `stacks/shared/data` | `elasticstack_elasticsearch_component_template` (`logs@custom`, `metrics@custom`, `traces@custom`). |
| cluster `manage_security` | `stacks/shared/security`, `stacks/workspaces/*` | Roles (`elasticstack_kibana_security_role`: Kibana's role API writes the role to Elasticsearch as the caller) and role mappings (`elasticstack_elasticsearch_security_role_mapping`). No narrower privilege writes roles: `read_security` only reads them. |
| index `read`, `view_index_metadata` on `logs-*`, `metrics-*`, `traces-*` | `stacks/workspaces/*` | Data views read the fields; the workspaces' rules query the data (below). |
| Kibana `all`, every space (`kibana-.kibana`, privilege `all`, resource `*`) | every stack | Creating a space needs Kibana's *global* `all` (the spaces client checks `space:manage`, which only global `all` grants). It also covers Fleet and Integrations (Fleet's routes check only those two Kibana features, then write as Kibana's internal user), data views, saved objects, connectors and rules. |

Nothing else: no `manage` (cluster settings), no `manage_pipeline`, no
snapshots, no writes to any index or data stream. A new resource type
that needs another privilege (an ingest pipeline: `manage_pipeline`)
means updating this table and creating a new key with it.

### Rules run on this key

A rule created through Kibana's API by a caller authenticated with an
API key keeps that very key and runs on it (Kibana's
`resolve_rule_api_key.ts`: `api_key_created_by_user: true`). So the
workspaces' rules (`No data`, `Error rate`, the platform's `Data in a
namespace with no workspace`) search their data with this key's `read`
privileges, and they **stop running when this key expires or is
invalidated**. Rotating it means re-keying them ([below](#rotating-it)).

### What it could still do

`manage_security` writes users and roles, so whoever holds this key could
create a user with more privileges than the key has. That's why it stays
a tier 1 secret (`homelab.yaml`, your key only): never the AI agent's,
and never the CI runner's. The scope above still keeps an honest mistake
in a plan (or a provider bug) away from cluster settings, data and
pipelines.

## Creating it

Create it **as `elastic`** (or another user with every privilege below),
in Kibana's Dev Tools (`https://kibana.homelab.bcochofel.com`), not with
another API key: a key created by an API key can't have privileges of its
own. The key's privileges are these role descriptors, intersected with
yours.

```json
POST /_security/api_key
{
  "name": "opentofu-homelab-proxmox-platform-2026-10",
  "expiration": "365d",
  "role_descriptors": {
    "opentofu-homelab-proxmox-platform": {
      "cluster": ["monitor", "manage_ilm", "manage_index_templates", "manage_security"],
      "indices": [
        {
          "names": ["logs-*", "metrics-*", "traces-*"],
          "privileges": ["read", "view_index_metadata"]
        }
      ],
      "applications": [
        {
          "application": "kibana-.kibana",
          "privileges": ["all"],
          "resources": ["*"]
        }
      ]
    }
  },
  "metadata": {
    "repository": "homelab-proxmox-platform",
    "used_by": "mise run tofu:* (every stack tagged elastic)",
    "docs": "docs/ELASTIC-API-KEY.md"
  }
}
```

The name carries the month it was created, so the old and the new key
can be told apart while rotating. 365 days: rotating means re-keying the
rules too, so once a year, not every quarter. Set a reminder a week
before it expires.

The response shows the key once. Put its **`encoded`** value (not `id`,
not `api_key`) in `homelab.yaml`, from `~/.secrets` (SOPS finds its
config from the current directory):

```bash
cd ~/.secrets
SOPS_AGE_KEY_FILE=~/.config/sops/age/bcochofel.txt sops homelab.yaml
```

```yaml
# homelab-proxmox-platform's OpenTofu, the Elastic stacks (its mise run tofu:*)
ELASTICSEARCH_API_KEY: "<the encoded value>"
```

**The current key:** `opentofu-homelab-proxmox-platform-2026-10`,
created 2026-10-19, expires 2027-10-19 (rotate in the week before). It
replaced `opentofu-homelab-proxmox-platform` (unscoped, no expiry, no
read on the data streams), invalidated the same day. Update this line at
every rotation.

## Checking it

From the repo root. The key reaches `curl` through standard input, never
as an argument.

It has the privileges above, and only those:

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/bcochofel.txt sops exec-env ~/.secrets/homelab.yaml '
printf "Authorization: ApiKey %s\n" "$ELASTICSEARCH_API_KEY" |
  curl -s --cacert ansible/pki/elastic-ca.crt -H @- -H "Content-Type: application/json" \
    https://192.168.68.30:9200/_security/user/_has_privileges -d "{
      \"cluster\": [\"monitor\", \"manage_ilm\", \"manage_index_templates\", \"manage_security\", \"manage\", \"manage_pipeline\"],
      \"index\": [{\"names\": [\"logs-x-platform\"], \"privileges\": [\"read\", \"view_index_metadata\", \"write\", \"delete_index\"]}],
      \"application\": [{\"application\": \"kibana-.kibana\", \"privileges\": [\"all\"], \"resources\": [\"*\"]}]
    }"'
```

Expect `"has_all_requested": false`, with `true` for the four cluster
privileges in the table, `read`, `view_index_metadata` and Kibana's
`all`, and `false` for `manage`, `manage_pipeline`, `write` and
`delete_index`. Then `mise run tofu:plan` from the repo root: every
`elastic` stack plans with no changes and no `403`. A `403` names the
privilege it lacked: add it to the table and the key here, never
`superuser`.

The key you had before this page may have been created with no
`role_descriptors`: such a key has every privilege of the user who
created it (`superuser`, for `elastic`). See what it has with
`GET /_security/api_key?name=<its name>` in Dev Tools (`role_descriptors`
empty means unscoped) and replace it by rotating, below.

## Rotating it

Before the old key expires (or now, to replace an unscoped one):

1. Create the new key ([above](#creating-it)), with this month in its
   name, and put its `encoded` value in `homelab.yaml`.
2. Check it ([above](#checking-it)).
3. Re-key the rules that ran on the old key, with the new one. Only
   rules OpenTofu made (`api_key_created_by_user`) are touched; a rule a
   person made in Kibana keeps its own key:

   ```bash
   SOPS_AGE_KEY_FILE=~/.config/sops/age/bcochofel.txt sops exec-env ~/.secrets/homelab.yaml \
     'python scripts/elastic_rekey_rules.py --dry-run'   # lists them
   SOPS_AGE_KEY_FILE=~/.config/sops/age/bcochofel.txt sops exec-env ~/.secrets/homelab.yaml \
     'python scripts/elastic_rekey_rules.py'             # ok/FAIL per rule
   ```

4. Invalidate the old key, in Dev Tools:

   ```json
   DELETE /_security/api_key
   { "name": "<the old key's name>" }
   ```

5. In Kibana, each workspace's space, *Stack Management > Rules*: every
   rule's last run is *Succeeded* after its next interval. One that
   fails with an authorization error still has the old key: run step 3
   again.

If a key leaks, do the same at once, step 4 first: the rules stop until
step 3 runs, which is the point.
