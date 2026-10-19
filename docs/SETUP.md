# Setup

How to build the platform from nothing, or rebuild it after losing it,
and end up exactly where it is today: everything in order, each stage
closed by its check. Day 2 (adding a workspace or a host group) is in the
[README](../README.md).

## How to use this page

- **Follow the stages in order.** Each relies on the ones before it, and
  ends with a check that must pass before you go on.
- **This page is the record** of everything configured by hand for this
  repository (Proxmox, HCP Terraform, Elastic, GitHub, the secret files).
  Change a setting, change it here too.
- **Shared identities are homelab-proxmox-core's**, and documented once,
  there: its [`docs/SETUP.md`](https://github.com/BCochofelHomelab/homelab-proxmox-core/blob/main/docs/SETUP.md)
  (the order) and [`docs/CREDENTIALS.md`](https://github.com/BCochofelHomelab/homelab-proxmox-core/blob/main/docs/CREDENTIALS.md)
  (the procedures and the secret tiers): the age keys (yours, `ai-agent`,
  `ci`), `~/.secrets/`, `terraform@pve!terraform`, the HCP token, the AI
  agent's identities and the dry-run runner. This page names what the
  platform adds to them, and links the rest.
- Run everything **from the root of your own clone**
  (`~/Projects/GitHub/BCochofelHomelab/homelab-proxmox-platform`), on an
  up-to-date `main`, unless a step says otherwise. Files the steps commit
  (`ansible/pki/`, `*.sops.yaml`, `ci/`) are yours to commit: the AI agent
  can't create or decrypt them.
- **A rebuild keeps what's committed.** The CA, the agents' client
  certificate and every `*.sops.yaml` live in the repository: a step that
  creates one says so, and on a rebuild you skip it.

## Stage 0. What core provides

The platform runs behind homelab-proxmox-core, so core comes first, up to
its stage 6 (stages 7 and 8, the AI agent and the dry-run runner, are
needed only for this page's stages 9 and 10). From core, the platform uses:

| What | Where it's set up in core | Used here by |
| --- | --- | --- |
| The VM template `ubuntu-26.04-core` and the VM module (by tag, `terramate.tm.hcl`) | Stage 5 (`packer build`) | `platform/elastic`, `apps/otel-demo` |
| `terraform@pve!terraform`, `TF_VAR_cipassword`, the HCP token, in `~/.secrets/homelab.yaml` | CREDENTIALS.md steps 1, 2, 5 | `mise run tofu:*` |
| Your age key at `~/.config/sops/age/bcochofel.txt`, and the `ci` key's public half | CREDENTIALS.md steps 4, 11.1 | every `*.sops.yaml` here (`.sops.yaml`) |
| DNS for every platform VM, and `kibana`/`pve1` through Caddy | `dns_hosts`, `caddy_sites` (`trusted_ca: platform-elastic`, core's copy of this repo's CA) | the inventory (`pve1.homelab.bcochofel.com`), Kibana's public URL |

*Check:* in core, `mise run check:creds` passes, and
`https://pve1.homelab.bcochofel.com` answers with a valid certificate.

## Stage 1. Proxmox: the inventory's token

Ansible finds the VMs through Proxmox's dynamic inventory
(`ansible/inventory/platform.proxmox.yml`), with its own read-only token,
never the AI agent's and never OpenTofu's state. On `pve1`:

```bash
pveum role add AnsibleInventory -privs "VM.Audit VM.GuestAgent.Audit"
pveum user add inventory@pve --comment "Ansible dynamic inventory (homelab-proxmox-platform), read-only"
pveum user token add inventory@pve ansible --privsep 1
pveum acl modify /vms -user inventory@pve -role AnsibleInventory
pveum acl modify /vms -token 'inventory@pve!ansible' -role AnsibleInventory
```

`token add` prints the secret once. Put **only the secret** (the UUID, not
`user!token=secret`) in `~/.secrets/homelab.yaml` as
`PROXMOX_TOKEN_SECRET`, with core's `mise run secrets:edit --
homelab.yaml`. The inventory file names the user and token id.

*Check:* core's `mise run check:creds` shows `Proxmox token
inventory@pve!ansible (PROXMOX_TOKEN_SECRET) (HTTP 200)`.

## Stage 2. HCP Terraform: one workspace per stack, Local execution

State only: every stack has its own HCP Terraform workspace in
`homelab-bcochofel-com`, named after its path (`platform-<path with / as
->`), and **runs locally** (execution mode *Local*). `tofu init` creates a
missing workspace on first use, with the organization's default execution
mode, so set that default once: *Organization settings → General →
Default execution mode → Local*. Otherwise set each new workspace to
*Local* (*Workspace → Settings → General*) right after its first
`tofu:init`.

The fourteen workspaces, created in stages 3, 7 and 8:

```text
platform-platform-elastic              platform-apps-otel-demo
platform-shared-security               platform-shared-data             platform-shared-fleet
platform-agent-policies-elasticsearch  platform-agent-policies-ingest   platform-agent-policies-otel-demo
platform-agent-policies-core           platform-agent-policies-core-runner  platform-agent-policies-proxmox
platform-workspaces-platform           platform-workspaces-otel_demo    platform-workspaces-core
```

*Check* (after each stage that creates some): every `platform-*`
workspace is *Local*:

```bash
SOPS_AGE_KEY_FILE=~/.config/sops/age/bcochofel.txt sops exec-env ~/.secrets/homelab.yaml '
printf "Authorization: Bearer %s\n" "$TF_TOKEN_app_terraform_io" |
  curl -s -H @- "https://app.terraform.io/api/v2/organizations/homelab-bcochofel-com/workspaces?search%5Bname%5D=platform-&page%5Bsize%5D=100"' |
  python3 -c 'import json,sys; [print(w["attributes"]["name"], w["attributes"]["execution-mode"]) for w in json.load(sys.stdin)["data"]]'
```

## Stage 3. The VMs

The two VM stacks (tag `proxmox`), from their own directories so only
they run:

```bash
for d in platform apps; do (cd $d && mise run tofu:init && mise run tofu:plan); done
# review both plans, then:
for d in platform apps; do (cd $d && mise run tofu:apply); done
```

`tofu:plan` saves each plan to its stack's `tfplan`, and `tofu:apply`
applies only that, so what you reviewed is what's applied. The same
pattern holds in every later stage: plan, review, apply.

*Check:* six VMs running in Proxmox, `es-01`–`es-03`, `kibana`,
`ingest` and `otel-demo`, each tagged `platform`, at `192.168.68.30`–`.35`;
both workspaces *Local* (stage 2).

## Stage 4. The internal CA, the agents' certificate, Ansible's secrets

**Skip on a rebuild:** all of these are committed. Commit each on a
branch, through a pull request.

1. **The CA**, once (`ansible/pki/elastic-ca.crt` and `elastic-ca.key.sops`,
   your key and the `ci` key). A *new* CA also needs core's copy updated
   (`trusted_ca: platform-elastic`), in a core pull request.

   ```bash
   mise run pki:init      # prints the CA's subject, expiry (10 years) and SHA-256 fingerprint
   ```

2. **The agents' client certificate**, once: every Elastic Agent presents
   it to Logstash (mTLS); `shared/fleet` reads it (2 years: renew by
   deleting both files and running it again).

   ```bash
   mise run pki:agent-client   # prints subject, issuer, expiry; "agent-client.crt: OK"
   ```

3. **Ansible's secrets**, one file per group (your key and the `ci` key).
   Each value is generated, never shown:

   | File | Key | What |
   | --- | --- | --- |
   | `elastic.sops.yaml` | `elastic_password` | The `elastic` superuser's password |
   | `elastic.sops.yaml` | `remote_monitoring_password` | `remote_monitoring_user`'s, for stack monitoring (Ansible sets it; OpenTofu reads it) |
   | `kibana_server.sops.yaml` | `kibana_system_password` | `kibana_system`'s |
   | `kibana_server.sops.yaml` | `kibana_encryption_key` | Kibana's encryption keys (32 characters or more) |
   | `logstash.sops.yaml` | `logstash_writer_password` | Logstash's writer user |
   | `edot_gateway.sops.yaml` | `edot_writer_password` | The EDOT gateway's writer user |

   ```bash
   g=ansible/inventory/group_vars
   # A file that doesn't exist yet opens in the editor: type any one of
   # its keys with a placeholder value, save; the next lines replace it.
   for f in elastic kibana_server logstash edot_gateway; do
     [ -e $g/$f.sops.yaml ] || mise run sops -- $g/$f.sops.yaml
   done
   new() { mise run sops -- set "$g/$1" "[\"$2\"]" "\"$(openssl rand -base64 "${3:-24}")\""; }
   new elastic.sops.yaml elastic_password
   new elastic.sops.yaml remote_monitoring_password
   new kibana_server.sops.yaml kibana_system_password
   new kibana_server.sops.yaml kibana_encryption_key 48
   new logstash.sops.yaml logstash_writer_password
   new edot_gateway.sops.yaml edot_writer_password
   ```

   `sops set` only edits an existing file, hence the loop first. Keep `elastic_password` somewhere you can
   reach without the homelab: it's the way back in.

*Check:* `mise run lint` passes (`sops files are encrypted`, `terraform
validate` of `shared/fleet` needs `agent-client.crt`), and
`mise run check:boundary` shows the `ai-agent` key refused by every one of
these files.

## Stage 5. Ansible, first run

```bash
mise run ansible:site
```

It formats each VM's data disk, installs Elasticsearch, Kibana, Logstash
and the EDOT gateway, and starts the OpenTelemetry demo. Fleet Server and
the Elastic Agents are **skipped, with a message**: their policies come
from OpenTofu in stages 7 and 8.

*Check:* `failed=0` on every host; the health check shows the cluster
green with 3 nodes, Kibana available over verified TLS and through core's
Caddy (`https://kibana.homelab.bcochofel.com`), and the demo's traces in
Elasticsearch.

## Stage 6. OpenTofu's Elastic API key

The only credential that writes to Elastic, scoped to what the stacks
manage: [`ELASTIC-API-KEY.md`](ELASTIC-API-KEY.md), *Creating it* and
*Checking it*. It goes in `~/.secrets/homelab.yaml` as
`ELASTICSEARCH_API_KEY`, and expires after 365 days: set the reminder.

*Check:* that page's `_has_privileges` answer.

## Stage 7. The shared stacks, then Fleet Server

```bash
(cd shared && mise run tofu:init && mise run tofu:plan)   # review, then:
(cd shared && mise run tofu:apply)
mise run ansible:site      # Fleet Server enrolls into fleet-server-policy
```

`shared/fleet` imports Fleet's own default output and makes Logstash the
default only after Fleet Server's integration exists (its `depends_on`).
After enrolling, Fleet may show Fleet Server *Unhealthy* (`output`) for a
few minutes while its output health check settles.

*Check:* three new workspaces *Local*; Fleet Server `HEALTHY` in the
health check; *Kibana → Fleet → Agents*: one agent, `kibana`, Healthy.

## Stage 8. Agent policies and workspaces, then the agents

Six host groups and three workspaces:

| Agent policy (`agent-policies/<id>`) | Hosts | Integrations | Data in workspace |
| --- | --- | --- | --- |
| `elasticsearch` | `es-01`–`es-03` | system, Elasticsearch (stack monitoring) | `platform` |
| `ingest` | `ingest` | system, Logstash (stack monitoring) | `platform` |
| `otel-demo` | `otel-demo` | system | `otel_demo` |
| `core` | core's `proxy`, `server01` | system, Docker | `core` |
| `core-runner` | core's `runner01` (no Docker: it's masked there) | system | `core` |
| `proxmox` | `pve1`, the Proxmox VE host | system | `core` |

(`kibana` is on `fleet-server-policy`, `shared/fleet`'s.) This repo's
Ansible enrolls the platform VMs; **core's Ansible enrolls core's hosts**,
with an enrollment token you copy from Fleet.

```bash
for d in agent-policies workspaces; do (cd $d && mise run tofu:init && mise run tofu:plan); done
# review, then:
for d in agent-policies workspaces; do (cd $d && mise run tofu:apply); done
mise run ansible:site      # every platform VM's agent enrolls into its host group's policy
```

Then **core's hosts**:

1. Copy the three enrollment tokens: *Kibana → Fleet → Enrollment
   tokens*, one each for *Homelab core*, *Homelab core runner* and
   *Proxmox*.
2. Put each in core's `ansible/inventory/group_vars/<group>.sops.yaml`
   (your key and the `ci` key), in the file core's AI agent names for
   it: tokens are secrets, never pasted to the agent.
3. Core's `mise run ansible:site` installs Elastic Agent 9.5.4 on `proxy`,
   `server01`, `runner01` and `pve1` and enrolls each into its policy,
   trusting this repo's CA (core's `ansible/files/trust/platform-elastic.crt`).

A rebuild from nothing is a new Fleet: core's agents' credentials and the
old tokens are gone, and core's Ansible never enrolls an agent that's
already managed (that would register a duplicate). So uninstall each one
first (`sudo elastic-agent uninstall --force` on the host), then repeat
steps 1 to 3.

Then your own Kibana user (*Stack Management → Users*), so `elastic`
stays for setup and recovery: `platform-admin` covers every space, or the
workspaces' `workspace-<id>-editor` / `-viewer` roles.

*Check:* nine new workspaces *Local*; the health check waits until every
platform VM's agent is online in Fleet; *Kibana → Fleet → Agents*: ten
agents, all Healthy, once core's hosts are enrolled; *Stack Monitoring*:
the cluster's 3 nodes, Kibana and Logstash; the *Core* space shows host
metrics from core's four hosts, and container metrics and logs from
`proxy` and `server01`.

## Stage 9. The AI agent (optional)

Core's stage 7 sets up the agent once for both repositories: the machine
user and its token, the read-only MCP servers, and the devcontainer
(core's `docs/DEVCONTAINER.md`). For this repository, its own clone:

```bash
git clone https://github.com/BCochofelHomelab/homelab-proxmox-platform.git ~/Projects/ai-agent/homelab-proxmox-platform
```

opened in VS Code with *Reopen in Container* (`.devcontainer/`).

*Check:* in the container, `mise run check:boundary`, every line ok.

## Stage 10. The dry-run (optional)

Pull requests are dry-run on core's runner, `runner01`, as `ci`, after
your approval (core's stage 8, which must be done first). For this
repository:

1. **The `ci` files**, committed through a pull request (skip on a
   rebuild), both your key and the `ci` key (`.sops.yaml`):
   - `ci/dry-run.sops.yaml`: `TF_VAR_proxmox_api_token` (`ci@pve!plan=...`,
     as core's), `TF_VAR_cipassword`, `TF_TOKEN_app_terraform_io` (core's
     `owners` team token, an accepted risk: core's CREDENTIALS.md 11.4),
     `PROXMOX_TOKEN_SECRET` (the inventory's read-only token, stage 1) and
     `ELASTICSEARCH_API_KEY`, a read-only key for the plan:

     ```json
     POST /_security/api_key
     {
       "name": "ci-plan-homelab-proxmox-platform-<yyyy-mm>",
       "expiration": "90d",
       "role_descriptors": {
         "ci-plan": {
           "cluster": ["monitor"],
           "applications": [{ "application": "kibana-.kibana", "privileges": ["read"], "resources": ["*"] }]
         }
       }
     }
     ```

     (`-refresh=false` plans only read the versions; a `403` names the
     *read* privilege to add, never a write one.)
   - `ci/ssh_ed25519.key.sops`: core's automation key, re-encrypted here:

     ```bash
     SOPS_AGE_KEY_FILE=~/.config/sops/age/bcochofel.txt sops decrypt --input-type binary --output-type binary \
         ../homelab-proxmox-core/ci/ssh_ed25519.key.sops |
       sops encrypt --filename-override ci/ssh_ed25519.key.sops --input-type binary --output-type binary /dev/stdin \
         > ci/ssh_ed25519.key.sops
     ```

2. **The automation key on the VMs:** `ci_ssh_key` (in `site.yml`) puts
   its public half on every VM, at every `ansible:site`. Core's template
   already has it for VMs cloned since 2026-10-12.
3. **The `dry-run` environment** (*Settings → Environments*), as core's:
   *Required reviewers* `sre-lead`, *Prevent self-review* off, *Allow
   administrators to bypass* **off**, no deployment branch restriction,
   environment secret `CI_AGE_KEY` (the `AGE-SECRET-KEY-...` line of
   `~/.config/sops/age/ci.txt`), then **Save protection rules**. And
   *Settings → Actions → General*: *Require approval for all external
   contributors*.
4. **The workflow**, `.github/workflows/dry-run.yml`: only you commit
   workflow files.

*Check:*

```bash
for ip in 30 31 32 33 34 35; do ssh ubuntu@192.168.68.$ip 'grep -c "ci@homelab (dry-run runner)" ~/.ssh/authorized_keys'; done   # 1 each
mise run ci:plan    # every stack: No changes.
mise run ci:check   # failed=0 on every host
```

Then a test pull request touching `ansible/`: the dry-run waits for your
approval, then comments each stack's plan line and the recap. The full
output is an artifact encrypted to you and the `ai-agent` key (core's
SETUP.md, *Output: the logs are public*).

## Keys that expire

| What | Lifetime | Renew |
| --- | --- | --- |
| OpenTofu's Elastic API key | 365 days (the current one: 2027-10-19) | [`ELASTIC-API-KEY.md`](ELASTIC-API-KEY.md), *Rotating it* (the rules are re-keyed too) |
| The CI plan's Elastic API key | 90 days | A new one (stage 10), in `ci/dry-run.sops.yaml`, then invalidate the old |
| The agents' client certificate | 2 years | Stage 4, step 2, then `tofu:apply` in `shared/fleet` |
| The internal CA | 10 years | Stage 4, step 1, every host's certificate again (`ansible:site`), and core's copy |

## Red button

Core's [red button](https://github.com/BCochofelHomelab/homelab-proxmox-core/blob/main/docs/SETUP.md#red-button)
stops the AI agent and the runner for both repositories: follow it. Its
level 2 (a credential may have leaked) adds, for this repository:

| Identity | Revoke | Then rotate |
| --- | --- | --- |
| The `ci` age key | As core's, and this repo's `CI_AGE_KEY` and `ci/` files | Everything in `ci/dry-run.sops.yaml` (the CI plan's Elastic key: `DELETE /_security/api_key` with its name) and Ansible's secrets (stage 4) |
| OpenTofu's Elastic API key | `DELETE /_security/api_key` with its name, in Dev Tools | A new one ([`ELASTIC-API-KEY.md`](ELASTIC-API-KEY.md)): the rules stop until re-keyed |
| `inventory@pve!ansible` | `pveum user token remove inventory@pve ansible` | Stage 1 again; `ci/dry-run.sops.yaml` too |

## Final verification

From your clone, on `main`:

```bash
mise run check            # what CI runs
mise run tofu:plan        # every stack: No changes
mise run ansible:site     # failed=0 everywhere; every agent online in Fleet
mise run ci:plan          # every stack: No changes (stage 10)
mise run ci:check         # failed=0 (stage 10)
```

Then, in the AI agent's devcontainer (stage 9), `mise run check:boundary`.

## Open items

### A read-only view of Elasticsearch for the AI agent (proposed, not built)

Today the agent sees the platform only through Proxmox, GitHub and the
Terraform registry: it can't read the cluster's own data while
investigating. Google's *AI engineering for reliable operations* wants
investigation agents that read everything and write nothing, read-only
enforced by the credential and proven by a negative test (core's
SRE-AI.md A8, and Phases B and C). The proposal, decided on the free tier
(Basic): Kibana's Agent Builder MCP endpoint needs an Enterprise licence
(Kibana 9.5.4, `minimumLicense: 'enterprise'`), so it's Elastic's
standalone server instead.

1. **The server:** Elastic's
   [`mcp-server-elasticsearch`](https://github.com/elastic/mcp-server-elasticsearch)
   **v0.4.6**, the Linux binary from its release, pinned in `mise.toml`
   with its SHA-256 (`7ec9c268...0cde6`, GitHub's digest), as
   `terraform-mcp-server` is. No Docker: the devcontainer has no Docker
   socket. It's deprecated (critical security fixes only, superseded by
   Agent Builder), which is the cost of staying on Basic: bumps are rare
   and reviewed. Its five tools all declare themselves read-only
   (`search`, `esql`, `list_indices`, `get_mappings`, `get_shards`), but
   the key is what enforces it (step 2), never the tool list.
2. **A read-only API key for the agent**, created as `elastic`, in
   `~/.secrets/homelab-ro.yaml` (your key and the `ai-agent` key), never
   in `homelab.yaml`:

   ```json
   POST /_security/api_key
   {
     "name": "ai-agent-ro-homelab-proxmox-platform-<yyyy-mm>",
     "expiration": "90d",
     "role_descriptors": {
       "ai-agent-ro": {
         "indices": [
           {
             "names": ["logs-*", "metrics-*", "traces-*"],
             "privileges": ["read", "view_index_metadata", "monitor"]
           }
         ]
       }
     }
   }
   ```

   Read on the data streams and nothing else. `monitor` here is the
   *index* privilege (index stats, read-only), which `list_indices` and
   `get_shards` need (`_cat/indices`, `_cat/shards`); no cluster
   privilege. No Kibana privilege either: this server only talks to
   Elasticsearch. In `homelab-ro.yaml`:

   ```yaml
   # Elasticsearch MCP server (homelab-proxmox-platform docs/SETUP.md)
   ES_URL: "https://192.168.68.30:9200"
   ES_API_KEY: "<the encoded value>"
   ```

3. **TLS verified against the internal CA**, never
   `ES_SSL_SKIP_VERIFY`. The server has no CA option, but it links the
   system's OpenSSL 3, which reads `SSL_CERT_FILE`: set to
   `ansible/pki/elastic-ca.crt` for this server's process only, its
   connections verify. Tested on the v0.4.6 binary against a stand-in
   with a test CA: with `SSL_CERT_FILE` the call succeeds; without it the
   handshake fails and no request is sent.
4. **`.mcp.json`**, as the Proxmox and GitHub servers: `sops exec-env
   ~/.secrets/homelab-ro.yaml` with the `ai-agent` key, `SSL_CERT_FILE`
   in the server's `env`.
5. **A negative test**, in `check:boundary`, as its Proxmox one: with the
   agent's key, a document write (`POST /logs-boundary-test/_doc`) and a
   role write (`PUT /_security/role/boundary-test`) must both answer
   `403`; a `2xx` is a `FAIL` that names what to delete.
6. **In core** (its AI agent's PR): `check:creds` gains a line for the key
   (`GET /_security/_authenticate`, from `homelab-ro.yaml` with the
   `ai-agent` key only), and CREDENTIALS.md step 5's `homelab-ro.yaml`
   example its two keys.
