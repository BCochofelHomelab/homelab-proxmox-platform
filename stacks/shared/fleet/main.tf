# ----------------------------------------------------------------------------
# Fleet, platform-wide: the integration packages every agent policy uses,
# where agents enroll (Fleet Server) and where they send data (outputs),
# and Fleet Server's own agent policy. Host groups' agent policies are
# agent-policies/<group>/'s.
#
#   agents ──mTLS──> Logstash (ingest:5044) ──> Elasticsearch   default output
#   Fleet Server (kibana:8220) ─────────────> Elasticsearch     its own policy
#
# Fleet Server only works with an Elasticsearch output, and the Basic
# licence has no per-policy outputs. So the order matters: Fleet Server's
# policy has its integration while Elasticsearch is still the default, and
# only then is Logstash made the default; Fleet keeps the Elasticsearch
# output for a policy with Fleet Server in it (depends_on below).
#
# Enrolling Fleet Server is Ansible's (roles/fleet_server): run
# `mise run ansible:site` again once this stack is applied.
# ----------------------------------------------------------------------------

locals {
  pki    = "${path.module}/../../../ansible/pki"
  ca_pem = trimspace(file("${local.pki}/elastic-ca.crt"))
  # The agents' shared client certificate for Logstash's mTLS
  # (`mise run pki:agent-client`, once).
  agent_client_crt_pem = trimspace(file("${local.pki}/agent-client.crt"))

  fleet_server_url = "https://192.168.68.33:8220" # kibana VM
  es_hosts         = ["https://192.168.68.30:9200", "https://192.168.68.31:9200", "https://192.168.68.32:9200"]
  logstash_host    = "192.168.68.34:5044" # ingest VM

  # Fleet Server's own logs and metrics belong to the platform workspace
  # (namespace = workspace id).
  platform_namespace = "platform"
}

# remote_monitoring_user's password (Kibana's stack monitoring, below):
# Ansible's group_vars/elastic.sops.yaml, the file Ansible sets it from.
data "sops_file" "elastic" {
  source_file = "${path.module}/../../../ansible/inventory/group_vars/elastic.sops.yaml"
}

# The agents' client key, decrypted with your age key (stack.tm.hcl).
data "sops_file" "agent_client_key" {
  source_file = "${local.pki}/agent-client.key.sops"
  input_type  = "raw"
}

# -- Integration packages (global.fleet_packages, terramate.tm.hcl) ---------------

# Every package the platform uses, at its one version: agent policies'
# integrations (agent-policies/*) and Fleet Server's (below) pick them by
# name. Adding a package is one line in the global.
resource "elasticstack_fleet_integration" "packages" {
  for_each = local.fleet_packages

  name         = each.key
  version      = each.value
  skip_destroy = true
}

moved {
  from = elasticstack_fleet_integration.fleet_server
  to   = elasticstack_fleet_integration.packages["fleet_server"]
}

moved {
  from = elasticstack_fleet_integration.system
  to   = elasticstack_fleet_integration.packages["system"]
}

moved {
  from = elasticstack_fleet_integration.monitoring["elasticsearch"]
  to   = elasticstack_fleet_integration.packages["elasticsearch"]
}

moved {
  from = elasticstack_fleet_integration.monitoring["kibana"]
  to   = elasticstack_fleet_integration.packages["kibana"]
}

moved {
  from = elasticstack_fleet_integration.monitoring["logstash"]
  to   = elasticstack_fleet_integration.packages["logstash"]
}

# -- Fleet Server -------------------------------------------------------------------

resource "elasticstack_fleet_server_host" "kibana" {
  host_id = "fleet-server-kibana"
  name    = "Fleet Server (kibana)"
  hosts   = [local.fleet_server_url]
  default = true
}

# -- Outputs ------------------------------------------------------------------------

# Fleet's own default output, created by Fleet's setup (roles/kibana runs
# it), adopted here: every Elasticsearch node, verified against the
# internal CA.
import {
  to = elasticstack_fleet_output.elasticsearch
  id = "fleet-default-output"
}

