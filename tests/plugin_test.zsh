#!/usr/bin/env zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PLUGIN_FILE="$ROOT/codex-workflow.plugin.zsh"
TMP_ROOT="$ROOT/tests/tmp"

_fail() {
  print -u2 -- "FAIL: $1"
  exit 1
}

_assert_eq() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  [[ "$actual" == "$expected" ]] || _fail "$msg (expected: $expected, actual: $actual)"
}

_assert_match() {
  local value="$1"
  local pattern="$2"
  local msg="$3"
  [[ "$value" == ${~pattern} ]] || _fail "$msg (value: $value, pattern: $pattern)"
}

run_test_session_name_collision() {
  local workspace="$TMP_ROOT/session-name"
  rm -rf "$workspace"
  mkdir -p "$workspace/api" "$workspace/alt/api"

  source "$PLUGIN_FILE"
  typeset -gA _CW_SESSION_PATHS
  _CW_SESSION_PATHS=(api "$workspace/api")

  local resolved
  resolved="$(_cw_resolve_project_session_name "$workspace/alt/api")"
  _assert_eq "api-2" "$resolved" "collision should append numeric suffix"
}

run_test_project_metadata_roundtrip() {
  local workspace="$TMP_ROOT/metadata"
  rm -rf "$workspace"
  mkdir -p "$workspace"

  source "$PLUGIN_FILE"
  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"

  _cw_write_project_metadata "api" "$workspace/project-api"
  _cw_load_project_metadata

  _assert_eq "$workspace/project-api" "${_CW_SESSION_PATHS[api]}" "metadata should reload saved path"
}

run_test_pj_creates_layout_for_new_project() {
  local workspace="$TMP_ROOT/pj-create"
  rm -rf "$workspace"
  mkdir -p "$workspace/project"

  export PATH="$ROOT/tests/fixtures/bin:$PATH"
  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CW_ZELLIJ_LOG="$workspace/zellij.log"

  source "$PLUGIN_FILE"
  pj "$workspace/project"

  [[ -f "$CW_ZELLIJ_LOG" ]] || _fail "zellij invocation log should exist"
  grep -q "action=new-project-session" "$CW_ZELLIJ_LOG" || _fail "pj should create a new project session"
  grep -q "cwd=$workspace/project" "$CW_ZELLIJ_LOG" || _fail "pj should create the session in the project directory"
}

run_test_px_requires_reset_for_new_directory() {
  local workspace="$TMP_ROOT/px-existing"
  rm -rf "$workspace"
  mkdir -p "$workspace/one" "$workspace/two"

  export PATH="$ROOT/tests/fixtures/bin:$PATH"
  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CW_ZELLIJ_LOG="$workspace/zellij.log"

  source "$PLUGIN_FILE"
  px "$workspace/one"
  : > "$CW_ZELLIJ_LOG"
  px "$workspace/two"

  grep -q "action=attach-temp-session" "$CW_ZELLIJ_LOG" || _fail "px should re-enter existing temp session"
  ! grep -q "cwd=$workspace/two" "$CW_ZELLIJ_LOG" || _fail "px should not silently retarget temp session"
}

run_test_pjp_routes_selected_session_into_pj() {
  local workspace="$TMP_ROOT/pjp"
  rm -rf "$workspace"
  mkdir -p "$workspace"

  export PATH="$ROOT/tests/fixtures/bin:$PATH"
  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CW_ZELLIJ_LOG="$workspace/zellij.log"
  export CW_FZF_SELECTION="api | $workspace/project-api"

  source "$PLUGIN_FILE"
  _cw_write_project_metadata "api" "$workspace/project-api"
  pjp

  grep -q "action=attach-project-session" "$CW_ZELLIJ_LOG" || _fail "pjp should route through pj"
}

run_test_session_name_collision
run_test_project_metadata_roundtrip
run_test_pj_creates_layout_for_new_project
run_test_px_requires_reset_for_new_directory
run_test_pjp_routes_selected_session_into_pj

print -- "PASS: plugin_test.zsh"
