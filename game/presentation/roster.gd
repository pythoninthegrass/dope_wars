class_name Roster
extends RefCounted

## Display names for the two static rule tables, loaded once and cached.
##
## This is the one thing the presentation layer is allowed to hold onto, and
## the reason is in the header itself: `include/dopewars.h:407-410` says the
## `dw_rules_*` accessors are "pure and reentrant" and that "callers cache
## these once at startup". They are not `dw_world` state -- nothing can change
## them mid-run -- so caching them is not the mirrored-world-state problem
## `docs/layer-boundaries.md` rules out. Everything that *does* move (cash,
## day, prices, inventory) is re-read from the world on every render instead.
##
## Deliberately not a second copy of the tables: drug ids, names, price bands
## and borough police weights all come from the core, and this file only holds
## what it was handed.

static var _drugs: Array = []
static var _locations: Array = []
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var world := SimWorld.new()
	_drugs = world.rules_drugs()
	_locations = world.rules_locations()


static func drugs() -> Array:
	_ensure()
	return _drugs


static func locations() -> Array:
	_ensure()
	return _locations


static func location_count() -> int:
	_ensure()
	return _locations.size()


## The index.html prototype sorts both tables by display name
## (`index.html:1168`, `:1200`). All twelve drug names are single capitalized
## words, so Godot's codepoint ordering and JS's localeCompare agree here; if a
## future ruleset adds a mixed-case name, that assumption needs revisiting.
static func sorted_drug_indices() -> Array[int]:
	_ensure()
	var indices: Array[int] = []
	for i in range(_drugs.size()):
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool:
		return String(_drugs[a]["name"]) < String(_drugs[b]["name"])
	)
	return indices


static func drug_id(drug_index: int) -> String:
	_ensure()
	if drug_index < 0 or drug_index >= _drugs.size():
		return ""
	return String(_drugs[drug_index]["id"])


static func drug_name(drug_index: int) -> String:
	_ensure()
	if drug_index < 0 or drug_index >= _drugs.size():
		return ""
	return String(_drugs[drug_index]["name"])


static func location_name(location_index: int) -> String:
	_ensure()
	if location_index < 0 or location_index >= _locations.size():
		return ""
	return String(_locations[location_index]["name"])
