#!/usr/bin/env zsh
set -euo pipefail

ROOT="${0:A:h:h}"
PLUGIN_FILE="$ROOT/codex-workflow.plugin.zsh"
TMP_ROOT="$ROOT/tests/tmp"
SYSTEM_PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

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
  local needle="$pattern"
  needle="${needle#\*}"
  needle="${needle%\*}"
  [[ "$value" == *"$needle"* ]] || _fail "$msg (value: $value, pattern: $pattern)"
}

run_test_session_name_collision() {
  export PATH="$SYSTEM_PATH"
  local workspace="$TMP_ROOT/session-name"
  rm -rf "$workspace"
  mkdir -p "$workspace/api" "$workspace/alt/api"

  source "$PLUGIN_FILE"
  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  _cw_write_project_metadata "api" "$workspace/api"

  local resolved
  resolved="$(_cw_resolve_project_session_name "$workspace/alt/api")"
  _assert_eq "api-2" "$resolved" "collision should append numeric suffix"
}

run_test_project_metadata_roundtrip() {
  export PATH="$SYSTEM_PATH"
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
  export PATH="$ROOT/tests/fixtures/bin:$SYSTEM_PATH"
  local workspace="$TMP_ROOT/pj-create"
  rm -rf "$workspace"
  mkdir -p "$workspace/project"

  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CW_ZELLIJ_LOG="$workspace/zellij.log"
  export CW_ZELLIJ_STATE="$workspace/zellij.state"
  export CODEX_WORKFLOW_PICKER="fzf"

  source "$PLUGIN_FILE"
  pj "$workspace/project"

  [[ -f "$CW_ZELLIJ_LOG" ]] || _fail "zellij invocation log should exist"
  grep -q "action=new-project-session" "$CW_ZELLIJ_LOG" || _fail "pj should create a new project session"
  grep -q "cwd=$workspace/project" "$CW_ZELLIJ_LOG" || _fail "pj should create the session in the project directory"
  grep -q -- "--new-session-with-layout" "$CW_ZELLIJ_LOG" || _fail "pj should force a new zellij session with the generated layout"
  grep -q -- "--session project" "$CW_ZELLIJ_LOG" || _fail "pj should name the new zellij session"
  grep -q 'split_direction="horizontal"' "$workspace/state/project.kdl" || _fail "project layout should split panes top and bottom"
  grep -q 'args "--no-alt-screen"' "$workspace/state/project.kdl" || _fail "codex pane should disable alternate screen in zellij"
}

run_test_px_requires_reset_for_new_directory() {
  export PATH="$ROOT/tests/fixtures/bin:$SYSTEM_PATH"
  local workspace="$TMP_ROOT/px-existing"
  rm -rf "$workspace"
  mkdir -p "$workspace/one" "$workspace/two"

  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CW_ZELLIJ_LOG="$workspace/zellij.log"
  export CW_ZELLIJ_STATE="$workspace/zellij.state"

  source "$PLUGIN_FILE"
  px "$workspace/one"
  : > "$CW_ZELLIJ_LOG"
  px "$workspace/two"

  grep -q "action=attach-temp-session" "$CW_ZELLIJ_LOG" || _fail "px should re-enter existing temp session"
  ! grep -q "cwd=$workspace/two" "$CW_ZELLIJ_LOG" || _fail "px should not silently retarget temp session"
}

run_test_pjp_routes_selected_session_into_pj() {
  export PATH="$ROOT/tests/fixtures/bin:$SYSTEM_PATH"
  local workspace="$TMP_ROOT/pjp"
  rm -rf "$workspace"
  mkdir -p "$workspace/project-api"

  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CW_ZELLIJ_LOG="$workspace/zellij.log"
  export CW_ZELLIJ_STATE="$workspace/zellij.state"
  export CODEX_WORKFLOW_PICKER="$ROOT/tests/fixtures/bin/fzf"
  export CW_FZF_SELECTION="api | $workspace/project-api"

  source "$PLUGIN_FILE"
  _cw_write_project_metadata "api" "$workspace/project-api"
  print -- "api" > "$CW_ZELLIJ_STATE"
  pjp

  grep -q "action=attach-project-session" "$CW_ZELLIJ_LOG" || _fail "pjp should route through pj"
  grep -q "^attach api$" "$CW_ZELLIJ_LOG" || _fail "pjp should attach existing zellij session without boolean flag values"
  ! grep -q -- "--create-background=false" "$CW_ZELLIJ_LOG" || _fail "zellij attach should not pass a value to --create-background"
}

run_test_pjs_lists_saved_session_paths() {
  export PATH="$SYSTEM_PATH"
  local workspace="$TMP_ROOT/pjs"
  rm -rf "$workspace"
  mkdir -p "$workspace"

  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"

  source "$PLUGIN_FILE"
  _cw_write_project_metadata "api" "$workspace/api"
  _cw_write_project_metadata "web" "$workspace/web"

  local output
  output="$(pjs)"
  _assert_match "$output" "*api | $workspace/api*" "pjs should include api mapping"
  _assert_match "$output" "*web | $workspace/web*" "pjs should include web mapping"
}

run_test_pxr_deletes_temp_session() {
  export PATH="$ROOT/tests/fixtures/bin:$SYSTEM_PATH"
  local workspace="$TMP_ROOT/pxr"
  rm -rf "$workspace"
  mkdir -p "$workspace/one"

  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CW_ZELLIJ_LOG="$workspace/zellij.log"
  export CW_ZELLIJ_STATE="$workspace/zellij.state"

  source "$PLUGIN_FILE"
  px "$workspace/one"
  pxr

  grep -q "^delete-session codex-temp$" "$CW_ZELLIJ_LOG" || _fail "pxr should delete the temp session"
  ! grep -q "^codex-temp$" "$CW_ZELLIJ_STATE" || _fail "pxr should remove temp session from zellij state"
}

run_test_requires_zellij_and_codex() {
  export PATH="$SYSTEM_PATH"
  local workspace="$TMP_ROOT/require-cmd"
  rm -rf "$workspace"
  mkdir -p "$workspace/project"

  export PATH="$ROOT/tests/fixtures/no-zellij"
  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"

  source "$PLUGIN_FILE"

  local output=""
  if output="$(pj "$workspace/project" 2>&1)"; then
    _fail "pj should fail when zellij is unavailable"
  fi

  _assert_match "$output" "*missing required command: zellij*" "pj should report missing zellij"
}

run_test_pjp_requires_picker_command() {
  export PATH="$ROOT/tests/fixtures/bin:$SYSTEM_PATH"
  local workspace="$TMP_ROOT/pjp-require-picker"
  rm -rf "$workspace"
  mkdir -p "$workspace"

  export CODEX_WORKFLOW_STATE_DIR="$workspace/state"
  export CODEX_WORKFLOW_PICKER="missing-picker"

  source "$PLUGIN_FILE"

  local output=""
  if output="$(pjp 2>&1)"; then
    _fail "pjp should fail when picker command is missing"
  fi

  _assert_match "$output" "*missing required command: missing-picker*" "pjp should report missing picker"
}

run_test_requires_zellij_and_codex
run_test_session_name_collision
run_test_project_metadata_roundtrip
run_test_pj_creates_layout_for_new_project
run_test_px_requires_reset_for_new_directory
run_test_pjp_routes_selected_session_into_pj
run_test_pjs_lists_saved_session_paths
run_test_pxr_deletes_temp_session
run_test_pjp_requires_picker_command

print -- "PASS: plugin_test.zsh"
