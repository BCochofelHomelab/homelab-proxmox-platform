# The workspace is its workspace.yaml (plus dashboards/ and rules/); its
# code is generated, the same for every workspace
# (stacks/workspaces/workspace.tm.hcl -> _terramate_generated_workspace.tf). Not
# generated itself: other stacks write their main.tf by hand, and
# `terramate run` refuses a stack holding a hand-written file that a
# generate block names.
