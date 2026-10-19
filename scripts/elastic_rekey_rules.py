#!/usr/bin/env python3
"""Move every Kibana rule that runs on OpenTofu's API key to the current one.

A rule created through Kibana's API with an API key keeps that very key and
runs with it (Kibana 9.5.4, alerting's resolve_rule_api_key.ts): when the
key expires or is invalidated, those rules stop running. After a new
ELASTICSEARCH_API_KEY is in ~/.secrets/homelab.yaml, this asks Kibana to
re-key each such rule (POST .../rule/<id>/_update_api_key) with the new
key. Rules a person made in Kibana (api_key_created_by_user false) keep
their own key and are left alone. docs/ELASTIC-API-KEY.md, "Rotating it".

Usage, from the repo root, yours only (the key is in homelab.yaml):

  SOPS_AGE_KEY_FILE=~/.config/sops/age/bcochofel.txt \\
    sops exec-env ~/.secrets/homelab.yaml 'python scripts/elastic_rekey_rules.py'

--dry-run lists the rules without changing them. Prints ok/FAIL per rule,
never the key.
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
CA_CERT = "ansible/pki/elastic-ca.crt"
PER_PAGE = 100


def call(ctx, key, method, url):
    req = urllib.request.Request(url, method=method)
    req.add_header("Authorization", f"ApiKey {key}")
    req.add_header("kbn-xsrf", "true")
    with urllib.request.urlopen(req, context=ctx, timeout=30) as resp:
        body = resp.read()
    return json.loads(body) if body else None


def space_path(kibana, space):
    return kibana if space == "default" else f"{kibana}/s/{urllib.parse.quote(space)}"


def rules(ctx, key, base):
    page = 1
    while True:
        found = call(ctx, key, "GET", f"{base}/api/alerting/rules/_find?per_page={PER_PAGE}&page={page}")
        yield from found["data"]
        if page * PER_PAGE >= found["total"]:
            return
        page += 1


def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--kibana", default=KIBANA)
    p.add_argument("--cacert", default=CA_CERT)
    p.add_argument("--dry-run", action="store_true", help="list the rules, change nothing")
    args = p.parse_args()

    key = os.environ.get("ELASTICSEARCH_API_KEY")
    if not key:
        sys.exit("ELASTICSEARCH_API_KEY isn't set: run it through sops exec-env (see --help)")
    ctx = ssl.create_default_context(cafile=args.cacert)
    kibana = args.kibana.rstrip("/")

    try:
        return rekey(ctx, key, kibana, args.dry_run)
    except urllib.error.HTTPError as e:
        sys.exit(f"FAIL  {e.url}: HTTP {e.code}")
    except urllib.error.URLError as e:
        sys.exit(f"FAIL  {kibana} not reached: {e.reason}")


def rekey(ctx, key, kibana, dry_run):
    rc = 0
    spaces = [s["id"] for s in call(ctx, key, "GET", f"{kibana}/api/spaces/space")]
    for space in spaces:
        base = space_path(kibana, space)
        for rule in rules(ctx, key, base):
            name = f"{space}/{rule['id']}"
            if not rule.get("api_key_created_by_user"):
                print(f"skip  {name}: its key is Kibana's, not OpenTofu's")
                continue
            if dry_run:
                print(f"would {name} (owner {rule.get('api_key_owner')})")
                continue
            try:
                call(ctx, key, "POST", f"{base}/api/alerting/rule/{urllib.parse.quote(rule['id'])}/_update_api_key")
                print(f"ok    {name}")
            except urllib.error.HTTPError as e:
                print(f"FAIL  {name}: HTTP {e.code}")
                rc = 1
    return rc


if __name__ == "__main__":
    sys.exit(main())
