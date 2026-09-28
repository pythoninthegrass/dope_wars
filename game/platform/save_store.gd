class_name SaveStore
extends RefCounted

## The localStorage key 'dopewars.save' from `index.html:1537`, as a file under
## user://. The payload is the core's opaque dump -- 766 bytes at ABI v1,
## written verbatim by dw_world_dump -- not JSON. The prototype's JSON blob
## existed only because its state was a JS object; the core already owns a
## canonical byte format, and `docs/layer-boundaries.md` permits handing those
## bytes to FileAccess and passing them back through dw_world_load.
##
## Write failures are swallowed, matching the JS `try { ... } catch (e) { }`
## around setItem: a full disk should not take the game down mid-turn.

const SAVE_PATH := "user://dopewars.save"


## Autosave. The prototype saves at the end of every render
## (`index.html:1163`), which is every state change; the caller wires this to
## its state-changed signal.
func save(world: SimWorld) -> bool:
	var dumped := world.world_dump()
	if int(dumped.get("result", SimWorld.ERR_INVALID_ARGUMENT)) != SimWorld.OK:
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(dumped.get("bytes", PackedByteArray()))
	return true


## Rehydrates `world` in place. False means "start fresh", and the caller must
## treat `world` as a brand-new game.
##
## The prototype deletes the key when JSON.parse throws
## (`index.html:1544-1553`) but not when the key is simply absent. dw_world_load
## validates the length and every index in the payload, so a stale save from a
## different ABI version lands on the same delete path that a malformed JSON
## string would have -- the JS never got that check at all.
func load_into(world: SimWorld) -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var bytes := file.get_buffer(file.get_length())
	if world.world_load(bytes) != SimWorld.OK:
		clear()
		return false
	return true


## `startNewGame` removes the save before rendering, and the render that
## follows immediately writes a fresh one -- so in practice this runs against an
## already-replaced world. Kept separate anyway, because a new game that failed
## to reach its first render must not resume the old one.
func clear() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
