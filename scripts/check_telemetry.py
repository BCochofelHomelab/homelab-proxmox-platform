#!/usr/bin/env python3
"""Check every host the platform observes reports its telemetry: its
Elastic Agent is online in Fleet, on its policy, and its host metrics
reached Elasticsearch, in its policy's namespace, in the last few minutes
(the whole path: agent, Logstash, Elasticsearch). Read-only: GETs and one
search.

The hosts:
  - the platform VMs, from Ansible's own inventory (Proxmox's, by tag), so
    a VM added there is checked without editing this; their policy is
    fleet_server_policy_id (the kibana VM) or elastic_agent_policy_id;
  - the hosts enrolled from outside this repo's Ansible (core's), listed
    under `hosts` in their stacks/agent-policies/<id>/agent-policy.yaml.
Each policy's namespace is its `system` integration's (agent-policy.yaml;
Fleet Server's is stacks/shared/fleet's, `platform`).

Usage, yours only (`mise run check:telemetry`, which runs, from ansible/):

  ansible-inventory --list | python ../scripts/check_telemetry.py --inventory - \\
    --policies ../stacks/agent-policies --cacert pki/elastic-ca.crt

with ELASTICSEARCH_API_KEY in the environment. Prints ok/FAIL per host and
check, never the key; exits 1 on any FAIL.
"""

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.request
from pathlib import Path

import yaml

KIBANA = "https://192.168.68.33:5601"
ELASTICSEARCH = "https://192.168.68.30:9200"
CA_CERT = "ansible/pki/elastic-ca.crt"
POLICIES = "stacks/agent-policies"
# Fleet Server's policy is stacks/shared/fleet's, not a stacks/agent-policies/ stack:
# its system integration writes to the platform workspace.
OTHER_POLICIES = {"fleet-server-policy": "platform"}
# Every policy's system integration writes metrics-system.*-<namespace>,
# every 10 seconds by default.
METRICS = "metrics-system.*-*"
FRESH_MINUTES = 10


def call(ctx, key, url, body=None):
    req = urllib.request.Request(url, data=None if body is None else json.dumps(body).encode())
    req.add_header("Authorization", f"ApiKey {key}")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        return json.loads(resp.read())


def load_policies(root):
    """{policy id: system namespace}, and {host: policy id} for listed hosts."""
    namespaces, listed = dict(OTHER_POLICIES), {}
    for path in sorted(Path(root).glob("*/agent-policy.yaml")):
        spec = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        policy = path.parent.name
        system = [i for i in spec.get("integrations", []) if i.get("package") == "system"]
        namespaces[policy] = system[0].get("namespace") if system else None
        for host in spec.get("hosts", []):
            listed[host] = policy
    return namespaces, listed


def expected_hosts(inventory, listed):
    hosts = dict(listed)
    for name, hv in inventory.get("_meta", {}).get("hostvars", {}).items():
        hosts[name] = hv.get("fleet_server_policy_id") or hv.get("elastic_agent_policy_id")
    return dict(sorted(hosts.items()))


def fleet_agents(ctx, key, kibana):
    agents, page = [], 1
    while True:
        found = call(ctx, key, f"{kibana}/api/fleet/agents?perPage=100&page={page}")
        agents += found["items"]
        if page * 100 >= found["total"]:
            return agents
        page += 1


def fresh_metrics(ctx, key, es):
    """{host: {namespaces with host metrics in the last FRESH_MINUTES}}."""
    body = {
        "size": 0,
        "query": {"range": {"@timestamp": {"gte": f"now-{FRESH_MINUTES}m"}}},
        "aggs": {"hosts": {
            "terms": {"field": "host.name", "size": 500},
            "aggs": {"namespaces": {"terms": {"field": "data_stream.namespace", "size": 50}}},
        }},
    }
    found = call(ctx, key, f"{es}/{METRICS}/_search?ignore_unavailable=true", body)
    return {b["key"]: {n["key"] for n in b["namespaces"]["buckets"]}
            for b in found["aggregations"]["hosts"]["buckets"]}


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--inventory", required=True, help="ansible-inventory --list output, or - for stdin")
    p.add_argument("--policies", default=POLICIES, help="the stacks/agent-policies directory")
    p.add_argument("--kibana", default=KIBANA)
    p.add_argument("--elasticsearch", default=ELASTICSEARCH)
    p.add_argument("--cacert", default=CA_CERT)
    args = p.parse_args()

    key = os.environ.get("ELASTICSEARCH_API_KEY")
    if not key:
        sys.exit("ELASTICSEARCH_API_KEY isn't set: run it through mise run check:telemetry")
    namespaces, listed = load_policies(args.policies)
    with sys.stdin if args.inventory == "-" else open(args.inventory, encoding="utf-8") as f:
        inventory = json.load(f)
    if not inventory.get("_meta", {}).get("hostvars"):
        sys.exit("FAIL  the inventory lists no VM (is PROXMOX_TOKEN_SECRET set?)")
    hosts = expected_hosts(inventory, listed)
    ctx = ssl.create_default_context(cafile=args.cacert)

    try:
        agents = fleet_agents(ctx, key, args.kibana.rstrip("/"))
        fresh = fresh_metrics(ctx, key, args.elasticsearch.rstrip("/"))
    except urllib.error.HTTPError as e:
        sys.exit(f"FAIL  {e.url}: HTTP {e.code}")
    except urllib.error.URLError as e:
        sys.exit(f"FAIL  Elastic not reached: {e.reason}")

    rc = 0
    by_host = {}
    for a in agents:
        by_host.setdefault(a.get("local_metadata", {}).get("host", {}).get("hostname"), []).append(a)
    for host, policy in hosts.items():
        if not policy:
            print(f"FAIL  {host}: no fleet_server_policy_id or elastic_agent_policy_id in its group_vars")
            rc = 1
            continue
        mine = by_host.get(host, [])
        if any(a.get("status") == "online" and a.get("policy_id") == policy for a in mine):
            print(f"ok    {host}: agent online in Fleet, policy {policy}")
        else:
            seen = ", ".join(f"{a.get('status')} on {a.get('policy_id')}" for a in mine) or "no agent"
            print(f"FAIL  {host}: no online agent on {policy} ({seen})")
            rc = 1
        namespace = namespaces.get(policy)
        if namespace is None:
            print(f"FAIL  {host}: policy {policy} has no system integration (or no stacks/agent-policies/{policy})")
            rc = 1
        elif namespace in fresh.get(host, set()):
            print(f"ok    {host}: host metrics in Elasticsearch, namespace {namespace}, in the last {FRESH_MINUTES} minutes")
        else:
            elsewhere = ", ".join(sorted(fresh.get(host, set())))
            print(f"FAIL  {host}: no host metrics in namespace {namespace} in the last {FRESH_MINUTES} minutes"
                  + (f" (only in {elsewhere})" if elsewhere else ""))
            rc = 1
    for host in sorted(h for h in by_host if h and h not in hosts):
        states = ", ".join(sorted({a.get("status", "?") for a in by_host[host]}))
        print(f"note  {host}: enrolled in Fleet ({states}), in no policy's hosts")
    return rc


if __name__ == "__main__":
    sys.exit(main())
