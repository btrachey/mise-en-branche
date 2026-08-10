# mise-en-branche — Claude Code Skill

This file documents the `mise-en-branche` project for Claude Code. Read it before making any changes to the codebase.

---

## Project overview

`mise-en-branche` is a git worktree manager built on top of **mise-en-place**. It manages bare git repositories where each branch lives in its own worktree directory. It integrates with GitHub (`gh` CLI), Linear (`linear-cli`), and Jira (direct REST API) for issue-driven branch creation, and with tmux, cmux, kitty, iTerm2, Alacritty, Ghostty, or WezTerm for automatic terminal window management.

---

## Repository layout

```
mise-en-branche/
├── mise.toml                  ← tool definitions, task declarations, env vars
├── README.md
├── CLAUDE.md                  ← this file
└── tasks/
    ├── init.sh                ← mise run init
    ├── add-worktree.sh        ← mise run add-worktree
    ├── rm-worktree.sh         ← mise run rm-worktree
    ├── prune.sh               ← mise run prune
    └── lib/
        ├── git.sh             ← git / worktree helpers
        ├── tracker.sh         ← issue tracker abstraction (github / linear / jira)
        ├── terminal.sh        ← terminal integration (tmux / cmux / kitty / iterm2 / alacritty / ghostty / wezterm)
        └── config.sh          ← configuration validation and defaults
```

### mise task files

