# Every host group's stack (agent-policies/*): a value in agent-policy.yaml
# written as `{secret: <key>}` is read from Ansible's
# ansible/inventory/group_vars/elastic.sops.yaml at plan time, decrypted with
# SOPS_AGE_KEY_FILE (your key, set by `mise run tofu:*`). One source for a
# secret both sides use: Ansible sets remote_monitoring_user's password from
# it, Fleet's integrations log in with it.
globals {
  extra_providers = {
    sops = {
      source  = "carlpett/sops"
      version = "~> 1.4.1"
    }
  }
}
