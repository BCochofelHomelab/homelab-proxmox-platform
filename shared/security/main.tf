# Platform-wide IAM, owned by the platform team. Workspace roles are NOT
# here: the workspace module derives them per workspace.
#
# Planned (CLAUDE.md, migration order):
# - platform roles: platform_admin, platform_viewer
# - one service account / API key per stack, scoped to what that stack
#   manages (agent policies: Fleet only; workspaces: their own space and
#   saved objects, connectors, rules, roles, role mappings)
# - the SSO realm's role mappings for platform roles
#
# Until then every elasticstack stack uses the bootstrap API key from
# ~/.secrets/homelab.yaml (docs/STACKS.md, credentials).
