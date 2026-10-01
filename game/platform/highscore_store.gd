class_name HighscoreStore
extends RefCounted

## The localStorage key 'dopewars.highscores' from `index.html:1557`, as JSON
## under user://. Each record is {name, score, day, dead, date}.
##
## Ordering and the top-10 truncation are the core's job, not this file's:
## dw_insert_highscore sorts by score descending and cuts to
## DW_MAX_HIGHSCORES, and it drops any key outside
## {name, score, day, dead}. The date is therefore the one field the core
## cannot carry, and it round-trips through this store instead.
##
## A date is a wall-clock fact about when a run was recorded, not a fact about
## the run, which is why it stays out of the ABI. Re-attaching it is a tuple
## match on the four fields the core does preserve; two runs that tie on all
## four are the same run as far as the table is concerned, and the first
## record's date wins.

const SCORES_PATH := "user://dopewars.highscores.json"


## Every record, or [] when the file is absent or unreadable -- the prototype's
## `JSON.parse(...) || []` in a try/catch (`index.html:1559-1563`). A record
## missing any of the core's four fields is dropped rather than defaulted, so
## the tuple match can never invent a phantom row.
func load_all() -> Array[Dictionary]:
	if not FileAccess.file_exists(SCORES_PATH):
		return []
	var file := FileAccess.open(SCORES_PATH, FileAccess.READ)
	if file == null:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return []

	var records: Array[Dictionary] = []
	for raw: Variant in parsed:
		if not (raw is Dictionary):
			continue
		var row: Dictionary = raw
		if not _has_core_fields(row):
			continue
		records.append({
			"name": String(row["name"]),
			"score": int(row["score"]),
			"day": int(row["day"]),
			"dead": bool(row["dead"]),
			"date": String(row.get("date", "")),
		})
	return records


## Inserts one score, persists the result, and returns
## `{"table": Array[Dictionary], "inserted": bool}`.
##
## `inserted` is false when the core refused the entry -- a score of 0 or
## below (`SimWorld.ERR_SCORE_TOO_LOW`, docs/beermat-re.md M-13) -- in which
## case `table` is the unchanged previous table.
##
## `today` is an ISO date (YYYY-MM-DD) in UTC, matching the prototype's
## `new Date().toISOString().slice(0, 10)`. Pass "" to read the system clock;
## tests pass it explicitly so a run is reproducible.
func insert(world: SimWorld, entry: Dictionary, today: String = "") -> Dictionary:
	if today.is_empty():
		today = Time.get_date_string_from_system(true)

	var dates := {}
	dates[_tuple(entry)] = today
	var previous := load_all()
	for row in previous:
		# The just-inserted entry wins a tie, so a repeat run of the same
		# game re-stamps rather than inheriting its own earlier date.
		if not dates.has(_tuple(row)):
			dates[_tuple(row)] = String(row["date"])

	var result := world.insert_highscore(_core_only(previous), _core_row(entry))
	if int(result.get("result", SimWorld.ERR_INVALID_ARGUMENT)) != SimWorld.OK:
		return {"table": previous, "inserted": false}

	var scores: Array = result.get("scores", [])
	var table: Array[Dictionary] = []
	for raw: Variant in scores:
		var row: Dictionary = raw
		table.append({
			"name": String(row["name"]),
			"score": int(row["score"]),
			"day": int(row["day"]),
			"dead": bool(row["dead"]),
			"date": String(dates.get(_tuple(row), "")),
		})
	_write(table)
	return {"table": table, "inserted": true}


static func _has_core_fields(row: Dictionary) -> bool:
	return row.has("name") and row.has("score") and row.has("day") and row.has("dead")


static func _core_row(row: Dictionary) -> Dictionary:
	return {
		"name": String(row["name"]),
		"score": int(row["score"]),
		"day": int(row["day"]),
		"dead": bool(row["dead"]),
	}


static func _core_only(rows: Array) -> Array:
	var out: Array = []
	for row: Dictionary in rows:
		out.append(_core_row(row))
	return out


## The identity the core preserves across an insert. US (0x1f) as the
## separator so a name containing a digit cannot forge a different row's key.
const _SEPARATOR := 0x1f


static func _tuple(row: Dictionary) -> String:
	return "%s%s%d%s%d%s%s" % [
		String(row["name"]), char(_SEPARATOR),
		int(row["score"]), char(_SEPARATOR),
		int(row["day"]), char(_SEPARATOR),
		str(bool(row["dead"])),
	]


## Drops the whole table. `startNewGame` does not do this -- the prototype
## keeps scores across games, so only a test has a reason to.
func clear_all() -> void:
	if FileAccess.file_exists(SCORES_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCORES_PATH))


func _write(table: Array[Dictionary]) -> void:
	var file := FileAccess.open(SCORES_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(table))
