#!/usr/bin/env zsh
set -euo pipefail

ROOT="${0:A:h:h}"

chmod +x "$ROOT/tests/plugin_test.zsh"
"$ROOT/tests/plugin_test.zsh"
