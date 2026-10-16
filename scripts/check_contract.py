#!/usr/bin/env python3
"""Check the one contract between this repo and the workspace module:
namespace = workspace id.

- A workspace is a folder under workspaces/; its name is its id. Ids match
  ^[a-z0-9_]{1,64}$ (a data stream namespace can't hold a hyphen) and are
  never "default". A workspace.yaml that sets `id` sets the folder's name.
- Every namespace data is written with names an existing workspace. A
  namespace is the value of any `namespace` key, at any depth, in
  agent-policies/*/agent-policy.yaml, and of any key named `namespace` or
  ending in `_namespace` in ansible/inventory/group_vars/*.yml (Logstash
  and the EDOT gateway). A value holding a Jinja expression is skipped: it
  resolves to one of the checked ones.

A baseline rule in the platform workspace catches whatever slips past
this: data arriving in a namespace with no workspace.

Usage: check_contract.py (from the repo root; takes no file arguments)
"""

import re
import sys
from pathlib import Path

import yaml

WORKSPACE_ID = re.compile(r"^[a-z0-9_]{1,64}$")
NAMESPACE_KEY = re.compile(r"^(.*_)?namespace$")


def walk(node, key_pattern, where):
    """Yield (where, value) for every string value under a matching key."""
    if isinstance(node, dict):
        for key, value in node.items():
            here = f"{where}.{key}"
            if isinstance(key, str) and key_pattern.match(key) and isinstance(value, str):
                yield here, value
            else:
                yield from walk(value, key_pattern, here)
    elif isinstance(node, list):
        for i, item in enumerate(node):
            yield from walk(item, key_pattern, f"{where}[{i}]")


def load(path):
    with path.open(encoding="utf-8") as f:
        return yaml.safe_load(f)


def main():
    errors = []

    workspaces = set()
    for folder in sorted(p for p in Path("workspaces").glob("*") if p.is_dir()):
        wid = folder.name
        if not WORKSPACE_ID.match(wid):
            errors.append(f"{folder}: workspace id must match {WORKSPACE_ID.pattern}")
        if wid == "default":
            errors.append(f"{folder}: \"default\" can't be a workspace id")
        spec = folder / "workspace.yaml"
        if spec.exists():
            declared = (load(spec) or {}).get("id", wid)
            if declared != wid:
                errors.append(f"{spec}: id {declared!r} isn't the folder's name, {wid!r}")
        workspaces.add(wid)

    sources = [(p, re.compile(r"^namespace$")) for p in sorted(Path("agent-policies").glob("*/agent-policy.yaml"))]
    sources += [
        (p, NAMESPACE_KEY)
        for p in sorted(Path("ansible/inventory/group_vars").glob("*.yml"))
        if not p.name.endswith(".sops.yml")
    ]
    for path, key_pattern in sources:
        for where, namespace in walk(load(path), key_pattern, ""):
            if "{{" in namespace:
                continue
            if namespace not in workspaces:
                errors.append(f"{path}: {where.lstrip('.')} = {namespace!r} names no workspace (workspaces/{namespace}/)")

    for error in errors:
        print(error)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
