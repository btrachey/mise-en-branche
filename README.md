# mise-en-branche

> Git worktree management powered by [mise-en-place](https://mise.jdx.dev/).

`mise-en-branche` orchestrates git bare repositories and worktrees, with native integration for GitHub, Linear, and Jira issue trackers, and terminal multiplexers (tmux, cmux, Ghostty, WezTerm).

---

## Concepts

`mise-en-branche` works with **bare repositories**: the `.git` directory is stored in a `.bare/` subdirectory, and each branch lives in its own worktree directory alongside it. This allows switching contexts without stashing, and keeps your editor state intact per branch.

```
my-project/
├── .bare/          ← bare git repository
├── main/           ← worktree for main branch
├── feat/PROJ-42/   ← worktree for a Linear issue
└── fix/gh-123/     ← worktree for a GitHub issue
```

---

## Requirements

- [mise-en-place](https://mise.jdx.dev/) ≥ 2024.x
- [gh](https://cli.github.com/) — GitHub CLI (authenticated)
- [gum](https://github.com/charmbracelet/gum) — interactive prompts and pickers
- [glow](https://github.com/charmbracelet/glow) — Markdown rendering in terminal
- [jq](https://jqlang.org/) — JSON parsing for the Jira REST API integration
- One or more of:
  - [tmux](https://github.com/tmux/tmux)
  - [cmux](https://cmux.com)
  - [Ghostty](https://ghostty.org/)
  - [WezTerm](https://wezfurlong.org/wezterm/)
- For Linear support:
  - `linear-cli` — installed automatically via `cargo:linear-cli` in `mise.toml`
- For Jira support:
  - A Jira Cloud site and an [API token](https://id.atlassian.com/manage-profile/security/api-tokens) — no CLI needed, `mise-en-branche` talks to the Jira REST API directly

---

## Installation

`mise-en-branche` isn't cloned into your project — it's pulled in as a [remote task include](https://mise.jdx.dev/tasks/task-configuration.html), one of mise's experimental features. Your project keeps its own independent `.git` history; mise fetches the task scripts into its own cache directory and runs them with your project directory as the working directory, so there's no conflict with the `.git` gitdir-pointer file that `mise run init` creates for your bare repository.

Create a fresh project directory (or open an existing one you want to convert to the bare+worktree layout) and add a `mise.toml`:

```toml
[task_config]
includes = ["git::https://github.com/btrachey/mise-en-branche.git//.mise/tasks?ref=main"]

[tools]
gh    = "latest"
gum   = "latest"
glow  = "latest"
jq    = "latest"
"cargo:linear-cli" = "latest"

[env]
# Required
MEB_REPO = "owner/repository"          # GitHub repository

# Issue tracker: "github" | "linear" | "jira" | "none"
MEB_TRACKER = "linear"

# Linear-specific (required if MEB_TRACKER = "linear")
MEB_LINEAR_TEAM = "PROJ"               # Linear team key

# Jira-specific (required if MEB_TRACKER = "jira")
MEB_JIRA_PROJECT = "PROJ"              # Jira project key
# JIRA_HOST, JIRA_EMAIL, JIRA_API_TOKEN are NOT set here — export them in your
# shell environment instead (see "Jira" under Issue tracker integration below)

# Terminal: "tmux" | "cmux" | "ghostty" | "wezterm" | "none"
MEB_TERMINAL = "tmux"

# Optional
MEB_DEFAULT_BRANCH = "main"            # defaults to repo default branch
MEB_WORKTREE_PREFIX = ""               # e.g. "wt/" to namespace worktree dirs

[settings]
experimental = true   # required — remote git task includes are an experimental mise feature
```

Then:

```bash
mise trust
mise install
mise run init
```

Track `main` for the latest tasks, or pin to a released version by replacing `?ref=main` with a tag, e.g. `?ref=v0.1.0`.

---

## Commands

### `init`

Clones the repository as a bare repo into `.bare/` and creates the initial worktree for the main branch.

```bash
mise run init
```

- Uses `gh repo clone` under the hood
- Creates `.bare/` and a `<default-branch>/` worktree
- Writes a `.git` file pointing to `.bare/` so standard git tooling keeps working

---

### `add-worktree`

Creates a new worktree. Accepts a branch name, an issue reference, or a free-form name. With no arguments, opens an interactive issue picker.

```bash
# Interactive issue picker (uses gum)
mise run add-worktree

# From an existing or new branch
mise run add-worktree -- --branch feat/my-feature

# From a GitHub issue number
mise run add-worktree -- --gh 123

# From a Linear issue ID
mise run add-worktree -- --linear PROJ-42

# From a Jira issue key
mise run add-worktree -- --jira PROJ-42

# From a free-form name (creates a new branch)
mise run add-worktree -- --name my-experiment
```

**Behaviour:**
- Branch names are derived from the issue title when using `--gh`, `--linear`, or the interactive picker
- The worktree directory is created relative to the project root (or under `MEB_WORKTREE_PREFIX` if set)
- Once created, opens a new window/pane in the configured terminal (tmux, cmux, Ghostty, or WezTerm) pointed at the worktree directory

---

### `rm-worktree`

Removes one or more worktrees.

```bash
# By worktree path
mise run rm-worktree -- ./feat/my-feature

# By branch name
mise run rm-worktree -- --branch feat/my-feature

# By issue ID
mise run rm-worktree -- --linear PROJ-42
mise run rm-worktree -- --gh 123
mise run rm-worktree -- --jira PROJ-42

# Interactive multi-select (uses gum)
mise run rm-worktree

# Force removal (uncommitted changes discarded)
mise run rm-worktree -- --force
```

When called with no arguments, displays an interactive checklist of existing worktrees for selection.

---

### `prune`

Removes all worktrees whose branch has been merged into the default branch.

```bash
mise run prune

# Dry run — shows what would be removed
mise run prune -- --dry-run

# Skip confirmation prompt
mise run prune -- --yes
```

---

## Issue tracker integration

### GitHub

Uses the `gh` CLI. Authentication is delegated to `gh auth login`.

```bash
mise run add-worktree -- --gh 123
```

### Linear

Uses [`linear-cli`](https://github.com/Finesssee/linear-cli), installed via `cargo:linear-cli`.

```bash
# Authenticate once
linear auth

mise run add-worktree -- --linear PROJ-42
```

### Jira

Talks directly to the [Jira Cloud REST API](https://developer.atlassian.com/cloud/jira/platform/rest/v3/) (`/rest/api/3`) — no CLI dependency. Authentication is HTTP Basic auth using your Atlassian account email and an API token.

Credentials are read from the ambient environment, not `mise.toml` — export them in your shell (the same `JIRA_HOST` convention used by other Jira CLI tools, so you can share credentials across tools):

```bash
# Generate a token once at:
# https://id.atlassian.com/manage-profile/security/api-tokens

export JIRA_HOST="https://yourcompany.atlassian.net"
export JIRA_EMAIL="you@company.com"
export JIRA_API_TOKEN="..."

mise run add-worktree -- --jira PROJ-42
```

Jira Server / Data Center is not supported — only Jira Cloud sites.

---

## Terminal integration

| Terminal | Behaviour |
|----------|-----------|
| `tmux`   | Creates a new tmux window named after the branch, cwd set to the worktree |
| `cmux`   | Opens a new cmux window in the worktree directory |
| `ghostty`| Opens a new Ghostty tab/window in the worktree directory |
| `wezterm`| Spawns a new WezTerm tab (via `wezterm cli`) and titles it after the branch |
| `none`   | Skips terminal integration; prints the worktree path to stdout |

---

## Tips

- `mise run add-worktree` with no arguments opens an interactive picker listing open issues from your configured tracker.
- Use `MEB_WORKTREE_PREFIX = "wt/"` to keep worktrees in a subdirectory and reduce clutter at project root.
- `mise run prune --dry-run` is safe to run frequently to audit stale worktrees.
- `glow` is available in your PATH after `mise install` — use it to read this README in the terminal: `glow README.md`.

---

## License

MIT
