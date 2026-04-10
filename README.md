# zsh-codex-workflow

A lightweight zsh plugin for `codex + zellij` workflows on remote servers.

## What It Does

The plugin gives you two fast entry modes:

- project sessions: one zellij session per project directory
- temporary session: one reusable scratch session

Each new session starts with a fixed two-pane layout:

- top pane: shell in the target directory
- bottom pane: `codex` in the same directory

The main goal is fast multi-project switching without manually rebuilding the same workspace layout every time.

## Commands

- `pj <dir>`: enter or create a project zellij session for a directory
- `px [dir]`: enter or create the shared temporary zellij session
- `pjs`: list known project sessions and directories
- `pjp`: choose a known project session from a picker command
- `pxr`: reset the shared temporary session

## Requirements

- `zsh`
- `zellij`
- `codex` in `PATH`
- optional picker command for `pjp`
  - default: `fzf`
  - override with `CODEX_WORKFLOW_PICKER`

## Install

```bash
git clone <your-repo-url> ~/.oh-my-zsh/custom/plugins/codex-workflow
```

In `~/.zshrc`:

```bash
plugins=(... codex-workflow)
```

Reload your shell:

```bash
source ~/.zshrc
```

## Usage

Open or create a project session:

```bash
pj ~/workspace/project-a
```

Open or create the shared temporary session:

```bash
px
px ~/tmp/scratch-dir
```

List known project sessions:

```bash
pjs
```

Pick and enter a known project session:

```bash
pjp
```

Reset the shared temporary session:

```bash
pxr
```

## Configuration

Temporary session name:

```bash
export CODEX_WORKFLOW_TEMP_SESSION="codex-temp"
```

State directory for project metadata and generated zellij layouts:

```bash
export CODEX_WORKFLOW_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/codex-workflow"
```

Picker command used by `pjp`:

```bash
export CODEX_WORKFLOW_PICKER="fzf"
```

## Notes

- The plugin is now zellij-first. The old tmux-oriented command model is no longer the primary workflow.
- Project session names are derived from directory names and get numeric suffixes when collisions occur.
- The temporary session is intentionally not repointed automatically. Use `pxr` before `px <dir>` when you want a fresh scratch context.
