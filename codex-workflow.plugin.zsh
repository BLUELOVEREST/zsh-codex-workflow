# zsh-codex-workflow
# Provides tmux-based Codex workflows for project and temporary contexts.

# Optional defaults (can be overridden in .zshrc before loading plugin)
: "${CODEX_WORKFLOW_TEMP_SESSION:=codex-temp}"
: "${CODEX_WORKFLOW_SMART_REPO_ROOT:=1}"
: "${CODEX_WORKFLOW_ITERM_TITLE:=1}"
: "${CODEX_WORKFLOW_TITLE_MODE:=compact}"
: "${CODEX_WORKFLOW_SESSION_NAME_MODE:=basename}"

_cw_require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "codex-workflow: missing required command: $cmd" >&2
    return 1
  fi
}

_cw_abs_dir() {
  local dir="${1:-$PWD}"
  cd "$dir" 2>/dev/null && pwd
}

_cw_session_name_from_dir() {
  local dir="$1"
  local mode="$CODEX_WORKFLOW_SESSION_NAME_MODE"
  local base
  local parent
  local raw
  base="$(basename "$dir")"
  parent="$(basename "$(dirname "$dir")")"
  case "$mode" in
    parent_basename) raw="${parent}_${base}" ;;
    basename|*) raw="${base}" ;;
  esac
  # tmux session names cannot include ':' and are easier to manage without '.'
  echo "$raw" | tr '.:' '__'
}

_cw_get_session_path() {
  local name="$1"
  tmux display-message -p -t "$name" "#{session_path}" 2>/dev/null
}

_cw_resolve_session_name() {
  local dir="$1"
  local base
  local candidate
  local current_path
  local n
  base="$(_cw_session_name_from_dir "$dir")"
  candidate="$base"
  n=2

  while tmux has-session -t "$candidate" 2>/dev/null; do
    current_path="$(_cw_get_session_path "$candidate")"
    if [[ "$current_path" = "$dir" ]]; then
      echo "$candidate"
      return 0
    fi
    candidate="${base}-${n}"
    n=$((n + 1))
  done

  echo "$candidate"
}

_cw_switch_or_attach() {
  local name="$1"
  if [[ -n "$TMUX" ]]; then
    tmux switch-client -t "$name"
  else
    tmux attach -t "$name"
  fi
}

_cw_bootstrap_session() {
  local name="$1"
  local dir="$2"

  tmux new-session -d -s "$name" -c "$dir"
  tmux split-window -v -t "$name":0 -c "$dir"
  tmux send-keys -t "$name":0.1 "codex" C-m
  tmux select-pane -t "$name":0.0
}

_cw_configure_titles() {
  [[ "$CODEX_WORKFLOW_ITERM_TITLE" = "1" ]] || return 0
  local title_fmt
  case "$CODEX_WORKFLOW_TITLE_MODE" in
    full) title_fmt='#S | #{pane_current_path}' ;;
    session) title_fmt='#S' ;;
    compact|*) title_fmt='#S | #{b:pane_current_path}' ;;
  esac
  # Let tmux push session/path into terminal title (shown by iTerm2 tab title if configured).
  tmux set-option -g set-titles on >/dev/null
  tmux set-option -g set-titles-string "$title_fmt" >/dev/null
  tmux set-window-option -g automatic-rename on >/dev/null
  tmux set-window-option -g automatic-rename-format '#{b:pane_current_path}' >/dev/null
}

_cw_git_repo_root() {
  local dir="$1"
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null
}

# dev <dir>
# Project mode: one tmux session per directory.
dev() {
  _cw_require_cmd tmux || return 1
  _cw_require_cmd codex || return 1

  local dir
  dir="$(_cw_abs_dir "$1")" || {
    echo "codex-workflow: invalid directory: ${1:-$PWD}" >&2
    return 1
  }

  local name
  name="$(_cw_resolve_session_name "$dir")"

  if ! tmux has-session -t "$name" 2>/dev/null; then
    _cw_bootstrap_session "$name" "$dir" || return 1
  fi

  _cw_configure_titles
  _cw_switch_or_attach "$name"
}

# cx [dir]
# Temporary mode: always uses one shared session.
cx() {
  _cw_require_cmd tmux || return 1
  _cw_require_cmd codex || return 1

  local dir
  dir="$(_cw_abs_dir "$1")" || {
    echo "codex-workflow: invalid directory: ${1:-$PWD}" >&2
    return 1
  }

  local name="$CODEX_WORKFLOW_TEMP_SESSION"

  if ! tmux has-session -t "$name" 2>/dev/null; then
    _cw_bootstrap_session "$name" "$dir" || return 1
  else
    # Re-point the codex pane to the target directory.
    tmux send-keys -t "$name":0.1 C-c "cd \"$dir\"" C-m
  fi

  _cw_configure_titles
  _cw_switch_or_attach "$name"
}

# cwa [dir]
# Smart mode: git repo -> dev, non-git dir -> cx.
cwa() {
  _cw_require_cmd git || return 1

  local dir
  dir="$(_cw_abs_dir "$1")" || {
    echo "codex-workflow: invalid directory: ${1:-$PWD}" >&2
    return 1
  }

  local root
  root="$(_cw_git_repo_root "$dir")"
  if [[ -n "$root" ]]; then
    if [[ "$CODEX_WORKFLOW_SMART_REPO_ROOT" = "1" ]]; then
      dev "$root"
    else
      dev "$dir"
    fi
  else
    cx "$dir"
  fi
}

# cxx
# Reset temporary session.
cxx() {
  _cw_require_cmd tmux || return 1

  local name="$CODEX_WORKFLOW_TEMP_SESSION"
  tmux has-session -t "$name" 2>/dev/null || return 0
  tmux kill-session -t "$name"
}

# cwl
# List current tmux sessions.
cwl() {
  _cw_require_cmd tmux || return 1
  tmux list-sessions -F "#{session_name} | #{session_path} | #{session_windows} windows"
}
