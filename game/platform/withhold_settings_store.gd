class_name WithholdSettingsStore
extends RefCounted

## The amount Finances' "Deposit All But.." leaves in cash, set in Options
## (`OptionsDlg_SkinOkBtnClick`, docs/beermat-2.1-re.md) and kept as JSON under
## user://, the same pattern `sound_settings_store.gd` uses.
##
## A missing or corrupt file reads back DEFAULT_WITHHOLD, which is what the 2.1
## oracle shows on a first run. Out-of-range values clamp to 0..MAX_WITHHOLD.

const SETTINGS_PATH := "user://dopewars.withhold.json"
const DEFAULT_WITHHOLD := 1000
const MAX_WITHHOLD := 1000000


func load_withhold() -> int:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return DEFAULT_WITHHOLD
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return DEFAULT_WITHHOLD
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary) or not (parsed.get("withhold") is float):
		return DEFAULT_WITHHOLD
	return clampi(int(parsed["withhold"]), 0, MAX_WITHHOLD)


func save_withhold(amount: int) -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"withhold": clampi(amount, 0, MAX_WITHHOLD)}))


## A test's reset to the default, matching `sound_settings_store.gd`'s `clear()`.
func clear() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
