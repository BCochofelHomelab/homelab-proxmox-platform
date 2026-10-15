#!/usr/bin/env python3
"""Check the namespace contract between workspaces, agent policies and
shared Fleet configuration (docs/WORKSPACES.md). Fails on:

1. a workspace id (folder under workspaces/) that isn't ^[a-z0-9_]{1,64}$,
   or is `default`;
2. a workspace.yaml without an owner;
3. a read_from entry that names no existing workspace, or the workspace
   itself;
4. an agent policy, or one of its integrations, whose namespace names no
   existing workspace;
5. an integration whose package version differs from the one installed
   in shared/fleet/fleet.yaml;
6. a host group or workspace folder without a stack.tm.hcl.

Needs PyYAML (in the project .venv via requirements.txt).

Usage: check_contract.py (from the repo root; no arguments)
"""

import glob
import os
import re
import sys

import yaml

ID = re.compile(r"^[a-z0-9_]{1,64}$")


def load(path):
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def main():
    problems = []
    workspaces = {}
    for d in sorted(glob.glob("workspaces/*/")):
        wid = os.path.basename(d.rstrip("/"))
        if not ID.match(wid) or wid == "default":
            problems.append(f"{d}: workspace id must match ^[a-z0-9_]{{1,64}}$ and not be 'default'")
        if not os.path.exists(f"{d}stack.tm.hcl"):
            problems.append(f"{d}: no stack.tm.hcl")
        path = f"{d}workspace.yaml"
        if not os.path.exists(path):
            problems.append(f"{d}: no workspace.yaml")
            continue
        workspaces[wid] = load(path)
        if not str(workspaces[wid].get("owner") or "").strip():
            problems.append(f"{path}: owner is required (one accountable owner)")

    for wid, ws in workspaces.items():
        for other in ws.get("read_from") or []:
            if other == wid:
                problems.append(f"workspaces/{wid}/workspace.yaml: read_from names the workspace itself")
            elif other not in workspaces:
                problems.append(f"workspaces/{wid}/workspace.yaml: read_from '{other}' is not a workspace")

    fleet_path = "shared/fleet/fleet.yaml"
    installed = (load(fleet_path).get("integrations") or {}) if os.path.exists(fleet_path) else {}

    for d in sorted(glob.glob("agent-policies/*/")):
        if not os.path.exists(f"{d}stack.tm.hcl"):
            problems.append(f"{d}: no stack.tm.hcl")
        path = f"{d}agent-policy.yaml"
        if not os.path.exists(path):
            problems.append(f"{d}: no agent-policy.yaml")
            continue
        policy = load(path)
        ns = policy.get("namespace")
        if ns not in workspaces:
            problems.append(f"{path}: namespace '{ns}' is not a workspace")
        for key, integ in (policy.get("integrations") or {}).items():
            where = f"{path}: integrations.{key}"
            if integ.get("namespace") not in workspaces:
                problems.append(f"{where}: namespace '{integ.get('namespace')}' is not a workspace")
            pkg, ver = integ.get("package"), str(integ.get("version"))
            if pkg not in installed:
                problems.append(f"{where}: package '{pkg}' isn't installed in {fleet_path}")
            elif str(installed[pkg]) != ver:
                problems.append(f"{where}: version {ver} differs from {fleet_path}'s {installed[pkg]}")

    for p in problems:
        print(p)
    if problems:
        print("The namespace contract: docs/WORKSPACES.md.")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
