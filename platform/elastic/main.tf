# ----------------------------------------------------------------------------
# The Elastic VMs. The module call, provider and inputs are generated
# (terramate/vms.tm.hcl); this stack holds only its VMs. Everything inside
# them (packages, certificates, configuration, enrollment) is Ansible's.
#
# name => VM. `groups` become Proxmox tags, and the Ansible inventory groups
# the VM lands in. `data_disk` (GB) is a second disk, scsi1, created empty:
# Ansible formats it and mounts it where the service keeps its data
# (/var/lib/elasticsearch, /var/lib/logstash) before the service writes
# any. `disk` is the OS disk.
# ----------------------------------------------------------------------------

locals {
  vms = {
    "es-01" = { ip = "192.168.68.30", cores = 2, memory = 8192, disk = 50, data_disk = 200, groups = ["elasticsearch"] }
    "es-02" = { ip = "192.168.68.31", cores = 2, memory = 8192, disk = 50, data_disk = 200, groups = ["elasticsearch"] }
    "es-03" = { ip = "192.168.68.32", cores = 2, memory = 8192, disk = 50, data_disk = 200, groups = ["elasticsearch"] }
    # Kibana, and an Elastic Agent enrolled as Fleet Server.
    "kibana" = { ip = "192.168.68.33", cores = 2, memory = 4096, disk = 50, data_disk = null, groups = ["kibana_server", "fleet_server"] }
    # Logstash (its persistent queue on the data disk) and the EDOT Collector gateway (OTLP).
    "ingest" = { ip = "192.168.68.34", cores = 2, memory = 4096, disk = 50, data_disk = 50, groups = ["logstash", "edot_gateway"] }
  }
}
