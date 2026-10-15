# Shared data plumbing: retention and parsing are platform-wide.
#
# Planned:
# - ILM policies and the @custom component templates that attach them
# - ingest pipelines, including the reroute processor in a @custom pipeline
#   that splits a shared APM Server's data per workspace (docs/WORKSPACES.md,
#   APM caveat). Verify before onboarding the first APM workspace.
#
# Templates match on dataset, never on a workspace: the namespace is the
# workspace, and retention doesn't depend on who owns the data.