Commands are declared in `mise.toml` using the [mise task file](https://mise.jdx.dev/tasks/file-tasks.html) convention: each script under `tasks/` is automatically picked up as a task. The `mise.toml` `[tasks]` section is used only for metadata (description, aliases) and is kept minimal.

```toml
[tools]
gum    = "latest"
glow   = "latest"
"cargo:linear-cli" = "latest"

[vars]
# Filled in by the user — see README

# Task metadata (scripts are auto-discovered from tasks/)
[tasks.init]
description = "Clone repo as bare and create main worktree"

[tasks.add-worktree]
description = "Create a new worktree (branch, issue, or interactive picker)"

[tasks.rm-worktree]
description = "Remove a worktree interactively or by identifier"

[tasks.prune]
description = "Remove worktrees for merged branches"
```

---

## Shell script conventions

- All scripts use `set -euo pipefail`
- Every script sources the lib files it needs at the top: `. "$(dirname "$0")/lib/config.sh"`
- Error messages → stderr (`echo "error: ..." >&2`); consumable output → stdout
- Use `gum` for all interactive prompts and pickers — not `fzf`, not raw `select`
- Use `glow` only for rendering Markdown content (e.g. displaying issue body)
- Never mutate `.bare/` directly — always use `git worktree` subcommands
- Branch slugification must be idempotent (same input → same output always), used for reverse lookup

---

## Configuration reference

Configuration is read from `mise.toml` via `[vars]`. All mise-managed variables are prefixed `MEB_`.

| Variable | Required | Values | Description |
|---|---|---|---|
| `MEB_REPO` | yes | `owner/repo` | GitHub repository |
| `MEB_TRACKER` | yes | `github` \| `linear` \| `jira` \| `none` | Issue tracker backend |
| `MEB_LINEAR_TEAM` | if linear | string | Linear team key (e.g. `PROJ`) |
| `MEB_JIRA_PROJECT` | if jira | string | Jira project key (e.g. `PROJ`) |
| `MEB_TERMINAL` | no | `tmux` \| `cmux` \| `kitty` \| `iterm2` \| `alacritty` \| `ghostty` \| `wezterm` \| `none` | Terminal to open on worktree creation |
| `MEB_DEFAULT_BRANCH` | no | branch name | Defaults to repo's default branch |
| `MEB_WORKTREE_PREFIX` | no | path prefix | Optional subdirectory for worktrees |

Jira credentials are deliberately **not** mise-managed — `JIRA_HOST`, `JIRA_EMAIL`, and `JIRA_API_TOKEN` are read directly from the ambient process environment (`${VAR:-}` in `config.sh`/`tracker.sh`), not from `[vars]`/`mise set`. This mirrors the `JIRA_HOST` convention used by other Jira CLI tools, so credentials can be shared across tools instead of being duplicated into `mise.toml`.

`config.sh` exports these variables and validates them at startup. Missing required variables print a clear error and exit 1.

---

## Commands

### `tasks/init.sh`

1. Calls `meb_config_validate`
2. Aborts if `.bare/` already exists
3. `gh repo clone --bare "$MEB_REPO" .bare`
4. Resolves default branch if `MEB_DEFAULT_BRANCH` is unset: `gh repo view "$MEB_REPO" --json defaultBranchRef --jq '.defaultBranchRef.name'`
5. Writes `.git` file at project root: `echo "gitdir: .bare" > .git`
6. `git -C .bare worktree add "../${MEB_DEFAULT_BRANCH}" "$MEB_DEFAULT_BRANCH"`
7. Prints resulting layout

---

### `tasks/add-worktree.sh`

**Argument parsing:**

| Arg | Description |
|---|---|
| *(none)* | Interactive issue picker via `gum` (see below) |
| `--branch <n>` | Use or create branch by name |
| `--gh <number>` | Resolve GitHub issue → branch |
| `--linear <id>` | Resolve Linear issue → branch |
| `--jira <key>` | Resolve Jira issue → branch |
| `--name <n>` | Free-form name → new branch |

**Interactive picker (no args):**

1. Calls `meb_issue_list` from `tracker.sh` → list of `ID\tTITLE` lines
2. Passes to `gum choose` for single selection
3. Extracts issue ID from selection, proceeds as `--gh`, `--linear`, or `--jira`

**Branch name derivation from issues:**
- GitHub: `gh issue view <number> --json title,number --jq '"gh-\(.number)/\(.title)"'` → slugify
- Linear: `linear issue <id>` → parse title → slugify → `<ID>/<slug>` (e.g. `PROJ-42/fix-login-timeout`)
- Jira: `GET {JIRA_HOST}/rest/api/3/issue/<key>?fields=summary` (Basic auth via `JIRA_EMAIL`/`JIRA_API_TOKEN`) → parse `.key`/`.fields.summary` with `jq` → slugify → `<key>/<slug>`
- Slugify function in `lib/git.sh`: lowercase, spaces→`-`, strip non-alphanumeric except `-`, truncate to 50 chars

**Worktree creation:**
```bash
local dir="${MEB_WORKTREE_PREFIX}${branch}"
git -C .bare worktree add "../${dir}" "$branch"
```

**Terminal integration** (delegates to `lib/terminal.sh → meb_open_window`):

| `MEB_TERMINAL` | Command |
|---|---|
| `tmux` | `tmux new-window -c "$worktree_path" -n "$branch"` |
| `cmux` | `cmux open "$worktree_path"` |
| `kitty` | `kitten @ launch --type=tab --tab-title "$branch" --cwd "$worktree_path"` |
| `iterm2` | `osascript` — create tab with `cd $worktree_path && exec $SHELL` |
| `alacritty` | `alacritty --title "$branch" --working-directory "$worktree_path"` |
| `ghostty` | `ghostty --working-directory="$worktree_path"` |
| `wezterm` | `wezterm cli spawn --cwd "$worktree_path"` then `wezterm cli set-tab-title --pane-id <id> "$branch"` |
| `none` | `echo "$worktree_path"` |

---

### `tasks/rm-worktree.sh`

**Argument parsing:**

| Arg | Description |
|---|---|
| *(none)* | Interactive multi-select via `gum choose --no-limit` |
| `<path>` | Worktree directory path |
| `--branch <n>` | Identify worktree by branch name |
| `--gh <number>` | Identify by GitHub issue (reverse slug lookup) |
| `--linear <id>` | Identify by Linear issue (reverse slug lookup) |
| `--jira <key>` | Identify by Jira issue (reverse slug lookup) |
| `--force` | Pass `--force` to `git worktree remove` |

**Interactive mode:**

1. `meb_list_worktrees` → lines of `BRANCH\tPATH\tSTATUS` (status: `clean`/`dirty`)
2. Format with awk for display, pipe to `gum choose --no-limit`
3. Extract paths from selection, proceed with removal for each

**Removal steps (per worktree):**
1. Confirm via `gum confirm` unless `--force`
2. `git -C .bare worktree remove [--force] "$path"`
3. `rm -rf "$path"` if directory still exists (git doesn't always clean up)

---

### `tasks/prune.sh`

**Flags:**

| Flag | Description |
|---|---|
| `--dry-run` | Print candidates, do nothing |
| `--yes` | Skip confirmation |

**Logic:**
1. `meb_list_worktrees` — exclude the default branch worktree
2. For each: `meb_branch_is_merged "$branch"` → boolean
3. Collect merged candidates
4. Display with `gum table` or formatted output
5. Confirm via `gum confirm` (unless `--yes`)
6. For each: `git -C .bare worktree remove "$path"` + `rm -rf "$path"`
7. `git -C .bare worktree prune` to clean stale metadata

---

## Library modules

### `tasks/lib/config.sh`

- `meb_config_validate` — checks required vars, exits 1 with descriptive error if missing
- `meb_default_branch` — returns `MEB_DEFAULT_BRANCH` or queries `gh repo view`

---

### `tasks/lib/git.sh`

All git operations target `.bare` explicitly via `git -C .bare`.

Key functions:
- `meb_git [args...]` — shorthand for `git -C .bare`
- `meb_list_worktrees` — parses `git worktree list --porcelain`, returns `BRANCH\tPATH\tDIRTY` lines
- `meb_worktree_path_for_branch(branch)` → path string or empty
- `meb_worktree_exists(branch)` → 0/1
- `meb_branch_is_merged(branch)` → 0/1 via `git branch --merged`
- `meb_slugify(str)` → branch-safe slug string

---

### `tasks/lib/tracker.sh`

Dispatches to GitHub, Linear, or Jira based on `MEB_TRACKER`.

Key functions:
- `meb_issue_to_branch(tracker, id)` → branch name string
- `meb_issue_list` → `ID\tTITLE` lines for open issues (used by interactive pickers)

GitHub implementation uses `gh issue list` and `gh issue view`.
Linear implementation uses `linear issue list` and `linear issue <id>`.
Jira implementation calls the Jira Cloud REST API directly (`curl` + `jq`, no CLI dependency):
- `_meb_jira_curl` — wraps `curl` with Basic auth (`JIRA_EMAIL`:`JIRA_API_TOKEN`, both read from the ambient environment)
- `meb_issue_list` → `POST {JIRA_HOST}/rest/api/3/search/jql` with a JQL body scoped to `MEB_JIRA_PROJECT` and `statusCategory != Done`
- `meb_issue_to_branch` → `GET {JIRA_HOST}/rest/api/3/issue/<key>?fields=summary`

The legacy `/rest/api/3/search` endpoint was fully retired by Atlassian in 2025 — always use `/rest/api/3/search/jql` for issue search. This integration targets Jira **Cloud** only (Basic auth + these endpoints don't apply to Server/Data Center).

---

### `tasks/lib/terminal.sh`

- `meb_open_window(path, name)` — dispatches on `MEB_TERMINAL`

cmux notes: use `cmux open <path>` to open a new window. Check `cmux` documentation if the API changes — the cmux CLI is newer and may evolve.

---

## Common pitfalls

- **`.git` file vs directory**: after `init`, the project root has a `.git` *file* pointing to `.bare/`. Tools that assume `.git` is a directory may misbehave. This is expected and correct for bare+worktree setups.
- **Worktree paths**: always use `../` relative to `.bare` when calling `git worktree add`. Worktrees must live outside the bare repo directory.
- **Linear CLI auth**: `linear auth` must be run once manually by the user. Do not attempt to automate authentication.
- **gh auth**: `gh auth status` must pass before `init`. The script checks this and prints a clear error if not.
- **Jira credentials**: `JIRA_HOST`, `JIRA_EMAIL`, and `JIRA_API_TOKEN` are read from the ambient process environment, not `mise.toml` — `init.sh` does not prompt for or persist them via `mise set`. Never route these through `[vars]`/`mise.local.toml`; the user is expected to `export` them (matching the convention other Jira CLI tools use). Only `MEB_JIRA_PROJECT` is mise-managed.
- **Default branch**: never hardcode `main` or `master`. Always resolve via `meb_default_branch`.
- **Slugify consistency**: the slug function is used both to create the branch name and to reverse-lookup a worktree from an issue ID. If the function changes, existing worktrees become un-resolvable. Treat it as stable API.
- **cmux**: as a newer tool, its CLI may evolve. Verify `cmux` invocation against its current documentation.
