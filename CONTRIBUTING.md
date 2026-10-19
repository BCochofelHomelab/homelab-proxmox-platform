# Contributing

How a change gets into the platform, whether you make it or the AI agent
does. It's the same flow as
[`homelab-proxmox-core`](https://github.com/BCochofelHomelab/homelab-proxmox-core/blob/main/CONTRIBUTING.md),
whose docs also explain the AI agent's setup and the reasons behind it.

## How a change flows

Every change goes through a pull request, and only you merge.

- **The AI agent** works in its devcontainer, in its own clone
  (`~/Projects/ai-agent/homelab-proxmox-platform`), as its machine
  user, `bcochofel-ai-agent`. It branches, makes the change, runs the
  checks, pushes and opens the pull request. It can't push
  `.github/workflows/` (those changes go in the pull request's description,
  for you to commit), merge, approve, tag, apply, run a playbook, or open
  your secrets.
- **You** work in your own clone, as you, with the same branch, commit and
  pull request flow. Yours is the only lane that changes workflows,
  reviews, merges, applies and runs playbooks.

Every pull request needs your approval as code owner (`sre-lead`), and every
review conversation resolved. **Merge right after you approve**: once
approved, GitHub would let any user with Write merge, the machine user
included. Squash or rebase merges only (linear history).

## Docs

The README, this file and `docs/` (diagrams included) name no versions:
they're stale the day a version changes. Point to where the version is
pinned instead (`mise.toml`, `terramate.tm.hcl`, `group_vars/all.yml`,
a stack's `.terraform.lock.hcl`). Dates are fine where they record when
something was done.

## Branches

Short-lived branches off `main`, deleted after merge, named
`<prefix>/<description>` ([Conventional Branch](https://conventionalbranch.org/)):
`feature/` (or `feat/`), `bugfix/` (or `fix/`), `hotfix/`, `release/`,
`chore/`. Lowercase letters, numbers and hyphens only.

## Commits and releases

[Conventional Commits](https://www.conventionalcommits.org/), checked by
commitlint ([`commitlint.config.js`](commitlint.config.js)):
`<type>(optional scope): <subject>`, with type `feat`, `fix`, `docs`,
`style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` or `revert`.
`git commit` without `-m` opens the repo's template.

Every merge to `main` runs
[semantic-release](https://semantic-release.gitbook.io/)
([`.releaserc.js`](.releaserc.js)), which computes the version from the
commits since the last release, the same way as `homelab-proxmox-core`:

- `fix:` → patch, `feat:` → minor, `feat!:` or a `BREAKING CHANGE:`
  footer → major.
- `docs:`, `chore:`, `style:` and the rest → no release on their own.

It publishes a GitHub Release with generated notes and a tag, `X.Y.Z`
with no `v`. No changelog file and no commit back to `main`. With squash
merges, the pull request's title is the commit it reads.

## Checks

`mise install` installs the git hooks, so `git commit` runs
[`.pre-commit-config.yaml`](.pre-commit-config.yaml): file hygiene,
markdownlint, Terramate (fmt, generated code up to date), the workspace
contract, OpenTofu (fmt, validate, terraform-docs, TFLint, Trivy,
Checkov with homelab-proxmox-core's Proxmox policies), ansible-lint,
ShellCheck, gitleaks, SOPS files encrypted, actionlint and zizmor on
workflows, and commitlint. CI runs the same.

```bash
mise run lint      # every hook on every file
mise run check     # the above + gitleaks on the full history (what CI runs)
```

Four repo-specific rules the hooks enforce:

- **Namespace = workspace id.** A workspace is a folder under
  `workspaces/`, and its name, the id, matches `^[a-z0-9_]{1,64}$` and
  isn't `default`. Every namespace an agent policy or the ingest VM writes
  data with names an existing workspace
  ([`scripts/check_contract.py`](scripts/check_contract.py)).
- **Every `check_mode: false`** says why it's safe on the same line
  (`check_mode: false # read-only: ...`): a dry-run runs it for real.
- **A secret-named OpenTofu variable** (token, secret, password, hash,
  private key, API key) has no default and is `sensitive = true`. A name
  that only looks secret goes in the allowlist of
  [`scripts/check_secret_variables.py`](scripts/check_secret_variables.py),
  with the reason.
- **mise itself** is pinned once: `MISE_VERSION` in
  `.devcontainer/post-create.sh`, and `version:` in every workflow's
  `jdx/mise-action` step
  ([`scripts/check_mise_version.py`](scripts/check_mise_version.py)).

## Toolchain

Every command-line tool is pinned in [`mise.toml`](mise.toml), with each
download's checksum in `mise.lock`, at the same versions as
`homelab-proxmox-core`: your workstation, CI and the devcontainer run the
same versions. `mise tasks` lists the repo's commands.

| Tool | For |
| --- | --- |
| OpenTofu (`tofu`) | The stacks: VMs and Elastic content. |
| Terramate | Splits the platform into stacks and runs them in order. |
| Ansible, ansible-lint | Configuring the VMs; in `.venv/`, from `requirements.txt`. |
| TFLint, terraform-docs, Trivy, Checkov | Linting, docs and policy for the OpenTofu code. |
| ShellCheck, markdownlint-cli2, actionlint, zizmor | Shell scripts, Markdown, and GitHub workflows (lint and security). |
| gitleaks | No secret committed: staged changes, and the full history in CI. |
| SOPS, age | The inventory's encrypted secrets, and the AI agent's credentials in its devcontainer. |
| pre-commit, commitlint, semantic-release | Hooks, commit messages, releases. |
| GitHub CLI (`gh`) | Pull requests and runs; the machine user's in the devcontainer. |
| Python, uv, Node.js | The runtimes for `.venv/` and the Node-based hooks. |
| github-mcp-server, terraform-mcp-server, mcp-proxmox | The AI agent's read-only MCP servers. |

**Bumping a version:** nothing updates on its own (no Dependabot, no
Renovate). `mise run outdated` lists newer versions; edit the pin, then
`mise lock`, `mise run lint`, and commit the pin with its lockfile. Keep
versions in step with `homelab-proxmox-core`.
