stack {
  name        = "shared-fleet"
  description = "Fleet: integration packages, the Fleet Server host, the Elasticsearch output and Fleet Server's agent policy"
  tags        = ["elastic", "shared", "fleet"]
  after       = ["/stacks/shared/data"]
  id          = "7d205fc1-ceb2-4713-b3aa-f4a1b3f3bd6f"
  # Files outside this folder that it reads: a change to one marks this
  # stack changed (mise run tofu:plan plans changed stacks only). The CA
  # and the agents' client certificate are in Fleet's outputs;
  # remote_monitoring_password is in elastic.sops.yaml.
  watch = [
    "/ansible/pki/elastic-ca.crt",
    "/ansible/pki/agent-client.crt",
    "/ansible/pki/agent-client.key.sops",
    "/ansible/inventory/group_vars/elastic.sops.yaml",
  ]
}

globals {
  # Decrypts the agents' client key (ansible/pki/agent-client.key.sops) at
  # plan time, with SOPS_AGE_KEY_FILE: your key, set by `mise run tofu:*`.
  extra_providers = {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4.1"
    }
  }
}
