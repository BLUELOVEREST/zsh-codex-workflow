# zsh-codex-workflow

A lightweight zsh plugin for Codex + tmux workflows on remote servers.

## Features

- `dev <dir>`: project mode (one tmux session per directory)
- `cx [dir]`: temporary mode (always reuse one shared session)
- `cwa [dir]`: smart mode (`git repo -> dev`, `non-git dir -> cx`)
- auto-resolve same-name project collisions (`project`, `project-2`, ...)
- each new session is bootstrapped with split panes:
  - top pane: normal shell
  - bottom pane: auto-start `codex`
- auto-configure tmux titles for iTerm2 tab display (default compact: `session | basename(path)`)
- `cxx`: reset temporary session
- `cwl`: list tmux sessions with path

## Requirements

- `zsh`
- `tmux`
- `codex` in `PATH`
- `git`

## Install (Oh My Zsh)

```bash
git clone <your-repo-url> ~/.oh-my-zsh/custom/plugins/codex-workflow
```

Add plugin name in `~/.zshrc`:

```bash
plugins=(... codex-workflow)
```

Reload shell:

```bash
source ~/.zshrc
```

## Usage

```bash
dev ~/workspace/project-a
cwa ~/workspace/project-a/subdir
cwa ~/tmp/some-folder
cx
cx ~/tmp/some-folder
cxx
cwl
```

## Optional config

Set temporary session name before plugin loads:

```bash
export CODEX_WORKFLOW_TEMP_SESSION="codex-temp"
```

Smart mode options:

```bash
# cwa in git repo uses repo root by default (1). Set 0 to use current dir.
export CODEX_WORKFLOW_SMART_REPO_ROOT=1

# session naming:
# basename (default): project
# parent_basename: parent_project (useful for same-name folders)
export CODEX_WORKFLOW_SESSION_NAME_MODE="basename"
```

Title options:

```bash
# 1 = enable tmux title integration for iTerm2 tabs (default), 0 = disable
export CODEX_WORKFLOW_ITERM_TITLE=1

# title mode:
# compact (default): session | current-dir-name
# full: session | full-path
# session: session only
export CODEX_WORKFLOW_TITLE_MODE="compact"
```

## Notes

- Run commands on the remote Ubuntu host (inside your SSH session).
- iTerm2 on macOS is only the terminal UI; tmux sessions live on the remote host.
- In iTerm2, tab title should include terminal title to display tmux-provided project/path.
