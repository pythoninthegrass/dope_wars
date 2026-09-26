#!/usr/bin/env bash
# Non-vendor, non-generated lines of code by language, plus the Mojo share.
#
# Excluded as vendor or generated: third_party/ (godot-cpp), .agents/ and
# .claude/ (vendored skill scripts), every build output and venv, and the
# backlog/ task records. index.html is counted on its own line and labelled as
# the JS oracle this port replaces -- it is deleted at the end of TASK-001, so
# it shrinks out of the denominator once the port lands.
#
# Mojo is reported three ways: core/ alone, the parity harness alone, and the
# combined hand-written total. The combined figure is the headline because both
# are hand-written, but the split is shown so the number cannot be inflated by
# padding the harness.
set -euo pipefail
cd "$(dirname "$0")/.."

EXCLUDE_DIR='^\./(third_party|\.git|\.venv|backlog|node_modules|\.serena|screenshots|third_party)'
EXCLUDE_DIR="$EXCLUDE_DIR|/(build-output|\.venv|\.godot|\.sconsign|__pycache__)(/|\$)"
EXCLUDE_DIR="$EXCLUDE_DIR|^\./(\.agents|\.claude|\.opencode)/"
EXCLUDE_FILE='(\.mojo\.inc$|/package-lock\.json$|\.min\.(js|css)$)'

# Non-blank, non-comment-only lines. A line counts if it has any non-whitespace
# character that is not part of a line comment.
sloc() {
  # shellcheck disable=SC2016
  cat "$@" 2>/dev/null \
    | grep -Ev '^[[:space:]]*(#|//|--|/\*|\*|<!--|$)' \
    | wc -l \
    | tr -d ' ' \
    || true
}

files_for() {
  find . -type f -name "*.$1" 2>/dev/null \
    | grep -Ev "$EXCLUDE_DIR" \
    | grep -Ev "$EXCLUDE_FILE"
}

row() {
  # $1 = label, rest = files
  local label="$1"
  shift
  local n=0 f
  for f in "$@"; do
    [ -f "$f" ] || continue
    n=$((n + $(sloc "$f")))
  done
  ROW_LABELS+=("$label")
  ROW_VALUES+=("$n")
}

ROW_LABELS=()
ROW_VALUES=()

mapfile -t mojo_core < <(files_for mojo | grep '^\./core/src/')
mapfile -t mojo_harness < <(files_for mojo | grep '^\./tests/mojo/')
mapfile -t cpp < <(files_for cpp)
mapfile -t hdr < <(files_for h)
mapfile -t gd < <(files_for gd)
mapfile -t py < <(files_for py)
mapfile -t mjs < <(files_for mjs)
mapfile -t sh < <(files_for sh)
mapfile -t yml < <(find . -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | grep -Ev "$EXCLUDE_DIR")

row "Mojo (core/src/)" "${mojo_core[@]}"
row "Mojo (tests/mojo/)" "${mojo_harness[@]}"
row "C++ (extension/)" "${cpp[@]}"
row "C headers (include/)" "${hdr[@]}"
row "GDScript (game/)" "${gd[@]}"
row "Python (scripts/)" "${py[@]}"
row "JS harness (tests/*.mjs)" "${mjs[@]}"
row "Shell (scripts/)" "${sh[@]}"
row "YAML (taskfiles)" "${yml[@]}"
row "index.html (JS oracle + UI)" index.html

total=0
printf '%-30s %8s\n' "LANGUAGE / AREA" "SLOC"
printf '%-30s %8s\n' "------------------------------" "--------"
for i in "${!ROW_LABELS[@]}"; do
  printf '%-30s %8d\n' "${ROW_LABELS[$i]}" "${ROW_VALUES[$i]}"
  total=$((total + ROW_VALUES[$i]))
done

mojo_core_n=${ROW_VALUES[0]}
mojo_harness_n=${ROW_VALUES[1]}
mojo_total=$((mojo_core_n + mojo_harness_n))

printf '%-30s %8s\n' "------------------------------" "--------"
printf '%-30s %8d\n' "TOTAL" "$total"
printf '%-30s %8d\n' "Mojo total (core + harness)" "$mojo_total"
awk -v m="$mojo_total" -v t="$total" \
  'BEGIN { printf "Mojo %% of non-vendor SLOC: %.2f%%   (target >= 43%%)\n", 100*m/t }'
awk -v m="$mojo_core_n" -v t="$total" \
  'BEGIN { printf "  of which core/ alone:      %.2f%%\n", 100*m/t }'
