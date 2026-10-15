# Ansible

Ansible configures the VMs that `platform/` (and `apps/k3s`) create. It is
not a Terramate stack: change detection can't see what it depends on, and
it runs between layers, after the VMs exist and before `shared/` needs a
live cluster.

## Inventory from Proxmox tags

`ansible/inventory/proxmox.yml` is a dynamic inventory: it asks Proxmox
for VMs tagged `platform` and groups them by their other tags. Each VM
stack tags its VMs `["terraform", "platform", "<role>"]`, so the groups are
`elasticsearch`, `kibana`, `fleet_server` and `logstash`. The address comes
from the QEMU guest agent.

Unlike homelab-proxmox-core, whose inventory is generated from OpenTofu
state, **Ansible never reads OpenTofu state here**. A VM stack and its
playbook stay decoupled, and the inventory needs only a read-only Proxmox
token (`~/.secrets/homelab-ro.yaml`).

## What moves here

From homelab-proxmox-workloads: the Elasticsearch, Kibana, Fleet Server and
Logstash roles. The Logstash role ships its pipelines, and every pipeline
that writes to Elasticsearch sets the data stream namespace of the
workspace it serves (docs/WORKSPACES.md).

## Enrollment

Hosts enroll in their host group's agent policy, whose id is the
`agent-policies/<group>/` folder name. The enrollment token stays out of
OpenTofu outputs: the Elastic Agent role looks it up from the Fleet API by
policy id (`GET /api/fleet/enrollment_api_keys`), with a Fleet-scoped API
key from the role's SOPS-encrypted group vars.
