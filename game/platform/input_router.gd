class_name InputRouter
extends Node

## Keyboard routing for the whole game. Emits one intent per shortcut and
## nothing else, so presentation never has to know a keycode. Mirrors the
## keydown handler in `index.html:1676-1698`, including its two-level
## structure: while a modal is up only confirm/cancel are routed, and
## everything else is swallowed.
##
## Uses _unhandled_input rather than _input, which is what gives the JS
## handler's focus rules for free. Godot lets a focused Control consume a key
## first, so a focused Button takes Enter (the JS explicitly skips the dialog
## OK path when activeElement is a BUTTON, `index.html:1682`) and a focused
## LineEdit/SpinBox takes its own text keys (`index.html:1688` skips when
## activeElement is an INPUT). No focus sniffing needed here.

signal intent(name: StringName, payload: Variant)

## Emitted for a key that maps to no intent at all.
const NONE := &""


## Pure so the whole shortcut table is testable without a live Input
## singleton, the same split jumpnbump's input_router.compute_masks() makes.
## Returns one of: NONE, "confirm", "cancel", "buy", "sell", "finances",
## "new_game", "travel_0" .. "travel_5".
static func classify(event: InputEvent) -> StringName:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return NONE

	# The prototype matches the unshifted character (`e.key.toLowerCase()`),
	# so both "b" and "B" mean buy. Godot's keycode is already unshifted, so
	# the modifier does not need inspecting.
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			return &"confirm"
		KEY_ESCAPE:
			return &"cancel"
		KEY_B:
			return &"buy"
		KEY_S:
			return &"sell"
		KEY_F:
			return &"finances"
		KEY_N:
			return &"new_game"
		KEY_1:
			return &"travel_0"
		KEY_2:
			return &"travel_1"
		KEY_3:
			return &"travel_2"
		KEY_4:
			return &"travel_3"
		KEY_5:
			return &"travel_4"
		KEY_6:
			return &"travel_5"
	return NONE


## The borough index a travel intent targets, or -1 for any other intent.
static func travel_index(name: StringName) -> int:
	var text := String(name)
	if not text.begins_with("travel_"):
		return -1
	return int(text.substr(7)) if text.length() > 7 else -1


func _unhandled_input(event: InputEvent) -> void:
	var name := classify(event)
	if name == NONE:
		return
	var payload: Variant = null
	if name.begins_with("travel_"):
		payload = travel_index(name)
	intent.emit(name, payload)
