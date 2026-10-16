# ----------------------------------------------------------------------------
# The Elastic VMs. The module call, provider and inputs are generated
# (terramate/vms.tm.hcl); this stack holds only its VMs. Everything inside
# them (packages, certificates, configuration, enrollment) is Ansible's.
#
# name => VM. `groups` become Proxmox tags, and the Ansible inventory groups
# the VM lands in. Data lives on the one disk: core's VM module has no
# second one.
# ----------------------------------------------------------------------------

locals {
  vms = {
    "es-01" = { ip = "192.168.68.30", cores = 2, memory = 8192, disk = 250, groups = ["elasticsearch"] }
    "es-02" = { ip = "192.168.68.31", cores = 2, memory = 8192, disk = 250, groups = ["elasticsearch"] }
    "es-03" = { ip = "192.168.68.32", cores = 2, memory = 8192, disk = 250, groups = ["elasticsearch"] }
    # Kibana, and an Elastic Agent enrolled as Fleet Server.
    "kibana" = { ip = "192.168.68.33", cores = 2, memory = 4096, disk = 50, groups = ["kibana_server", "fleet_server"] }
    # Logstash (with its persistent queue) and the EDOT Collector gateway (OTLP).
    "ingest" = { ip = "192.168.68.34", cores = 2, memory = 4096, disk = 100, groups = ["logstash", "edot_gateway"] }
  }
}
