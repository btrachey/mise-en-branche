# mise-en-branche

> Git worktree management powered by [mise-en-place](https://mise.jdx.dev/).

`mise-en-branche` orchestrates git bare repositories and worktrees, with native integration for GitHub and Linear issue trackers, and terminal multiplexers (tmux, cmux, Ghostty).

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
- One or more of:
  - [tmux](https://github.com/tmux/tmux)
  - [cmux](https://cmux.com)
  - [Ghostty](https://ghostty.org/)
- For Linear support:
  - `linear-cli` — installed automatically via `cargo:linear-cli` in `mise.toml`

---

## Installation

```bash
git clone https://github.com/youruser/mise-en-branche
cd mise-en-branche
mise install
```

---

## Configuration

Configuration lives in `mise.toml` at the root of your project directory.

```toml
[tools]
gum    = "latest"
glow   = "latest"
"cargo:linear-cli" = "latest"

[vars]
# Required
MEB_REPO = "owner/repository"          # GitHub repository

# Issue tracker: "github" | "linear" | "none"
MEB_TRACKER = "linear"

# Linear-specific (required if MEB_TRACKER = "linear")
MEB_LINEAR_TEAM = "PROJ"               # Linear team key

# Terminal: "tmux" | "cmux" | "ghostty" | "none"
MEB_TERMINAL = "tmux"

# Optional
MEB_DEFAULT_BRANCH = "main"            # defaults to repo default branch
MEB_WORKTREE_PREFIX = ""               # e.g. "wt/" to namespace worktree dirs
```

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

# From a free-form name (creates a new branch)
mise run add-worktree -- --name my-experiment
```

**Behaviour:**
- Branch names are derived from the issue title when using `--gh`, `--linear`, or the interactive picker
- The worktree directory is created relative to the project root (or under `MEB_WORKTREE_PREFIX` if set)
- Once created, opens a new window/pane in the configured terminal (tmux, cmux, or Ghostty) pointed at the worktree directory

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

---

## Terminal integration

| Terminal | Behaviour |
|----------|-----------|
| `tmux`   | Creates a new tmux window named after the branch, cwd set to the worktree |
| `cmux`   | Opens a new cmux window in the worktree directory |
| `ghostty`| Opens a new Ghostty tab/window in the worktree directory |
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
