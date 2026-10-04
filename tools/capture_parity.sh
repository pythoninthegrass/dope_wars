#!/usr/bin/env bash
# TASK-012.03 parity capture.
#
# Renders the exported Linux build (via the --capture-state= debug hook, see
# Main.drive_capture_state) and the web prototype (index.html?seed=<n>, a real
# Firefox window) under one headless sway compositor, and grabs a screenshot of
# each at matching states with grim. Output is a set of PNGs for a human to
# eyeball side by side; this is judgment-matched, not an automated pixel diff.
#
# Why a hook for the Godot side and real input for the prototype: under headless
# sway, wtype keystrokes reach a Godot window without changing game state (the
# same finding as ~/git/neo_snake's decision-025), so Godot is driven from its
# command line. The browser takes real wtype keystrokes. The buy state has no
# oracle screenshot: the prototype selects a drug only by clicking a table row,
# and a headless sway seat has no pointer device to click with.
#
# Linux + Wayland tooling only; not part of `task check`. Run through
# `task capture:linux -- --seed=42`, which builds the export first.
#
# Usage: capture_parity.sh [--seed=<n>] [--out=<dir>]
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED=42
OUT_DIR="$ROOT_DIR/artifacts/parity"
GAME="$ROOT_DIR/game/build/linux/dopewars.x86_64"
STATES=(boot buy travel finances)
# The prototype can only select a drug by clicking a row, and a headless sway
# seat has no pointer, so the oracle side covers the states real keys reach.
ORACLE_STATES=(boot travel finances)

# The game window is 704x620 at scale 1.0, on a 1280x800 headless output.
GAME_W=704
GAME_H=620
OUTPUT_RES=1280x800

for arg in "$@"; do
	case "$arg" in
	--seed=*) SEED="${arg#--seed=}" ;;
	--out=*) OUT_DIR="${arg#--out=}" ;;
	*)
		echo "capture_parity: unknown argument: $arg" >&2
		exit 2
		;;
	esac
done

for bin in sway swaymsg wtype grim firefox jq; do
	command -v "$bin" >/dev/null 2>&1 || {
		echo "capture_parity: missing required binary: $bin" >&2
		exit 1
	}
done
[ -x "$GAME" ] || {
	echo "capture_parity: $GAME not found; run task export:linux" >&2
	exit 1
}

mkdir -p "$OUT_DIR"
WORKDIR="$(mktemp -d)"
SWAY_PID=""
WTYPE_PID=""
APP_PID=""

# SIGTERM first so the game can exit cleanly; SIGKILL only if it does not.
stop_app() {
	[ -n "$APP_PID" ] || return 0
	kill -TERM "$APP_PID" >/dev/null 2>&1 || true
	for _ in $(seq 1 30); do
		kill -0 "$APP_PID" >/dev/null 2>&1 || break
		sleep 0.1
	done
	kill -9 "$APP_PID" >/dev/null 2>&1 || true
	wait "$APP_PID" 2>/dev/null || true
	APP_PID=""
}

cleanup() {
	stop_app
	for pid in "$WTYPE_PID" "$SWAY_PID"; do
		[ -n "$pid" ] || continue
		kill -9 "$pid" >/dev/null 2>&1 || true
		wait "$pid" 2>/dev/null || true
	done
	rm -rf "$WORKDIR"
}
trap cleanup EXIT

cat >"$WORKDIR/sway.conf" <<EOF
output HEADLESS-1 resolution $OUTPUT_RES
for_window [app_id="Dope Wars"] floating enable, border none, move position 0 0
EOF

env WLR_BACKENDS=headless WLR_RENDERER=pixman sway -c "$WORKDIR/sway.conf" >"$WORKDIR/sway.log" 2>&1 &
SWAY_PID=$!

# The sockets sway creates are named per process; wait for them rather than sleep.
for _ in $(seq 1 50); do
	SOCK="$(ls "${XDG_RUNTIME_DIR}"/wayland-[0-9]* 2>/dev/null | grep -v '\.lock$' | head -1 || true)"
	SWAYSOCK="$(ls "${XDG_RUNTIME_DIR}"/sway-ipc.*."$SWAY_PID".sock 2>/dev/null | head -1 || true)"
	[ -n "$SOCK" ] && [ -n "$SWAYSOCK" ] && break
	sleep 0.2
done
if [ -z "${SOCK:-}" ] || [ -z "${SWAYSOCK:-}" ]; then
	echo "capture_parity: sway came up without its sockets -- see $WORKDIR/sway.log" >&2
	cat "$WORKDIR/sway.log" >&2
	exit 1
fi
export WAYLAND_DISPLAY
WAYLAND_DISPLAY="$(basename "$SOCK")"
export SWAYSOCK

# One long-lived virtual keyboard: a lone per-invocation wtype can lose the race
# between creating its keyboard and the compositor binding it, and the keystroke
# is silently dropped (the same finding as ~/git/neo_snake's decision-025).
wtype -s 600000 >/dev/null 2>&1 &
WTYPE_PID=$!
sleep 1

# Poll sway's tree until a window with this app_id exists.
wait_for_window() {
	local app_id="$1"
	for _ in $(seq 1 100); do
		if swaymsg -t get_tree | jq -e --arg id "$app_id" '.. | select(.app_id? == $id)' >/dev/null 2>&1; then
			return 0
		fi
		sleep 0.2
	done
	echo "capture_parity: no '$app_id' window appeared" >&2
	return 1
}

capture_godot() {
	local state="$1" log="$WORKDIR/godot-$state.log"
	# A throwaway XDG_DATA_HOME keeps the run off the player's real save.
	# Headless sway has no GPU, so Godot's default Vulkan renderer cannot get a surface.
	env XDG_DATA_HOME="$WORKDIR/xdg-$state" stdbuf -oL "$GAME" --rendering-driver opengl3 --rendering-method gl_compatibility \
		--seed="$SEED" --capture-state="$state" >"$log" 2>&1 &
	APP_PID=$!
	wait_for_window "Dope Wars" || {
		echo "capture_parity: the game's own output follows:" >&2
		cat "$log" >&2
		exit 1
	}
	# Let the hook's awaited frames and any arrival dialog finish drawing.
	sleep 3
	grim -g "0,0 ${GAME_W}x${GAME_H}" "$OUT_DIR/godot-$state.png"
	stop_app
}

capture_oracle() {
	local state="$1"
	mkdir -p "$WORKDIR/ff-$state"
	env MOZ_ENABLE_WAYLAND=1 firefox --new-instance --no-remote --profile "$WORKDIR/ff-$state" --kiosk \
		"file://$ROOT_DIR/index.html?seed=$SEED" >"$WORKDIR/firefox-$state.log" 2>&1 &
	APP_PID=$!
	wait_for_window "firefox"
	sleep 4
	case "$state" in
	boot) ;;
	travel)
		wtype 6
		sleep 2
		;;
	finances)
		wtype f
		sleep 1
		;;
	esac
	grim "$OUT_DIR/oracle-$state.png"
	stop_app
}

echo "capturing Godot build states (seed $SEED)..."
for state in "${STATES[@]}"; do
	capture_godot "$state"
done

echo "capturing index.html oracle states (seed $SEED)..."
for state in "${ORACLE_STATES[@]}"; do
	capture_oracle "$state"
done

echo "done -- screenshots in $OUT_DIR"