resource "elasticstack_fleet_output" "elasticsearch" {
  output_id = "fleet-default-output"
  name      = "Elasticsearch"
  type      = "elasticsearch"
  hosts     = local.es_hosts

  ssl = {
    certificate_authorities = [local.ca_pem]
    verification_mode       = "full"
  }

  # Logstash is the default (below); Fleet Server's policy keeps this one.
  default_integrations = false
  default_monitoring   = false

  depends_on = [elasticstack_fleet_output.logstash]
}

# Every agent's output (data and monitoring): Logstash, mTLS with the
# agents' shared client certificate. Logstash routes each event to the data
# stream the agent set (data_stream.*, the integration's namespace).
resource "elasticstack_fleet_output" "logstash" {
  output_id = "logstash-ingest"
  name      = "Logstash (ingest)"
  type      = "logstash"
  hosts     = [local.logstash_host]

  ssl = {
    certificate_authorities = [local.ca_pem]
    certificate             = local.agent_client_crt_pem
    key                     = trimspace(data.sops_file.agent_client_key.raw)
    verification_mode       = "full"
  }

  default_integrations = true
  default_monitoring   = true

  # Only once Fleet Server's policy has its integration (see the top).
  depends_on = [
    elasticstack_fleet_integration_policy.fleet_server,
    elasticstack_fleet_integration_policy.fleet_server_system,
  ]
}

# -- Fleet Server's agent policy ----------------------------------------------------

# roles/fleet_server enrolls the kibana VM into this policy (fleet_server_policy_id,
# group_vars/fleet_server.yml).
resource "elasticstack_fleet_agent_policy" "fleet_server" {
  policy_id            = "fleet-server-policy"
  name                 = "Fleet Server"
  namespace            = local.platform_namespace
  description          = "Fleet Server on the kibana VM (homelab-proxmox-platform, shared/fleet)"
  monitor_logs         = true
  monitor_metrics      = true
  fleet_server_host_id = elasticstack_fleet_server_host.kibana.host_id
}

resource "elasticstack_fleet_integration_policy" "fleet_server" {
  name                = "fleet-server"
  namespace           = local.platform_namespace
  description         = "Fleet Server, port 8220"
  agent_policy_id     = elasticstack_fleet_agent_policy.fleet_server.policy_id
  integration_name    = elasticstack_fleet_integration.packages["fleet_server"].name
  integration_version = elasticstack_fleet_integration.packages["fleet_server"].version
}

resource "elasticstack_fleet_integration_policy" "fleet_server_system" {
  name                = "system-fleet-server"
  namespace           = local.platform_namespace
  description         = "Host logs and metrics of the kibana VM"
  agent_policy_id     = elasticstack_fleet_agent_policy.fleet_server.policy_id
  integration_name    = elasticstack_fleet_integration.packages["system"].name
  integration_version = elasticstack_fleet_integration.packages["system"].version
}

# Kibana's stack monitoring and logs: the kibana VM is Fleet Server's host.
# Kibana listens on the VM's address over HTTPS (not localhost), verified
# against the internal CA (Fleet Server's copy, roles/fleet_server).
locals {
  kibana_monitoring_vars = jsonencode({
    hosts    = ["https://192.168.68.33:5601"]
    username = "remote_monitoring_user"
    password = data.sops_file.elastic.data["remote_monitoring_password"]
    ssl      = "certificate_authorities: [\"/etc/fleet-server/certs/ca.crt\"]\n"
  })
}

resource "elasticstack_fleet_integration_policy" "fleet_server_kibana" {
  name                = "kibana-fleet-server"
  namespace           = local.platform_namespace
  description         = "Stack monitoring and logs of Kibana"
  agent_policy_id     = elasticstack_fleet_agent_policy.fleet_server.policy_id
  integration_name    = elasticstack_fleet_integration.packages["kibana"].name
  integration_version = elasticstack_fleet_integration.packages["kibana"].version

  inputs = {
    "kibana-kibana/metrics" = { enabled = true, vars = local.kibana_monitoring_vars }
    "kibana-http/metrics"   = { enabled = true, vars = local.kibana_monitoring_vars }
  }
}
