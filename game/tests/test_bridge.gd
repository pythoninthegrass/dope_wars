# game/tests/test_bridge.gd — bridge integration test (TASK-001.05).
#
# Exercises the full Godot -> C++ GDExtension -> Mojo call path headlessly:
# world lifecycle, a game step sequence, and a serialize/deserialize
# round-trip. Run with:
#   godot --headless --path game --script res://tests/test_bridge.gd
# Exits 0 on success, 1 on the first failed assertion (printed to stderr).
#
# This is deliberately not a UI test: it proves the ABI bridge carries real
# state, not that the presentation layer renders it (that is TASK-001.06).
extends SceneTree

var _failures := 0


func _initialize() -> void:
	_test_abi_version()
	_test_world_lifecycle()
	_test_game_step_sequence()
	_test_serialize_round_trip()
	_test_determinism()
	_test_rules_surface()

	if _failures > 0:
		push_error("%d test_bridge assertion(s) failed" % _failures)
		quit(1)
	else:
		print("test_bridge: OK")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % message)


func _new_world(seed: int = 7) -> DopeWarsWorld:
	var world := DopeWarsWorld.new()
	var result := world.init(seed)
	_assert(result == DopeWarsWorld.DW_OK, "world.init() should return DW_OK, got %d" % result)
	return world


func _test_abi_version() -> void:
	var world := DopeWarsWorld.new()
	_assert(
		world.abi_version() == DopeWarsWorld.DW_ABI_VERSION,
		"abi_version() should equal DW_ABI_VERSION",
	)


func _test_world_lifecycle() -> void:
	var world := _new_world()
	_assert(world.is_ready(), "world should be ready after init")

	var state: Dictionary = world.state_get()
	_assert(state["result"] == DopeWarsWorld.DW_OK, "state_get should succeed")
	_assert(state["day"] == 1, "a fresh game starts on day 1")
	_assert(state["cash"] == 2000, "a fresh game starts with 2000 cash")
	_assert(state["debt"] == 5500, "a fresh game starts with 5500 debt")
	_assert(state["health"] == 100, "a fresh game starts with 100 health")
	_assert(state["coat_capacity"] == 100, "a fresh game starts with 100 coat slots")
	_assert(state["location_index"] == 0, "a fresh game starts in the Bronx")

	# A reset is a full new game, not a mid-game reset.
	var damage: Dictionary = world.apply_damage(40)
	_assert(damage["health"] == 60, "apply_damage should reduce health to 60")
	_assert(world.reset() == DopeWarsWorld.DW_OK, "reset should succeed")
	_assert(world.state_get()["health"] == 100, "reset should restore health")


func _test_game_step_sequence() -> void:
	var world := _new_world()

	var prices: Array = world.prices_copy()
	_assert(prices.size() > 0, "a fresh game should have a price roster")
	var drug_index: int = prices[0]["drug_index"]

	var cash_before: int = world.state_get()["cash"]
	_assert(world.buy(drug_index, 1) == DopeWarsWorld.DW_OK, "buy should succeed")
	var after_buy: Dictionary = world.state_get()
	_assert(after_buy["coat_used"] == 1, "buying one unit should use one coat slot")
	_assert(after_buy["cash"] < cash_before, "buying should reduce cash")

	var inventory: Array = world.inventory_copy()
	_assert(inventory.size() == 1, "inventory should hold one drug")
	_assert(inventory[0]["drug_index"] == drug_index, "inventory should hold the bought drug")
	_assert(inventory[0]["qty"] == 1, "inventory should hold one unit")

	_assert(world.sell(drug_index, 1) == DopeWarsWorld.DW_OK, "sell should succeed")
	_assert(world.state_get()["coat_used"] == 0, "selling the unit should free the coat slot")

	_assert(world.travel(2) == DopeWarsWorld.DW_OK, "travel should succeed")
	var after_travel: Dictionary = world.state_get()
	_assert(after_travel["day"] == 2, "travel should advance the day")
	_assert(after_travel["location_index"] == 2, "travel should move the player")
	_assert(after_travel["debt"] == 6050, "travel should compound debt by 10%")

	# Finances move money between cash, bank and debt.
	var deposit: Dictionary = world.finances(DopeWarsWorld.DW_FINANCES_DEPOSIT, 500)
	_assert(deposit["result"] == DopeWarsWorld.DW_OK, "deposit should succeed")
	_assert(deposit["actual"] == 500, "deposit should move 500")
	_assert(world.state_get()["bank"] == 500, "bank should hold the deposit")


func _test_serialize_round_trip() -> void:
	var world := _new_world()
	var prices: Array = world.prices_copy()
	_assert(world.buy(prices[0]["drug_index"], 1) == DopeWarsWorld.DW_OK, "buy should succeed")
	_assert(world.travel(1) == DopeWarsWorld.DW_OK, "travel should succeed")

	var dump: Dictionary = world.world_dump()
	_assert(dump["result"] == DopeWarsWorld.DW_OK, "world_dump should succeed")
	var bytes: PackedByteArray = dump["bytes"]
	_assert(bytes.size() == world.world_dump_len(), "dump length should match world_dump_len()")

	var restored := DopeWarsWorld.new()
	_assert(restored.init(1) == DopeWarsWorld.DW_OK, "restored world should init")
	_assert(restored.world_load(bytes) == DopeWarsWorld.DW_OK, "world_load should succeed")

	var restored_state: Dictionary = restored.state_get()
	_assert(restored_state["day"] == 2, "restored world should be on day 2")
	_assert(restored_state["location_index"] == 1, "restored world should be in the Ghetto")

	var redump: Dictionary = restored.world_dump()
	_assert(redump["bytes"] == bytes, "dump -> load -> dump should be byte-identical")

	# A truncated buffer is rejected and leaves the world unchanged.
	var truncated := bytes.slice(0, bytes.size() - 1)
	_assert(
		restored.world_load(truncated) == DopeWarsWorld.DW_ERR_SERIALIZATION_FAILED,
		"a truncated dump should be rejected",
	)
	_assert(restored.world_dump()["bytes"] == bytes, "a failed load should not mutate the world")


func _test_determinism() -> void:
	var a := _new_world(7)
	var b := _new_world(7)
	_assert(a.world_dump()["bytes"] == b.world_dump()["bytes"], "same seed should produce the same dump")

	var c := _new_world(8)
	_assert(a.world_dump()["bytes"] != c.world_dump()["bytes"], "different seeds should diverge")


func _test_rules_surface() -> void:
	var world := DopeWarsWorld.new()
	var locations: Array = world.rules_locations()
	_assert(locations.size() == DopeWarsWorld.DW_NUM_LOCATIONS, "there should be 6 locations")
	_assert(locations[0]["id"] == "bronx", "the first location should be the Bronx")

	var drugs: Array = world.rules_drugs()
	_assert(drugs.size() == DopeWarsWorld.DW_NUM_DRUGS, "there should be 12 drugs")
	_assert(drugs[0]["id"] == "acid", "the first drug should be acid")

	var found: Dictionary = world.find_drug_index("weed")
	_assert(found["result"] == DopeWarsWorld.DW_OK, "weed should be a known drug")
	_assert(found["index"] == 11, "weed should be drug index 11")
	_assert(
		world.find_drug_index("nope")["result"] == DopeWarsWorld.DW_ERR_UNKNOWN_DRUG,
		"an unknown drug should be rejected",
	)
