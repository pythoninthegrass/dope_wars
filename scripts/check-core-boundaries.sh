#!/usr/bin/env bash
# Boundary gate for core/src (see docs/layer-boundaries.md).
#
# core/ is the pure simulation layer. It must not import Godot, import any FFI
# symbol from the C++ shim, do file/network/environment I/O, hold global mutable
# state outside the dw_world handle, or contain presentation strings. This runs
# in CI so a violation fails the build instead of surviving review.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC=core/src
fail=0

check() {
  local label="$1" pattern="$2"
  shift 2
  if matches=$(grep -REn "$pattern" "$@" 2>/dev/null); then
    echo "FAIL  $label"
    echo "$matches" | sed 's/^/      /'
    fail=1
  else
    echo "ok    $label"
  fi
}

check "no Godot imports" \
  '^\s*(import|from)\s+.*\b(godot|Godot|GDExtension)\b' "$SRC"

check "no FFI imports of shim symbols" \
  '^\s*(import|from)\s+.*\b(dopewars_world|register_types)\b' "$SRC"

check "no file I/O" \
  '\b(open|readline|FileHandle|os\.open|io\.)\b\s*\(' "$SRC"

check "no network I/O" \
  '\b(socket|http|urlopen|requests\.)\b' "$SRC"

check "no environment reads" \
  '\b(os\.environ|getenv|getenv_)\b' "$SRC"

check "no print/logging at steady state" \
  '\b(print|printf|logging|logger)\s*\(' "$SRC"

check "no global mutable state" \
  '^var\s+[a-zA-Z_]' "$SRC"

if [ "$fail" -ne 0 ]; then
  echo "---"
  echo "core/ boundary violations above. See docs/layer-boundaries.md."
  exit 1
fi
echo "---"
echo "core/src boundary gate clean"
