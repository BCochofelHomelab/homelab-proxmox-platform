# Contributing

How a change gets from an idea to the platform. It follows
homelab-proxmox-core's CONTRIBUTING.md: the same two lanes (the AI agent
proposes as its machine user, you review, merge and apply), branch and
commit rules, and toolchain. This page lists what's different here.

## How a change flows

1. A branch off `main`, named `<type>/<short-description>`.
2. The change, usually data: a `workspace.yaml`, a dashboard export, a
   rule, an `agent-policy.yaml`. `mise run tm:generate` if it touched a
   `.tm.hcl` file or a `module_ref`.
3. `mise run check` and `mise run validate`: no credentials needed.
4. A pull request. CI runs the same checks.
5. You review, approve and merge, then apply from `main`:
   `mise run tofu:plan`, review each stack's plan, `mise run tofu:apply`,
   and `mise run ansible:site` when VMs changed.

The AI agent's lane stops at step 4: it can't push `.github/workflows/`
from its devcontainer, merge, approve, tag, decrypt your secrets or reach
a host.

## Commits and releases

Conventional Commits, checked by commitlint. semantic-release tags `main`
after each merge, unprefixed like core; the tags are a record of what was
merged, nothing pins them.

## Checks

| Check | Local | CI |
| --- | --- | --- |
| pre-commit: fmt, validate, tflint, trivy, checkov, ansible-lint, gitleaks, shellcheck, actionlint, zizmor, commitlint | on every commit | yes |
| Terramate formatting and up-to-date generated code | `mise run tm:check` | yes |
| namespace contract | `mise run contract` | yes |
| gitleaks over the full history | `mise run lint:secrets` | yes |
| `tofu validate` in every stack | `mise run validate` | via pre-commit |

## Toolchain

`mise trust && mise install`. Versions match homelab-proxmox-core's
`mise.toml`: bump them there and here together, then `mise lock` and
commit `mise.toml`, `mise.lock` and `.mise/locks/`.
