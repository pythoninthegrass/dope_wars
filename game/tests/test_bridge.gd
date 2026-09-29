# game/tests/test_bridge.gd — bridge integration test (TASK-001.05, reworked
# for TASK-001.06 to drive SimWorld rather than DopeWarsWorld).
#
# Exercises the full Godot -> C++ GDExtension -> Mojo call path headlessly:
# world lifecycle, a game step sequence, and a serialize/deserialize
# round-trip. Run with:
#   godot --headless --path game --script res://tests/test_bridge.gd
# Exits 0 on success, 1 on the first failed assertion (printed to stderr).
#
# It drives SimWorld, not DopeWarsWorld, because
# tools/validate_game_boundary.py forbids naming the GDExtension class outside
# game/simulation/. Going through the wrapper is also the more useful test:
# it covers the same call path the game itself uses, where nothing does.
#
# This is deliberately not a UI test: the presentation layer is covered by
# game/godot_tests/ui_flow_test.gd.
extends SceneTree

var _failures := 0
var _assertions := 0
var _per_case := {}
var _current_case := "harness"
var _reconciled := false
var _frames := 0

# Per-case assertion floor. Each case declares the number of assertions it runs
# on the happy path (including the init assert its _new_world() call makes); a
# case that dies partway -- a GDScript runtime error, an unexpected null, an
# early return -- runs fewer and is reported as a named failure. A whole-suite
# floor cannot see a case that dies on its third check while the total still
# clears MIN_ASSERTIONS, which is exactly how _test_serialize_round_trip's death
# reported OK. Keep these in sync when a case gains or loses a check.
const EXPECTED_ASSERTIONS := {
	"abi_version": 1,
	"world_lifecycle": 12,
	"game_step_sequence": 17,
	"partial_sell": 6,
	"serialize_round_trip": 16,
	"determinism": 5,
	"rules_surface": 7,
	"prev_prices": 16,
	"dealer_visits": 10,
}

## Coarse backstop for the harness itself: if every case reports but the total
## is almost nothing, the run is still wrong. See AGENTS.md on false passes.
const MIN_ASSERTIONS := 40

# Backstop for a synchronous error in the harness before the cases: it aborts
# _initialize and skips _finish, so the tree would otherwise spin without ever
# quitting. A healthy _initialize is synchronous and reaches _finish on the
# first frame, well under this many frames later.
const WATCHDOG_FRAMES := 600


func _initialize() -> void:
	_assert(
		ClassDB.class_exists("DopeWarsWorld"),
		"the extension class is not registered; the extension did not load",
	)
	_case("abi_version")
	_test_abi_version()
	_case("world_lifecycle")
	_test_world_lifecycle()
	_case("game_step_sequence")
	_test_game_step_sequence()
	_case("partial_sell")
	_test_partial_sell()
	_case("serialize_round_trip")
	_test_serialize_round_trip()
	_case("determinism")
	_test_determinism()
	_case("rules_surface")
	_test_rules_surface()
	_case("prev_prices")
	_test_prev_prices()
	_case("dealer_visits")
	_test_dealer_visits()
	_finish()


## Marks a case as started. Its assertions accumulate until the next _case, so a
## case that throws, returns early, or is never reached ends up short of its
## declared floor in _finish.
func _case(name: String) -> void:
	_current_case = name
	_per_case[name] = 0


## Reconciles the per-case floors and the whole-suite floor, then quits. Guarded
## so the watchdog can call it without double-reporting.
func _finish() -> void:
	if _reconciled:
		return
	_reconciled = true
	for name: String in EXPECTED_ASSERTIONS:
		var expected: int = EXPECTED_ASSERTIONS[name]
		var ran: int = int(_per_case.get(name, 0))
		if ran < expected:
			_failures += 1
			var why := "never ran" if not _per_case.has(name) else "died mid-function"
			printerr("FAIL: case '%s' %s (ran %d assertions, expected %d)" % [name, why, ran, expected])
	if _assertions < MIN_ASSERTIONS:
		_failures += 1
		printerr("FAIL: ran %d assertions, expected at least %d" % [_assertions, MIN_ASSERTIONS])

	if _failures > 0:
		push_error("%d test_bridge failure(s)" % _failures)
		quit(1)
	else:
		print("test_bridge: OK (%d assertions)" % _assertions)
		quit(0)


