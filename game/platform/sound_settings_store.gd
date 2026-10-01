class_name SoundSettingsStore
extends RefCounted

## Mirrors the registry value `AllowSound` (`TForm1.EnableSndClick`,
## docs/beermat-re.md) as JSON under user://, the same pattern
## `highscore_store.gd` uses for the high-score table.
##
## A missing or corrupt file reads back true: docs/beermat-re.md's "AllowSound
## default: on" -- a normal first run writes 1, and only a broken install ever
## sees 0.

const SETTINGS_PATH := "user://dopewars.sound.json"


func load_allow_sound() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return true
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return true
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not parsed.has("allow_sound"):
		return true
	return bool(parsed["allow_sound"])


func save_allow_sound(allowed: bool) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"allow_sound": allowed}))


## A test's reset to the default, matching `save_store.gd`'s `clear()`.
func clear() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
