stack {
  name        = "shared-fleet"
  description = "Fleet: integration packages, the Fleet Server host, the Elasticsearch output and Fleet Server's agent policy"
  tags        = ["elastic", "shared", "fleet"]
  after       = ["/shared/data"]
  id          = "7d205fc1-ceb2-4713-b3aa-f4a1b3f3bd6f"
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
