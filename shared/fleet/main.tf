# ----------------------------------------------------------------------------
# Fleet, platform-wide: the integration packages every agent policy uses,
# where agents enroll (Fleet Server) and where they send data (outputs),
# and Fleet Server's own agent policy. Host groups' agent policies are
# agent-policies/<group>/'s.
#
#   Fleet Server (kibana:8220) ──> Elasticsearch    default output (for now)
#
# Fleet Server only works with an Elasticsearch output. The Logstash output
# (agents ──mTLS──> ingest:5044) comes with the first host group's agent
# policy, made the default only after Fleet Server's policy has its
# integration: the Basic licence has no per-policy outputs.
#
# Enrolling Fleet Server is Ansible's (roles/fleet_server): run
# `mise run ansible:site` again once this stack is applied.
# ----------------------------------------------------------------------------

locals {
  ca_pem = trimspace(file("${path.module}/../../ansible/pki/elastic-ca.crt"))

  fleet_server_url = "https://192.168.68.33:8220" # kibana VM
  es_hosts         = ["https://192.168.68.30:9200", "https://192.168.68.31:9200", "https://192.168.68.32:9200"]

  # Fleet Server's own logs and metrics belong to the platform workspace
  # (namespace = workspace id).
  platform_namespace = "platform"
}

# -- Integration packages (versions compatible with Kibana 9.5.4) ----------------

resource "elasticstack_fleet_integration" "fleet_server" {
  name         = "fleet_server"
  version      = "1.6.1"
  skip_destroy = true
}

resource "elasticstack_fleet_integration" "system" {
  name         = "system"
  version      = "3.0.0"
  skip_destroy = true
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

  default_integrations = true
  default_monitoring   = true
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
  integration_name    = elasticstack_fleet_integration.fleet_server.name
  integration_version = elasticstack_fleet_integration.fleet_server.version
}

resource "elasticstack_fleet_integration_policy" "fleet_server_system" {
  name                = "system-fleet-server"
  namespace           = local.platform_namespace
  description         = "Host logs and metrics of the kibana VM"
  agent_policy_id     = elasticstack_fleet_agent_policy.fleet_server.policy_id
  integration_name    = elasticstack_fleet_integration.system.name
  integration_version = elasticstack_fleet_integration.system.version
}
