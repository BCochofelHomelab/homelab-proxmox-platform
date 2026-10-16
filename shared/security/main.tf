# ----------------------------------------------------------------------------
# Platform roles: the people who run the platform as a whole. Workspace
# roles (workspace-<id>-viewer/-editor) are each workspace's, created by
# terraform-elasticstack-workspace; nobody has access to a workspace by
# default.
#
# Users are the native realm's (homelab: no SSO): assign a role to a user
# in Kibana (Stack Management > Users). Service users that write data
# (logstash_writer, edot_writer) are Ansible's, next to the passwords
# they're created with.
# ----------------------------------------------------------------------------

locals {
  # Every data stream any workspace writes to: <type>-<dataset>-<namespace>.
  data_streams = ["logs-*-*", "metrics-*-*", "traces-*-*", "synthetics-*-*"]
}

# Runs the platform: every space, Fleet, Stack Management, and the
# cluster's own settings (ILM, templates, pipelines), but not security
# (users, roles, API keys stay with `elastic`).
resource "elasticstack_kibana_security_role" "platform_admin" {
  name        = "platform-admin"
  description = "Administers the platform: every Kibana space and feature, Fleet, ILM, index templates and ingest pipelines, every data stream. Not security."

  elasticsearch {
    cluster = ["monitor", "manage_ilm", "manage_index_templates", "manage_pipeline"]

    indices {
      names      = local.data_streams
      privileges = ["all"]
    }
  }

  kibana {
    base   = ["all"]
    spaces = ["*"]
  }
}

# Sees the whole platform: every space and every data stream, read-only.
resource "elasticstack_kibana_security_role" "platform_viewer" {
  name        = "platform-viewer"
  description = "Views the whole platform, read-only: every Kibana space, every data stream."

  elasticsearch {
    cluster = ["monitor"]

    indices {
      names      = local.data_streams
      privileges = ["read", "view_index_metadata"]
    }
  }

  kibana {
    base   = ["read"]
    spaces = ["*"]
  }
}
