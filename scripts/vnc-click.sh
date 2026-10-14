#!/usr/bin/env bash
# Click at viewport coordinates on a noVNC canvas driven by chrome-devtools-axi.
#
# noVNC drops synthetic DOM events, so dispatching a MouseEvent at the target
# does nothing. Only a real CDP input event reaches it, and chrome-devtools-axi
# only aims those at elements from the accessibility snapshot -- it takes no
# coordinates. So place a transparent, pointer-events:none marker button at the
# target, let axi dispatch its real click on that marker, and the event falls
# through to the canvas underneath.
#
# Open the session first (`chrome-devtools-axi open <noVNC URL>`); the oracle's
# URL is in CLAUDE.local.md. Coordinates are CSS pixels in the browser viewport,
# which is what `chrome-devtools-axi screenshot` captures, so they can be read
# straight off a screenshot taken at the same `resize` dimensions.
set -euo pipefail

if [ "$#" -ne 2 ] || [ "$1" = "--help" ]; then
  echo "usage: $(basename "$0") <x> <y>" >&2
  exit 1
fi
x="$1"
y="$2"

axi() { npx -y chrome-devtools-axi "$@"; }

axi eval "() => {
  document.getElementById('axi-mark')?.remove();
  const b = document.createElement('button');
  b.id = 'axi-mark';
  b.textContent = 'AXIMARK';
  b.style.cssText = 'position:fixed;left:${x}px;top:${y}px;width:4px;height:4px;'
    + 'margin:-2px 0 0 -2px;padding:0;border:0;background:transparent;'
    + 'color:transparent;z-index:2147483647;pointer-events:none;';
  document.body.appendChild(b);
  return 'ok';
}" >/dev/null

# The marker needs a non-zero size and no opacity:0 to reach the a11y tree.
uid=$(axi snapshot | sed -n 's/^ *uid=\([^ ]*\) button "AXIMARK".*/\1/p' | head -1)
if [ -z "$uid" ]; then
  axi eval "() => { document.getElementById('axi-mark')?.remove(); return 'ok' }" >/dev/null
  echo "vnc-click: marker missing from the snapshot; is a page open?" >&2
  exit 1
fi

axi click "@$uid" >/dev/null
axi eval "() => { document.getElementById('axi-mark')?.remove(); return 'ok' }" >/dev/null
echo "clicked ${x},${y}"
