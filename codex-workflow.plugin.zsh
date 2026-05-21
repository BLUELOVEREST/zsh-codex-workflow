# zsh-codex-workflow
# Provides zellij-based Codex workflows for project and temporary contexts.

: "${CODEX_WORKFLOW_TEMP_SESSION:=codex-temp}"
: "${CODEX_WORKFLOW_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/codex-workflow}"
: "${CODEX_WORKFLOW_PICKER:=fzf}"

typeset -gA _CW_SESSION_PATHS

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

_cw_state_file() {
  print -- "$CODEX_WORKFLOW_STATE_DIR/project-sessions.tsv"
}

_cw_ensure_state_dir() {
  mkdir -p "$CODEX_WORKFLOW_STATE_DIR"
}

_cw_load_project_metadata() {
  typeset -gA _CW_SESSION_PATHS
  _CW_SESSION_PATHS=()

  local file
  file="$(_cw_state_file)"
  [[ -f "$file" ]] || return 0

  local session session_dir
  while IFS=$'\t' read -r session session_dir; do
    [[ -n "$session" && -n "$session_dir" ]] || continue
    _CW_SESSION_PATHS[$session]="$session_dir"
  done < "$file"
}

_cw_write_project_metadata() {
  local session="$1"
  local dir="$2"
  _cw_ensure_state_dir
  _cw_load_project_metadata
  _CW_SESSION_PATHS[$session]="$dir"

  local file key
  file="$(_cw_state_file)"
  : > "$file"
  for key in ${(ko)_CW_SESSION_PATHS}; do
    print -- "$key"$'\t'"${_CW_SESSION_PATHS[$key]}" >> "$file"
  done
}

_cw_remove_project_metadata() {
  local session="$1"
  _cw_load_project_metadata
  unset "_CW_SESSION_PATHS[$session]"

  local file key
  file="$(_cw_state_file)"
  _cw_ensure_state_dir
  : > "$file"
  for key in ${(ko)_CW_SESSION_PATHS}; do
    print -- "$key"$'\t'"${_CW_SESSION_PATHS[$key]}" >> "$file"
  done
}

_cw_session_name_from_dir() {
  local dir="$1"
  local base="${dir:t}"
  base="${base//./_}"
  base="${base//:/_}"
  base="${base//\//_}"
  print -- "$base"
}

_cw_resolve_project_session_name() {
  local dir="$1"
  _cw_load_project_metadata

  local key
  for key in ${(k)_CW_SESSION_PATHS}; do
    if [[ "${_CW_SESSION_PATHS[$key]}" == "$dir" ]]; then
      print -- "$key"
      return 0
    fi
  done

  local base candidate n
  base="$(_cw_session_name_from_dir "$dir")"
  candidate="$base"
  n=2

  while [[ -n "${_CW_SESSION_PATHS[$candidate]:-}" && "${_CW_SESSION_PATHS[$candidate]}" != "$dir" ]]; do
    candidate="${base}-${n}"
    n=$((n + 1))
  done

  print -- "$candidate"
}

_cw_layout_file_for_session() {
  local session="$1"
  _cw_ensure_state_dir
  print -- "$CODEX_WORKFLOW_STATE_DIR/${session}.kdl"
}

_cw_write_layout() {
  local session="$1"
  local dir="$2"
  local layout
  layout="$(_cw_layout_file_for_session "$session")"

  cat > "$layout" <<EOF
layout {
    tab name="$session" cwd="$dir" {
        pane split_direction="vertical" {
            pane cwd="$dir"
            pane cwd="$dir" command="codex"
        }
    }
}
EOF
}

_cw_log_action() {
  [[ -n "${CW_ZELLIJ_LOG:-}" ]] || return 0
  print -- "$*" >> "$CW_ZELLIJ_LOG"
}

_cw_list_sessions() {
  zellij list-sessions --short --no-formatting 2>/dev/null
}

_cw_has_session() {
  local session="$1"
  _cw_list_sessions | grep -Fxq -- "$session"
}

_cw_create_session() {
  local session="$1"
  local dir="$2"
  local kind="$3"
  _cw_write_layout "$session" "$dir"
  _cw_log_action "action=new-${kind}-session session=$session cwd=$dir"
  zellij --session "$session" --new-session-with-layout "$(_cw_layout_file_for_session "$session")"
}

_cw_attach_session() {
  local session="$1"
  local kind="$2"
  _cw_log_action "action=attach-${kind}-session session=$session"
  zellij attach "$session" --create-background=false
}

pj() {
  _cw_require_cmd zellij || return 1
  _cw_require_cmd codex || return 1

  local dir
  dir="$(_cw_abs_dir "$1")" || {
    echo "codex-workflow: invalid directory: ${1:-$PWD}" >&2
    return 1
  }

  local session
  session="$(_cw_resolve_project_session_name "$dir")"

  if _cw_has_session "$session"; then
    _cw_attach_session "$session" "project"
    return 0
  fi

  _cw_write_project_metadata "$session" "$dir"
  _cw_create_session "$session" "$dir" "project"
}

px() {
  _cw_require_cmd zellij || return 1
  _cw_require_cmd codex || return 1

  local dir
  dir="$(_cw_abs_dir "$1")" || {
    echo "codex-workflow: invalid directory: ${1:-$PWD}" >&2
    return 1
  }

  if _cw_has_session "$CODEX_WORKFLOW_TEMP_SESSION"; then
    _cw_attach_session "$CODEX_WORKFLOW_TEMP_SESSION" "temp"
    return 0
  fi

  _cw_create_session "$CODEX_WORKFLOW_TEMP_SESSION" "$dir" "temp"
}

pxr() {
  _cw_require_cmd zellij || return 1
  if _cw_has_session "$CODEX_WORKFLOW_TEMP_SESSION"; then
    zellij delete-session "$CODEX_WORKFLOW_TEMP_SESSION"
  fi
}

pjs() {
  _cw_load_project_metadata
  local key
  for key in ${(ko)_CW_SESSION_PATHS}; do
    print -- "$key | ${_CW_SESSION_PATHS[$key]}"
  done
}

pjp() {
  _cw_require_cmd "$CODEX_WORKFLOW_PICKER" || return 1
  _cw_load_project_metadata

  local entries selection dir
  entries="$(
    local key
    for key in ${(ko)_CW_SESSION_PATHS}; do
      print -- "$key | ${_CW_SESSION_PATHS[$key]}"
    done
  )"

  [[ -n "$entries" ]] || {
    echo "codex-workflow: no known project sessions" >&2
    return 1
  }

  selection="$(print -- "$entries" | /usr/bin/env PATH="$PATH" /bin/zsh -fc "$CODEX_WORKFLOW_PICKER")"
  [[ -n "$selection" ]] || return 1

  dir="${selection#* | }"
  pj "$dir"
}
