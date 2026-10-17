#!/usr/bin/env python3
"""Check every platform VM reports its telemetry: its Elastic Agent is
online in Fleet, on the policy its group_vars name, and its host metrics
reached Elasticsearch in the last few minutes (the whole path: agent,
Logstash, Elasticsearch). Read-only: GETs and one search.

The VMs come from Ansible's own inventory (Proxmox's, by tag), so a VM
added there is checked without editing this. The expected policy is
fleet_server_policy_id (the kibana VM) or elastic_agent_policy_id.

Usage, yours only (`mise run check:telemetry`, which runs):

  ansible-inventory --list | python scripts/check_telemetry.py --inventory -

with ELASTICSEARCH_API_KEY in the environment. Prints ok/FAIL per VM and
check, never the key; exits 1 on any FAIL.
"""

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request

KIBANA = "https://192.168.68.33:5601"
ELASTICSEARCH = "https://192.168.68.30:9200"
CA_CERT = "ansible/pki/elastic-ca.crt"
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


def expected_hosts(inventory):
    hosts = {}
    for name, hv in sorted(inventory.get("_meta", {}).get("hostvars", {}).items()):
        hosts[name] = hv.get("fleet_server_policy_id") or hv.get("elastic_agent_policy_id")
    return hosts


def fleet_agents(ctx, key, kibana):
    agents, page = [], 1
    while True:
        found = call(ctx, key, f"{kibana}/api/fleet/agents?perPage=100&page={page}")
        agents += found["items"]
        if page * 100 >= found["total"]:
            return agents
        page += 1


def fresh_hosts(ctx, key, es):
    body = {
        "size": 0,
        "query": {"range": {"@timestamp": {"gte": f"now-{FRESH_MINUTES}m"}}},
        "aggs": {"hosts": {"terms": {"field": "host.name", "size": 500}}},
    }
    found = call(ctx, key, f"{es}/{METRICS}/_search?ignore_unavailable=true", body)
    return {b["key"] for b in found["aggregations"]["hosts"]["buckets"]}


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--inventory", required=True, help="ansible-inventory --list output, or - for stdin")
    p.add_argument("--kibana", default=KIBANA)
    p.add_argument("--elasticsearch", default=ELASTICSEARCH)
    p.add_argument("--cacert", default=CA_CERT)
    args = p.parse_args()

    key = os.environ.get("ELASTICSEARCH_API_KEY")
    if not key:
        sys.exit("ELASTICSEARCH_API_KEY isn't set: run it through mise run check:telemetry")
    with sys.stdin if args.inventory == "-" else open(args.inventory, encoding="utf-8") as f:
        hosts = expected_hosts(json.load(f))
    if not hosts:
        sys.exit("FAIL  the inventory lists no VM (is PROXMOX_TOKEN_SECRET set?)")
    ctx = ssl.create_default_context(cafile=args.cacert)

    try:
        agents = fleet_agents(ctx, key, args.kibana.rstrip("/"))
        fresh = fresh_hosts(ctx, key, args.elasticsearch.rstrip("/"))
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
        if host in fresh:
            print(f"ok    {host}: host metrics in Elasticsearch in the last {FRESH_MINUTES} minutes")
        else:
            print(f"FAIL  {host}: no host metrics ({METRICS}) in the last {FRESH_MINUTES} minutes")
            rc = 1
    for host in sorted(h for h in by_host if h and h not in hosts):
        states = ", ".join(sorted({a.get("status", "?") for a in by_host[host]}))
        print(f"note  {host}: enrolled in Fleet ({states}), not a platform VM")
    return rc


if __name__ == "__main__":
    sys.exit(main())