# Fires only when a synchronous harness error skipped _finish and the tree would
# otherwise never quit; a healthy run reconciles on the first frame.
func _process(_delta: float) -> bool:
	if not _reconciled:
		_frames += 1
		if _frames >= WATCHDOG_FRAMES:
			_finish()
	return false


func _assert(condition: bool, message: String) -> void:
	_per_case[_current_case] = int(_per_case.get(_current_case, 0)) + 1
	_assertions += 1
	if not condition:
		_failures += 1
		printerr("FAIL: %s" % message)


func _new_world(seed: int = 7) -> SimWorld:
	var world := SimWorld.new()
	var result := world.init(seed)
	_assert(result == SimWorld.OK, "world.init() should return DW_OK, got %d" % result)
	return world


func _test_abi_version() -> void:
	var world := SimWorld.new()
	_assert(
		world.abi_version() == SimWorld.ABI_VERSION,
		"abi_version() should equal DW_ABI_VERSION",
	)


func _test_world_lifecycle() -> void:
	var world := _new_world()
	_assert(world.is_ready(), "world should be ready after init")

	var state: Dictionary = world.state_get()
	_assert(state["result"] == SimWorld.OK, "state_get should succeed")
	_assert(state["day"] == 1, "a fresh game starts on day 1")
	_assert(state["cash"] == 2000, "a fresh game starts with 2000 cash")
	_assert(state["debt"] == 5500, "a fresh game starts with 5500 debt")
	_assert(state["health"] == 100, "a fresh game starts with 100 health")
	_assert(state["coat_capacity"] == 100, "a fresh game starts with 100 coat slots")
	_assert(state["location_index"] == 0, "a fresh game starts in the Bronx")

	# A reset is a full new game, not a mid-game reset.
	var damage: Dictionary = world.apply_damage(40)
	_assert(damage["health"] == 60, "apply_damage should reduce health to 60")
	_assert(world.reset() == SimWorld.OK, "reset should succeed")
	_assert(world.state_get()["health"] == 100, "reset should restore health")


func _test_game_step_sequence() -> void:
	var world := _new_world()

	var prices: Array = world.prices_copy()
	_assert(prices.size() > 0, "a fresh game should have a price roster")
	var drug_index: int = prices[0]["drug_index"]

	var cash_before: int = world.state_get()["cash"]
	_assert(world.buy(drug_index, 1) == SimWorld.OK, "buy should succeed")
	var after_buy: Dictionary = world.state_get()
	_assert(after_buy["coat_used"] == 1, "buying one unit should use one coat slot")
	_assert(after_buy["cash"] < cash_before, "buying should reduce cash")

	var inventory: Array = world.inventory_copy()
	_assert(inventory.size() == 1, "inventory should hold one drug")
	_assert(inventory[0]["drug_index"] == drug_index, "inventory should hold the bought drug")
	_assert(inventory[0]["qty"] == 1, "inventory should hold one unit")

	_assert(world.sell(drug_index, 1) == SimWorld.OK, "sell should succeed")
	_assert(world.state_get()["coat_used"] == 0, "selling the unit should free the coat slot")

	_assert(world.travel(2) == SimWorld.OK, "travel should succeed")
	var after_travel: Dictionary = world.state_get()
	_assert(after_travel["day"] == 2, "travel should advance the day")
	_assert(after_travel["location_index"] == 2, "travel should move the player")
	_assert(after_travel["debt"] == 6050, "travel should compound debt by 10%")

	# Finances move money between cash, bank and debt.
	var deposit: Dictionary = world.finances(SimWorld.FINANCES_DEPOSIT, 500)
	_assert(deposit["result"] == SimWorld.OK, "deposit should succeed")
	_assert(deposit["actual"] == 500, "deposit should move 500")
	_assert(world.state_get()["bank"] == 500, "bank should hold the deposit")


