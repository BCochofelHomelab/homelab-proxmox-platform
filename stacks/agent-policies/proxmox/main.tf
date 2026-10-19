# The host group is its agent-policy.yaml; its code is generated, the same
# for every group (terramate/agent-policy.tm.hcl ->
# _terramate_generated_agent_policy.tf). Not generated itself: other stacks
# write their main.tf by hand, and `terramate run` refuses a stack holding a
# hand-written file that a generate block names.