## A partial sell. Every other sell in this suite sold the whole holding,
## which is the blind spot that let a UI regression sell 100 units for a typed
## 2 without any engine test noticing. This pins the engine chain itself:
## qty must be honored through GDScript -> C++ -> Mojo, not just accepted.
func _test_partial_sell() -> void:
	var world := _new_world()
	var prices: Array = world.prices_copy()
	var cheapest := int(prices[0]["drug_index"])
	var cheapest_price := int(prices[0]["price"])
	for slot in prices:
		if int(slot["price"]) < cheapest_price:
			cheapest = int(slot["drug_index"])
			cheapest_price = int(slot["price"])
	_assert(
		cheapest_price * 10 <= int(world.state_get()["cash"]),
		"ten of the cheapest drug should be affordable at the start (price %d)" % cheapest_price,
	)
	_assert(world.buy(cheapest, 10) == SimWorld.OK, "buying ten of the cheapest drug should succeed")
	_assert(world.sell(cheapest, 3) == SimWorld.OK, "selling three of the ten should succeed")
	_assert(_held(world, cheapest) == 7, "selling three of ten should leave seven")
	_assert(int(world.state_get()["coat_used"]) == 7, "the coat should hold exactly the seven unsold units")


static func _held(world: SimWorld, drug_index: int) -> int:
	for slot in world.inventory_copy():
		if int(slot["drug_index"]) == drug_index:
			return int(slot["qty"])
	return 0


func _test_serialize_round_trip() -> void:
	var world := _new_world()
	var prices: Array = world.prices_copy()
	_assert(world.buy(prices[0]["drug_index"], 1) == SimWorld.OK, "buy should succeed")
	_assert(world.travel(1) == SimWorld.OK, "travel should succeed")

	var dump: Dictionary = world.world_dump()
	_assert(dump["result"] == SimWorld.OK, "world_dump should succeed")
	var bytes: PackedByteArray = dump["bytes"]
	_assert(bytes.size() == world.world_dump_len(), "dump length should match world_dump_len()")

	var restored := SimWorld.new()
	_assert(restored.init(1) == SimWorld.OK, "restored world should init")
	_assert(restored.world_load(bytes) == SimWorld.OK, "world_load should succeed")

	var restored_state: Dictionary = restored.state_get()
	_assert(restored_state["day"] == 2, "restored world should be on day 2")
	_assert(restored_state["location_index"] == 1, "restored world should be in the Ghetto")

	var redump: Dictionary = restored.world_dump()
	_assert(redump["bytes"] == bytes, "dump -> load -> dump should be byte-identical")

	# A truncated buffer is rejected and leaves the world unchanged.
	var truncated := bytes.slice(0, bytes.size() - 1)
	_assert(
		restored.world_load(truncated) == SimWorld.ERR_SERIALIZATION_FAILED,
		"a truncated dump should be rejected",
	)
	_assert(restored.world_dump()["bytes"] == bytes, "a failed load should not mutate the world")
	_assert(
		restored.state_get()["result"] == SimWorld.OK,
		"a rejected load should not brick the handle's other world calls",
	)

	# A handle that never held a world stays refused after a failed load, so a
	# corrupt save is still discarded on boot and the next game starts clean
	# (index.html:1544-1553).
	var fresh := SimWorld.new()
	_assert(
		fresh.world_load(truncated) == SimWorld.ERR_SERIALIZATION_FAILED,
		"an uninitialized world should refuse a truncated dump",
	)
	_assert(not fresh.is_ready(), "a failed load should not make a fresh handle ready")
	_assert(
		fresh.state_get()["result"] == SimWorld.ERR_INVALID_ARGUMENT,
		"a fresh handle should still refuse world calls after a failed load",
	)


func _test_determinism() -> void:
	var a := _new_world(7)
	var b := _new_world(7)
	_assert(a.world_dump()["bytes"] == b.world_dump()["bytes"], "same seed should produce the same dump")

	var c := _new_world(8)
	_assert(a.world_dump()["bytes"] != c.world_dump()["bytes"], "different seeds should diverge")


func _test_rules_surface() -> void:
	var world := SimWorld.new()
	var locations: Array = world.rules_locations()
	_assert(locations.size() == SimWorld.NUM_LOCATIONS, "there should be 6 locations")
	_assert(locations[0]["id"] == "bronx", "the first location should be the Bronx")

	var drugs: Array = world.rules_drugs()
	_assert(drugs.size() == SimWorld.NUM_DRUGS, "there should be 12 drugs")
	_assert(drugs[0]["id"] == "acid", "the first drug should be acid")

	var found: Dictionary = world.find_drug_index("weed")
	_assert(found["result"] == SimWorld.OK, "weed should be a known drug")
	_assert(found["index"] == 11, "weed should be drug index 11")
	_assert(
		world.find_drug_index("nope")["result"] == SimWorld.ERR_UNKNOWN_DRUG,
		"an unknown drug should be rejected",
	)


# TASK-001.06 added both of these. Neither is covered by tests/fixtures/*.jsonl,
# which only replays what the core already exported at TASK-001.05, so the
# bridge is where their behavior is pinned.


## dw_prev_prices_copy exists for the market table's trend glyph, so the
## contract that matters is: empty on day 1, and after a travel the previous
## turn's roster comes back rather than the current one.
func _test_prev_prices() -> void:
	var world := _new_world()
	_assert(world.prev_prices_copy().is_empty(), "day 1 should have no previous prices")

	var day_one: Array = world.prices_copy()
	_assert(world.travel(1) == SimWorld.OK, "travel should succeed")

	var previous: Array = world.prev_prices_copy()
	var current: Array = world.prices_copy()
	_assert(previous.size() == day_one.size(), "prev prices should be the roster we left behind")
	_assert(previous.size() > 0, "there should be previous prices after a travel")

	# The two rosters are independent, so a drug traded now but not before
	# must not appear in the previous list. That is the case the trend glyph
	# has to tolerate.
	var current_only: Array[int] = []
	for slot in current:
		var found := false
		for prior in previous:
			if prior["drug_index"] == slot["drug_index"]:
				found = true
				break
		if not found:
			current_only.append(int(slot["drug_index"]))
	_assert(current_only.size() > 0, "the two rosters should differ, or the trend test proves nothing")

	# Prices carried over verbatim from the day-one roster.
	for prior in previous:
		for original in day_one:
			if original["drug_index"] == prior["drug_index"]:
				_assert(
					original["price"] == prior["price"],
					"a previous price should equal the day-one price for the same drug",
				)
				break


## dw_roll_dealer_visits is the one addition that consumes RNG, so the
## properties worth pinning are that it is deterministic for a seed, that it
## advances the stream by exactly two draws, and that a dead player gets no
## dealer even though the draws still happen.
func _test_dealer_visits() -> void:
	var a := _new_world(11)
	var b := _new_world(11)
	var first: Dictionary = a.roll_dealer_visits()
	var second: Dictionary = b.roll_dealer_visits()
	_assert(first["result"] == SimWorld.OK, "roll_dealer_visits should succeed")
	_assert(
		first["coat_visit"] == second["coat_visit"] and first["gun_visit"] == second["gun_visit"],
		"the same seed should produce the same dealer visits",
	)

	# Each call consumes two draws, so a second call on the same world has to
	# land on a different pair of RNG values.
	var after: Dictionary = a.roll_dealer_visits()
	_assert(after["result"] == SimWorld.OK, "a second roll_dealer_visits should succeed")
	_assert(
		a.world_dump()["bytes"] != b.world_dump()["bytes"],
		"rolling the dealer visits should advance the world's RNG stream",
	)

	# A dead player is never visited, but the roll is still spent -- the JS
	# evaluates state.rng() before the !state.dead guard.
	var dead := _new_world(11)
	dead.apply_damage(100)
	var suppressed: Dictionary = dead.roll_dealer_visits()
	_assert(
		not bool(suppressed["coat_visit"]) and not bool(suppressed["gun_visit"]),
		"a dead player should be visited by neither dealer",
	)
	var live_twin := _new_world(11)
	live_twin.roll_dealer_visits()
	_assert(
		dead.world_dump()["bytes"] != live_twin.world_dump()["bytes"],
		"a dead player's dealer roll should still consume its draws",
	)
