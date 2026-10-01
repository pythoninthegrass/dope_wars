extends Node

# UI flow regression test (TASK-001.06 AC#5).
#
# Drives the real Main scene through the same entry points the keyboard and the
# buttons use, and asserts on what the widgets actually render. The one thing it
# does not do is reach past Main: game/godot_tests/bridge_test.gd covers the
# extension, this covers the presentation layer on top of it.
#
# Everything here is deterministic. Each case starts a fresh game on a fixed
# seed through Main.start_new_game(), so a run is reproducible and a failure is
# a real regression rather than an unlucky roll.
#
# Scene-driven rather than --script driven because it needs a live SceneTree to
# build and lay out the window in. Run headless: task game:ui-test

const SEED := 20260927

var _passed := 0
var _failures: Array[String] = []
var _main: Main = null
var _per_case := {}
var _reconciled := false
var _frames := 0

# Backstop for a synchronous error in _ready before _finish: it aborts _ready
# (or the awaited run) and the scene would otherwise spin without ever quitting.
# A healthy run reaches _finish well under this many frames later.
const WATCHDOG_FRAMES := 600


func _ready() -> void:
	_main = load("res://presentation/main.tscn").instantiate() as Main
	if _main == null:
		_fail("harness", "res://presentation/main.tscn did not instantiate as Main")
		_finish()
		return
	add_child(_main)

	await _run()

	_finish()


## Every case is named here, and every one has to have run at least one
## assertion. A hard-coded total would drift the moment a case gained or lost
## a check; "each case ran" is a property that stays true as they change. The
## per-case count is what makes a case that ran but asserted nothing a failure
## rather than a silent pass.
const CASES := [
	"translation_keys_resolve",
	"new_game_boot",
	"keyboard_shortcuts",
	"buy_sell_round_trip",
	"click_rebuilds_table",
	"travel_advances_day",
	"persistence_round_trip",
	"finances",
	"typed_quantity",
	"endgame_and_highscores",
	"new_game_dialog",
	"win98_chrome",
	"window_pinned",
	"tables_fit_twelve_drugs",
]

## Per-case assertion floor. Each case declares the number of assertions it runs
## on the happy path for the fixed seed; a case that dies partway -- a GDScript
## runtime error, an unexpected null, an early return that skips its remaining
## work -- runs fewer and is a named failure. The old "asserted nothing" check
## only caught a case that ran zero assertions; a case that died on its second
## check sailed past it. Keep these in sync when a case gains or loses a check.
const CASE_FLOORS := {
	"translation_keys_resolve": 210,
	"new_game_boot": 22,
	"keyboard_shortcuts": 21,
	"buy_sell_round_trip": 18,
	"click_rebuilds_table": 11,
	"travel_advances_day": 12,
	"persistence_round_trip": 16,
	"finances": 7,
	"typed_quantity": 21,
	"endgame_and_highscores": 16,
	"new_game_dialog": 9,
	"win98_chrome": 82,
	"window_pinned": 5,
	"tables_fit_twelve_drugs": 4,
}

## A coarse backstop for the case registry itself: if every case reported but
## somehow asserted almost nothing, the run is still wrong.
const MIN_ASSERTIONS := 200


func _run() -> void:
	_case("translation_keys_resolve")
	_test_translation_keys_resolve()
	_case("new_game_boot")
	_test_new_game_boot()
	_case("keyboard_shortcuts")
	_test_keyboard_shortcuts()
	_case("buy_sell_round_trip")
	await _test_buy_sell_round_trip()
	_case("click_rebuilds_table")
	await _test_click_rebuilds_table()
	_case("travel_advances_day")
	await _test_travel_advances_day()
	_case("persistence_round_trip")
	await _test_persistence_round_trip()
	_case("finances")
	await _test_finances()
	_case("typed_quantity")
	await _test_typed_quantity()
	_case("endgame_and_highscores")
	await _test_endgame_and_highscores()
	_case("new_game_dialog")
	await _test_new_game_dialog()
	_case("win98_chrome")
	_test_win98_chrome()
	_case("window_pinned")
	_test_window_pinned()
	_case("tables_fit_twelve_drugs")
	await _test_tables_fit_twelve_drugs()


# docs/layer-boundaries.md:113-114 puts every display string behind tr(). A key
# with no row in translations/strings.csv renders as the key itself, which is
# exactly the sort of failure that survives review because the code reads fine.
# The first draft of the CSV hit the related one: an unquoted value with a comma
# in it parsed as extra columns and the window title read "Dope Wars".
func _test_translation_keys_resolve() -> void:
	# A key constant in copy.gd is an ALL_CAPS identifier assigned to itself;
	# the other consts in that file are display glyphs and prose.
	var pattern := RegEx.new()
	_assert(pattern.compile('const\\s+([A-Z][A-Z0-9_]*)\\s*:?=\\s*"\\1"') == OK, "the key-extraction regex should compile")

	var source := FileAccess.get_file_as_string("res://content/copy.gd")
	_assert(not source.is_empty(), "content/copy.gd should be readable")

	var declared: Array[String] = []
	for found in pattern.search_all(source):
		declared.append(found.get_string(1))
	_assert(declared.size() > 40, "copy.gd should declare many keys, found %d" % declared.size())

	var csv := FileAccess.get_file_as_string("res://translations/strings.csv")
	_assert(not csv.is_empty(), "translations/strings.csv should be readable")
	var table := {}
	for line in csv.split("\n"):
		if line.strip_edges().is_empty() or line.begins_with("keys,"):
			continue
		var comma := line.find(",")
		if comma > 0:
			table[line.substr(0, comma)] = true

	for key in declared:
		_assert(table.has(key), "copy.gd declares key %s with no row in strings.csv" % key)
		_assert(Copy.t(key) != key, "key %s did not resolve -- it would render as the key itself" % key)


# --- cases ------------------------------------------------------------------


# index.html:1700-1706, render() at :1128-1164. A fresh game must paint the
# title, all four LEDs, the health bar, and one market row per traded drug.
func _test_new_game_boot() -> void:
	var world := _fresh(SEED)
	var state := world.state_get()
	var hud := _main.hud()

	_assert(
		hud.title_text() == "Day %d of %d" % [state["day"], state["num_days"]],
		"the day readout should read 'Day 1 of 31', got '%s'" % hud.title_text()
	)
	_assert(hud.led_text("cash") == "2.000", "cash LED should be 2.000, got '%s'" % hud.led_text("cash"))
	_assert(hud.led_text("bank") == "0", "bank LED should be 0, got '%s'" % hud.led_text("bank"))
	_assert(hud.led_text("debt") == "5.500", "debt LED should be 5.500, got '%s'" % hud.led_text("debt"))
	_assert(hud.led_text("guns") == "0", "guns LED should be 0, got '%s'" % hud.led_text("guns"))

	var market := hud.market_table()
	var traded: Array = world.prices_copy()
	_assert(market.row_count() == traded.size(), "market table should have one row per traded drug (%d vs %d)" % [market.row_count(), traded.size()])
	_assert(market.row_count() > 0, "a fresh game should trade something")

	# index.html:1185 -- the price cell is the rounded, comma-grouped price.
	for slot in traded:
		var drug_index := int(slot["drug_index"])
		_assert(
			market.price_text(drug_index) == Copy.fmt(int(slot["price"])),
			"row for drug %d should read %s, got '%s'" % [drug_index, Copy.fmt(int(slot["price"])), market.price_text(drug_index)]
		)

	# index.html:1140-1142 -- day 1 hides the subway panel and hides Finish.
	_assert(
		hud.borough_panel_visible() == (int(state["day"]) < int(state["num_days"])),
		"the subway panel visibility should track the last day (day %d of %d, visible=%s)"
		% [state["day"], state["num_days"], hud.borough_panel_visible()]
	)
	_assert(hud.finish_panel_visible() == (int(state["day"]) >= int(state["num_days"])), "the finish panel should track the last day")

	# index.html:1177 -- no trend glyph on day 1, because nothing came before it.
	_assert(
		market.trend_text(int(traded[0]["drug_index"])) == "",
		"day 1 prices should carry no trend glyph"
	)

	# Nothing is selected on a new game, so both actions are disabled
	# (index.html:1217-1218).
	_assert(not hud.can_buy(), "Buy should be disabled with no drug selected")
	_assert(not hud.can_sell(), "Sell should be disabled with no drug selected")


# index.html:1676-1698. The router is a pure function, so the whole shortcut
# table is checkable without synthesizing events into a live Input singleton.
func _test_keyboard_shortcuts() -> void:
	var cases := {
		KEY_1: &"travel_0",
		KEY_2: &"travel_1",
		KEY_3: &"travel_2",
		KEY_4: &"travel_3",
		KEY_5: &"travel_4",
		KEY_6: &"travel_5",
		KEY_B: &"buy",
		KEY_S: &"sell",
		KEY_F: &"finances",
		KEY_N: &"new_game",
		KEY_ENTER: &"confirm",
		KEY_ESCAPE: &"cancel",
	}
	for keycode: Key in cases:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = true
		_assert(
			InputRouter.classify(event) == cases[keycode],
			"key %d should classify as %s, got %s" % [keycode, cases[keycode], InputRouter.classify(event)]
		)

	# index.html:1688 -- keys are only lowercased, so both cases mean the same.
	var shifted := InputEventKey.new()
	shifted.keycode = KEY_B
	shifted.pressed = true
	shifted.shift_pressed = true
	_assert(InputRouter.classify(shifted) == &"buy", "shift+B should still be Buy")

	# A keyup and a key-repeat are not shortcuts.
	var released := InputEventKey.new()
	released.keycode = KEY_B
	released.pressed = false
	_assert(InputRouter.classify(released) == InputRouter.NONE, "a keyup should not classify")
	var echoed := InputEventKey.new()
	echoed.keycode = KEY_B
	echoed.pressed = true
	echoed.echo = true
	_assert(InputRouter.classify(echoed) == InputRouter.NONE, "a key repeat should not classify")

	for index in range(InputRouter.travel_index(&"travel_4") + 1):
		_assert(
			InputRouter.travel_index(StringName("travel_%d" % index)) == index,
			"travel_%d should carry payload %d" % [index, index]
		)
	_assert(InputRouter.travel_index(&"buy") == -1, "a non-travel intent should carry no borough index")


# index.html:1282-1326. Buy moves cash into the coat, sell moves it back, and
# both re-render the LEDs and the coat table.
func _test_buy_sell_round_trip() -> void:
	var world := _fresh(SEED)
	var hud := _main.hud()
	# Cheapest, not first: the fixture harness does the same, and a roster
	# whose first entry costs more than the starting cash would make this
	# exercise the "Duh! Check the price" alert instead of the spinner.
	var drug_index := _cheapest_traded(world)
	var price := _price_of(world, drug_index)
	var cash_before := int(world.state_get()["cash"])
	_assert(price > 0, "there should be a traded drug to buy")
	_assert(int(floor(float(cash_before) / float(price))) >= 3, "the cheapest drug should be affordable for a 3-unit round trip")

	# index.html:1186-1190 -- clicking a market row selects it for buying. The
	# click's notify is deferred out of the Tree's selection event, so the
	# selection and its render land on the next frame, not on this line.
	_main.hud().market_drug_pressed(drug_index)
	await _idle()
	_assert(hud.selected_buy_drug == drug_index, "clicking a market row should select it for buying")
	_assert(hud.can_buy(), "Buy should be enabled for a traded drug (selected=%d, rows=%d)" % [hud.selected_buy_drug, hud.market_table().row_count()])

	_main._do_buy()
	await _idle()
	var dialog := _main.dialogs().current() as QuantityDialog
	_assert(dialog != null, "Buy should open a quantity dialog")
	if dialog == null:
		return
	# index.html:1287-1297 -- the spinner is bounded by cash and by coat room.
	var expected_limit := mini(int(floor(float(cash_before) / float(price))), int(world.state_get()["coat_capacity"]))
	_assert(dialog.max_value() == expected_limit, "the buy spinner should cap at %d, got %d" % [expected_limit, dialog.max_value()])
	dialog.set_value(3)
	_main.dialogs().confirm()
	await _idle()

	_assert(int(world.state_get()["cash"]) == cash_before - price * 3, "buying 3 units should cost exactly 3x the price")
	_assert(hud.led_text("cash") == Copy.led_fmt(cash_before - price * 3), "the cash LED should follow the purchase")
	_assert(hud.coat_table().row_count() == 1, "the coat table should list the drug we just bought")
	_assert(hud.coat_table().quantity_text(drug_index) == "3", "the coat table should show 3 units")
	# index.html:1163's render() never re-derives the selections, so a purchase
	# on its own leaves the sell selection where the click left it -- null when
	# the player only clicked the market. Selling is reached by clicking the
	# coat row, which is what the next step does.
	_assert(hud.selected_sell_drug == -1, "a purchase should not re-derive the sell selection")

	# Now sell it back at the same price, which is what a same-turn round trip
	# is: the market has not regenerated.
	_main.hud().coat_drug_pressed(drug_index)
	await _idle()
	_assert(hud.selected_sell_drug == drug_index, "clicking a coat row should select it for selling")
	_assert(hud.can_sell(), "Sell should be enabled for a held, traded drug")
	_main._do_sell()
	await _idle()
	var sell := _main.dialogs().current() as QuantityDialog
	_assert(sell != null, "Sell should open a quantity dialog")
	if sell == null:
		return
	_assert(sell.max_value() == 3, "the sell spinner should cap at the held quantity")
	sell.set_value(3)
	_main.dialogs().confirm()
	await _idle()

	_assert(int(world.state_get()["cash"]) == cash_before, "a same-price round trip should return the cash exactly")
	_assert(hud.coat_table().row_count() == 0, "selling the last unit should empty the coat table")
	_assert(hud.led_text("cash") == Copy.led_fmt(cash_before), "the cash LED should be back to where it started")


# index.html:1186-1190 and :1207-1211. Both click handlers end in a full
# render(), which rebuilds the very <tr> that was just clicked. A Tree refuses
# to clear itself or create items while it is still inside its own
# mouse-selection event, so the rebuild has to leave the event first -- and when
# it does not, refresh() dies partway through and the table comes back empty.
#
# market_drug_pressed() cannot see this: it is a programmatic set_selected,
# which never arms the guard. These clicks are pushed through the live
# viewport, so the Tree's own gui_input does the selecting.
func _test_click_rebuilds_table() -> void:
	var world := _fresh(SEED)
	var hud := _main.hud()
	var market := hud.market_table()
	var traded: Array = world.prices_copy()
	var drug_index := int(traded[0]["drug_index"])
	var price := _price_of(world, drug_index)
	await _idle()

	await _click_row(market.tree(), drug_index)

	# The click has to have landed, or every assertion below is vacuous.
	_assert(
		hud.selected_buy_drug == drug_index,
		"a routed click on a market row should select it (selected=%d, clicked=%d)" % [hud.selected_buy_drug, drug_index]
	)
	# index.html:1187-1188 -- the sell selection follows only if the drug is
	# held, and nothing is held yet.
	_assert(hud.selected_sell_drug == -1, "clicking an unheld market row should leave nothing selected to sell, got %d" % hud.selected_sell_drug)
	_assert(
		market.row_count() == traded.size(),
		"the market table should still hold a row per traded drug after a click (%d vs %d)" % [market.row_count(), traded.size()]
	)
	_assert(
		market.price_text(drug_index) == Copy.fmt(price),
		"the clicked row should still read its price, got '%s'" % market.price_text(drug_index)
	)
	_assert(hud.can_buy(), "Buy should be enabled after clicking a traded drug")

	# The coat table is the same click shape, so hold something first: an empty
	# coat has no row to click.
	_main._do_buy()
	await _idle()
	var dialog := _main.dialogs().current() as QuantityDialog
	if dialog != null:
		dialog.set_value(1)
		_main.dialogs().confirm()
	await _idle()
	_assert(hud.coat_table().row_count() == 1, "the purchase should put one drug in the coat, got %d rows" % hud.coat_table().row_count())
	if hud.coat_table().row_count() != 1:
		return

	await _click_row(hud.coat_table().tree(), drug_index)

	_assert(
		hud.selected_sell_drug == drug_index,
		"a routed click on a coat row should select it for selling, got %d" % hud.selected_sell_drug
	)
	# index.html:1208-1209 -- no null-out on this side; the buy selection follows.
	_assert(hud.selected_buy_drug == drug_index, "a coat click should carry the buy selection along, got %d" % hud.selected_buy_drug)
	_assert(hud.coat_table().row_count() == 1, "the coat table should still hold its row after a click, got %d" % hud.coat_table().row_count())
	_assert(
		hud.coat_table().quantity_text(drug_index) == "1",
		"the coat row should still read its quantity, got '%s'" % hud.coat_table().quantity_text(drug_index)
	)
	_assert(hud.can_sell(), "Sell should be enabled after clicking a held, traded drug")


# index.html:1369-1376 plus the arrival queue at :1378-1470. Travel advances the
# day, moves the player, and raises a modal sequence that drains back to the HUD.
func _test_travel_advances_day() -> void:
	var world := _fresh(SEED)
	var hud := _main.hud()
	var destination := SimWorld.NUM_LOCATIONS - 1
	var from_day := int(world.state_get()["day"])

	hud.borough_pressed(destination)
	await _idle()

	_assert(int(world.state_get()["day"]) == from_day + 1, "travel should advance the day")
	_assert(int(world.state_get()["location_index"]) == destination, "travel should move the player")
	_assert(
		hud.title_text() == "Day %d of 31" % (from_day + 1),
		"the day readout should show the new day, got '%s'" % hud.title_text()
	)
	_assert(hud.selected_buy_drug == -1 and hud.selected_sell_drug == -1, "travel should clear both selections (index.html:1372-1373)")
	_assert(hud.led_text("debt") == Copy.led_fmt(world.state_get()["debt"]), "the debt LED should show the compounded debt")

	# Day 2 is when the trend glyph appears, because there is finally a previous
	# roster to compare against (index.html:1176).
	var traded: Array = world.prices_copy()
	_assert(traded.size() > 0, "the new borough should trade something")
	var with_glyph := 0
	for slot in traded:
		if hud.market_table().trend_text(int(slot["drug_index"])) in [
			Copy.TREND_UP, Copy.TREND_DOWN, Copy.TREND_NEUTRAL
		]:
			with_glyph += 1
	_assert(with_glyph == traded.size(), "every day-2 price should carry a trend glyph")

	# The arrival sequence: price-event toasts, at most one arrival event, then
	# at most one dealer per roll. Confirming each dialog drains it.
	var guard := 0
	while _main.dialogs().is_open():
		guard += 1
		_assert(guard < 20, "the arrival sequence should drain, not loop forever")
		if guard >= 20:
			break
		_main.dialogs().confirm()
		await _idle()

	_assert(not _main.dialogs().is_open(), "the arrival sequence should end with no dialog open")
	_assert(not _main.arrival().is_active(), "the arrival flow should report itself finished")
	_assert(hud.market_table().row_count() == traded.size(), "the market table should show the new borough's roster")


# index.html:1539-1553. The save is the core's opaque dump written to user://,
# and loading it into a fresh world must land on the same game.
func _test_persistence_round_trip() -> void:
	var world := _fresh(SEED)
	var hud := _main.hud()

	# Put the game somewhere non-trivial before saving.
	var drug_index := _cheapest_traded(world)
	hud.select_buy_drug(drug_index)
	_main._do_buy()
	await _idle()
	var buy := _main.dialogs().current() as QuantityDialog
	if buy != null:
		buy.set_value(2)
		_main.dialogs().confirm()
	await _idle()
	_main._do_travel(SimWorld.NUM_LOCATIONS - 1)
	await _idle()
	await _drain()

	var before: Dictionary = world.state_get()
	var before_bytes: PackedByteArray = world.world_dump()["bytes"]
	_assert(world.world_dump()["result"] == SimWorld.OK, "the world should dump for the autosave")
	_assert(FileAccess.file_exists(SaveStore.SAVE_PATH), "the autosave should have written %s" % SaveStore.SAVE_PATH)

	# Resuming is a *cold* start: the handle has never been initialized, so
	# dw_world_load has to be able to build a world out of the payload alone.
	# The shim used to gate world_load on is_ready(), which made every fresh
	# process refuse its own save.
	var cold := SimWorld.new()
	_assert(not cold.is_ready(), "a brand-new world should not be ready before a load")
	_assert(SaveStore.new().load_into(cold), "an uninitialized world should load the save")
	_assert(cold.is_ready(), "a world should be ready after a successful load")
	_assert(
		int(cold.state_get()["day"]) == int(before["day"]),
		"the cold load should land on day %d, got %s" % [before["day"], cold.state_get().get("day")]
	)

	# Booting a second Main has to resume the save, not start a new game.
	var title_before := hud.title_text()
	_assert(title_before.contains("Day %d" % int(before["day"])), "the live HUD should show day %d, got '%s'" % [before["day"], title_before])
	var reloaded: Main = load("res://presentation/main.tscn").instantiate() as Main
	add_child(reloaded)
	await reloaded.get_tree().process_frame
	var restored := reloaded.simulation()

	var after: Dictionary = restored.state_get()
	_assert(
		int(after["day"]) == int(before["day"]),
		"the reloaded game should resume on day %d, got %s" % [before["day"], after.get("day")]
	)
	_assert(
		int(after["cash"]) == int(before["cash"]),
		"the reloaded game should resume with cash %d, got %s" % [before["cash"], after.get("cash")]
	)
	_assert(
		int(after["location_index"]) == int(before["location_index"]),
		"the reloaded game should resume in borough %d, got %s" % [before["location_index"], after.get("location_index")]
	)
	_assert(
		reloaded.hud().title_text() == title_before,
		"the reloaded HUD should render the resumed day, got '%s'" % reloaded.hud().title_text()
	)
	_assert(
		restored.world_dump()["bytes"] == before_bytes,
		"load -> dump should be byte-identical to the save that produced it"
	)
	_assert(reloaded.hud().market_table().row_count() == restored.prices_copy().size(), "the reloaded market table should render the saved roster")

	# A corrupt save is deleted rather than trusted, so the next boot starts
	# fresh instead of failing forever (index.html:1544-1553).
	var file := FileAccess.open(SaveStore.SAVE_PATH, FileAccess.WRITE)
	file.store_buffer(PackedByteArray([1, 2, 3]))
	file = null
	var discarded := SimWorld.new()
	_assert(discarded.init(SEED) == SimWorld.OK, "the throwaway world should init")
	_assert(not SaveStore.new().load_into(discarded), "a corrupt save should be refused")
	_assert(not FileAccess.file_exists(SaveStore.SAVE_PATH), "a refused save should be deleted")

	reloaded.queue_free()


# index.html:1328-1365. Deposit moves cash to the bank; the finances dialog
# re-opens itself afterwards, which is the prototype's render(); doFinances().
func _test_finances() -> void:
	var world := _fresh(SEED)
	var cash_before := int(world.state_get()["cash"])

	_main._do_finances()
	await _idle()
	_assert(_main.dialogs().current() is FinancesDialog, "Finances should open a finances dialog")

	_main._on_finances_action("finDeposit")
	await _idle()
	var amount := _main.dialogs().current() as QuantityDialog
	_assert(amount != null, "Deposit should open a quantity dialog")
	if amount == null:
		return
	_assert(amount.max_value() == cash_before, "the deposit spinner should cap at the cash on hand")
	amount.set_value(400)
	_main.dialogs().confirm()
	await _idle()

	_assert(int(world.state_get()["bank"]) == 400, "depositing 400 should put 400 in the bank")
	_assert(int(world.state_get()["cash"]) == cash_before - 400, "depositing 400 should take 400 out of cash")
	_assert(_main.dialogs().current() is FinancesDialog, "the finances dialog should re-open after a deposit (index.html:1348)")
	_assert(_main.hud().led_text("bank") == "400", "the bank LED should follow the deposit")


# The typed-text path every other case skips. set_value() writes the Range
# directly -- the one thing a player never does. Typing lands in the SpinBox's
# internal LineEdit, and the prototype read that text straight on OK
# (index.html:1276), while Enter confirmed and Escape cancelled from inside
# the field (index.html:1676-1686). A port that reads the Range instead of the
# typed text acts on the spinner's initial value -- the whole holding -- and a
# port whose LineEdit swallows Enter/Escape is keyboard-deaf in the one field
# the player is actually using. Both bugs were real here; this case pins both
# against the prototype's semantics.
func _test_typed_quantity() -> void:
	var world := _fresh(SEED)
	var hud := _main.hud()
	var drug_index := _cheapest_traded(world)
	var price := _price_of(world, drug_index)

	_main.hud().market_drug_pressed(drug_index)
	await _idle()
	_main._do_buy()
	await _idle()
	var buy_dialog := _main.dialogs().current() as QuantityDialog
	_assert(buy_dialog != null, "Buy should open a quantity dialog")
	if buy_dialog == null:
		return
	buy_dialog.set_value(3)
	_main.dialogs().confirm()
	await _idle()
	_assert(_held(world, drug_index) == 3, "the setup should hold three units")

	# Type "2" and click OK: two units sell, not the three the spinner was
	# initialized with.
	_main.hud().coat_drug_pressed(drug_index)
	await _idle()
	_main._do_sell()
	await _idle()
	var sell := _main.dialogs().current() as QuantityDialog
	_assert(sell != null, "Sell should open a quantity dialog")
	if sell == null:
		return
	var cash_before := int(world.state_get()["cash"])
	_quantity_line_edit(sell).text = "2"
	_main.dialogs().confirm()
	await _idle()
	_assert(
		int(world.state_get()["cash"]) == cash_before + 2 * price,
		"typing 2 into the sell spinner should sell exactly 2 units (cash %d, was %d, price %d)"
		% [int(world.state_get()["cash"]), cash_before, price]
	)
	_assert(_held(world, drug_index) == 1, "selling 2 of 3 should leave 1 held, got %d" % _held(world, drug_index))

	# Enter inside the field confirms (the prototype clicked qtyOk from the
	# input, index.html:1682-1684). The LineEdit consumes the key, so the
	# dialog has to be listening for it there; pressing it on the field is the
	# route a player takes.
	_main._do_sell()
	await _idle()
	var sell_enter := _main.dialogs().current() as QuantityDialog
	_assert(sell_enter != null, "Sell should reopen for the Enter case")
	if sell_enter == null:
		return
	var enter_line := _quantity_line_edit(sell_enter)
	enter_line.text = "1"
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	enter_line.gui_input.emit(enter)
	await _idle()
	_assert(not _main.dialogs().is_open(), "Enter in the spinner should confirm the dialog")
	_assert(
		int(world.state_get()["cash"]) == cash_before + 3 * price,
		"Enter should commit the typed amount, cash %d, expected %d" % [int(world.state_get()["cash"]), cash_before + 3 * price]
	)
	_assert(hud.coat_table().row_count() == 0, "selling the last unit should empty the coat table")

	# Escape inside the field cancels (index.html:1679-1681), selling nothing.
	_main.hud().market_drug_pressed(drug_index)
	await _idle()
	_main._do_buy()
	await _idle()
	var rebuy := _main.dialogs().current() as QuantityDialog
	_assert(rebuy != null, "Buy should reopen for the Escape case")
	if rebuy == null:
		return
	rebuy.set_value(1)
	_main.dialogs().confirm()
	await _idle()
	var cash_after_rebuy := int(world.state_get()["cash"])
	_main.hud().coat_drug_pressed(drug_index)
	await _idle()
	_main._do_sell()
	await _idle()
	var sell_esc := _main.dialogs().current() as QuantityDialog
	_assert(sell_esc != null, "Sell should reopen for the Escape case")
	if sell_esc == null:
		return
	_quantity_line_edit(sell_esc).text = "1"
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	_quantity_line_edit(sell_esc).gui_input.emit(escape)
	await _idle()
	_assert(not _main.dialogs().is_open(), "Escape in the spinner should cancel the dialog")
	_assert(_held(world, drug_index) == 1, "Escape should sell nothing, %d held" % _held(world, drug_index))
	_assert(int(world.state_get()["cash"]) == cash_after_rebuy, "Escape should not move cash")

	# A field the player cleared commits nothing, which is index.html:1276's
	# `parseInt('') || 0`. The distinction from an untouched field is that the
	# text changed and then emptied; the text_changed signal is what records
	# that, and a keystroke is what raises it.
	_main.hud().coat_drug_pressed(drug_index)
	await _idle()
	_main._do_sell()
	await _idle()
	var sell_cleared := _main.dialogs().current() as QuantityDialog
	_assert(sell_cleared != null, "Sell should reopen for the cleared-field case")
	if sell_cleared == null:
		return
	var cleared_line := _quantity_line_edit(sell_cleared)
	cleared_line.text = "1"
	cleared_line.text_changed.emit(cleared_line.text)
	cleared_line.text = ""
	_main.dialogs().confirm()
	await _idle()
	_assert(not _main.dialogs().is_open(), "a cleared field should still confirm the dialog")
	_assert(_held(world, drug_index) == 1, "a cleared field should sell nothing, %d held" % _held(world, drug_index))
	_assert(int(world.state_get()["cash"]) == cash_after_rebuy, "a cleared field should not move cash")

	# The same typed path through Deposit: 500 typed moves 500, not the
	# spinner's initial value of the whole cash pile.
	var cash_before_deposit := int(world.state_get()["cash"])
	_main._do_finances()
	await _idle()
	_main._on_finances_action("finDeposit")
	await _idle()
	var deposit := _main.dialogs().current() as QuantityDialog
	_assert(deposit != null, "Deposit should open a quantity dialog")
	if deposit == null:
		return
	_quantity_line_edit(deposit).text = "500"
	_main.dialogs().confirm()
	await _idle()
	_assert(
		int(world.state_get()["bank"]) == 500,
		"typing 500 into the deposit spinner should deposit exactly 500, got %d" % int(world.state_get()["bank"])
	)
	_assert(
		int(world.state_get()["cash"]) == cash_before_deposit - 500,
		"the deposit should leave the rest of the cash alone, got %d of %d" % [int(world.state_get()["cash"]), cash_before_deposit]
	)
	_main.dialogs().cancel()
	await _idle()


# index.html:1569-1606 and :1633-1638. Finishing ends the run, offers the
# score entry, and the store keeps a top-10 sorted by score -- with the date
# surviving the round trip through the core, which drops it.
func _test_endgame_and_highscores() -> void:
	var world := _fresh(SEED)
	var store := HighscoreStore.new()
	store.clear_all()

	# index.html:1633-1638 -- Finish ends the run and offers the score.
	_main._do_finish()
	await _idle()
	var dialog := _main.dialogs().current() as HighscoreDialog
	_assert(dialog != null, "Finish should open the score-entry dialog")
	if dialog == null:
		return

	# A finish the player did not survive is not marked dead, and the score is
	# cash + bank - debt (index.html:1021-1024).
	var expected := int(world.state_get()["cash"]) + int(world.state_get()["bank"]) - int(world.state_get()["debt"])
	_assert(
		_copy_text(dialog).contains(Copy.fmt(expected)),
		"the score dialog should show the net worth %d, got '%s'" % [expected, _copy_text(dialog)]
	)
	_assert(dialog.entered_name() == "Player", "the name field should default to Player")

	_main.dialogs().confirm()
	await _idle()

	var table := store.load_all()
	_assert(table.size() == 1, "saving a score should persist one row, got %d" % table.size())
	if table.size() == 1:
		_assert(int(table[0]["score"]) == expected, "the persisted score should be %d, got %s" % [expected, table[0]["score"]])
		_assert(int(table[0]["day"]) == int(world.state_get()["day"]), "the persisted day should match the run")
		_assert(not bool(table[0]["dead"]), "a clean finish should not be recorded as dead")
		_assert(String(table[0]["date"]) == Time.get_date_string_from_system(true), "the date should be today's UTC date")

	# index.html:1592-1606 -- the Scores menu renders the table back.
	_main._show_scores()
	await _idle()
	_assert(_main.dialogs().current() is ScoresDialog, "the Scores menu should open a scores dialog")
	_assert(_copy_text(_main.dialogs().current()).contains("Player"), "the scores dialog should list the saved name")
	_main.dialogs().cancel()
	await _idle()

	# The core owns the ordering and the top-10 cut; the store only carries the
	# date alongside. Twelve inserts, ascending, so the low ones fall off the
	# bottom.
	for i in range(12):
		store.insert(world, {
			"name": "Run%d" % i,
			"score": 1000 + i * 100,
			"day": i + 1,
			"dead": i % 2 == 0,
		}, "2026-01-%02d" % (i + 1))

	var full := store.load_all()
	_assert(full.size() == SimWorld.MAX_HIGHSCORES, "the table should hold exactly %d rows, got %d" % [SimWorld.MAX_HIGHSCORES, full.size()])
	if full.size() == SimWorld.MAX_HIGHSCORES:
		_assert(int(full[0]["score"]) == 2100, "the best score should sort first, got %s" % full[0]["score"])
		_assert(int(full[full.size() - 1]["score"]) == 1200, "the worst should be cut to 10, got %s" % full[full.size() - 1]["score"])
		_assert(
			String(full[0]["date"]) == "2026-01-12",
			"the surviving row should keep its own date, got '%s'" % full[0]["date"]
		)
		_assert(
			String(full[full.size() - 1]["date"]) == "2026-01-03",
			"the date should survive the core dropping it, got '%s'" % full[full.size() - 1]["date"]
		)

	# A file that is not the expected shape yields an empty table rather than
	# throwing (index.html:1559-1563).
	var corrupt := FileAccess.open(HighscoreStore.SCORES_PATH, FileAccess.WRITE)
	corrupt.store_string("{ not json")
	corrupt = null
	_assert(store.load_all().is_empty(), "an unparseable high-score file should read as empty")
	store.clear_all()


# index.html:1608-1627. The new-game form's clamping, and that Start really
# re-inits the world.
func _test_new_game_dialog() -> void:
	_fresh(SEED)
	_main._show_new_game_dialog()
	await _idle()
	var dialog := _main.dialogs().current() as NewGameDialog
	_assert(dialog != null, "the new game dialog should open")
	if dialog == null:
		return
	_assert(dialog.num_days() == 31, "the days field should default to the ruleset's 31, got %d" % dialog.num_days())
	_assert(dialog.start_cash() == 2000, "the cash field should default to the ruleset's 2000, got %d" % dialog.start_cash())
	_assert(dialog.requested_seed() == -1, "a new game with no seed asked for should report -1")

	# index.html:1622-1623 -- a blank field falls back to the prototype's
	# default (31 / 2000), not to the field's minimum. This is the typed path
	# the set_values() below bypasses, so it needs its own check.
	_spinbox_of(dialog).get_line_edit().text = ""
	_assert(dialog.num_days() == 31, "a blank days field should read 31, got %d" % dialog.num_days())

	dialog.set_values(7, 5000, 999)
	_main.dialogs().confirm()
	await _idle()

	var world := _main.simulation()
	_assert(int(world.state_get()["num_days"]) == 7, "starting a new game should apply the day count")
	_assert(int(world.state_get()["cash"]) == 5000, "starting a new game should apply the starting cash")
	_assert(int(world.state_get()["day"]) == 1, "a new game should start on day 1")
	_assert(_main.hud().title_text() == "Day 1 of 7", "the day readout should show the new game's length, got '%s'" % _main.hud().title_text())


# index.html:253-270, :45-63. The reference's chrome is a 2px two-tone border
# (light top/left, dark bottom/right for outset, the reverse for inset), a
# white form field with right-aligned text, and a light menu layer on top of
# the Win98 window. The theme must carry all of it; the old shadow-trick
# bevel rendered flat, the unthemed LineEdit fell back to Godot's dark
# default, and the dialog's button row sat flush on the frame. An earlier
# StyleBoxTexture 9-slice attempt rendered the stretched face as a gradient
# (linear-filtered border texels bleeding across the center) -- BevelStyleBox
# draws flat rects instead, so there is no texture to filter.
func _test_win98_chrome() -> void:
	var theme := Win98Theme.shared()

	# --- button bevel (index.html:253-266) -----------------------------------
	var normal := theme.get_stylebox("normal", "Button")
	_assert(normal is BevelStyleBox, "the Button normal stylebox should be a BevelStyleBox, got %s" % normal.get_class())
	if normal is BevelStyleBox:
		var bevel := normal as BevelStyleBox
		_assert(bevel.light == Palette.WIN_FACE_LIGHT, "the outset bevel's light edge should be the light tone, got %s" % bevel.light)
		_assert(bevel.dark == Palette.WIN_FACE_DARKER, "the outset bevel's dark edge should be the darker tone, got %s" % bevel.dark)
		_assert(bevel.face == Palette.WIN_FACE, "the bevel face should be the flat window face, got %s" % bevel.face)
		_assert(not bevel.ring, "a plain button bevel should carry no outer ring")

	var pressed := theme.get_stylebox("pressed", "Button")
	_assert(pressed is BevelStyleBox, "the Button pressed stylebox should be a BevelStyleBox, got %s" % pressed.get_class())
	if pressed is BevelStyleBox:
		var pressed_bevel := pressed as BevelStyleBox
		_assert(pressed_bevel.light == Palette.WIN_FACE_DARKER, "the pressed bevel's light edge should invert to dark, got %s" % pressed_bevel.light)
		_assert(pressed_bevel.dark == Palette.WIN_FACE_LIGHT, "the pressed bevel's dark edge should invert to light, got %s" % pressed_bevel.dark)

	# --- .win frame (index.html:45-50, :606) -----------------------------------
	# The dialog is the reference's .win: the bevel plus a 1px black outer
	# ring. Plain .outset panels (the subway grid) are not.
	var dialog_frame := theme.get_stylebox("panel", "DialogFrame")
	_assert(dialog_frame is BevelStyleBox and (dialog_frame as BevelStyleBox).ring, "the DialogFrame panel should carry the .win outer ring")
	var plain := theme.get_stylebox("panel", "Outset")
	_assert(plain is BevelStyleBox and not (plain as BevelStyleBox).ring, "plain .outset should carry no black ring")

	# --- main window face: flush, top hairline only -----------------------------
	# Unlike the dialog, the window fills the whole OS window -- there is no
	# dark backdrop for a ring to separate it from -- so it carries no bevel
	# and no ring on three sides, only a 1px black top hairline under the OS
	# titlebar, and zero margin elsewhere so content reaches the real edges.
	var win := theme.get_stylebox("panel", "WindowFace")
	_assert(win is StyleBoxFlat, "the WindowFace panel should be a flat box, got %s" % win.get_class())
	if win is StyleBoxFlat:
		var win_flat := win as StyleBoxFlat
		_assert(win_flat.border_width_top == 1, "the window face should carry a 1px top hairline, got %d" % win_flat.border_width_top)
		_assert(win_flat.border_width_left == 0 and win_flat.border_width_right == 0 and win_flat.border_width_bottom == 0, "the window face should carry no border on its other three sides")
		_assert(win_flat.content_margin_left == 0 and win_flat.content_margin_right == 0 and win_flat.content_margin_bottom == 0, "the window face should leave zero margin on three sides so content reaches the real window edges")

	# --- zero gradients ---------------------------------------------------------
	# The one deliberate exception is the system-styled PopupMenu's soft
	# dropshadow (index.html doesn't have one, but the answer to "should the
	# menu layer match Win98" was no -- it stays a light system panel).
	for type_name in theme.get_stylebox_type_list():
		for item_name in theme.get_stylebox_list(type_name):
			var box := theme.get_stylebox(item_name, type_name)
			_assert(not (box is StyleBoxTexture), "%s/%s should not be a stretched StyleBoxTexture (that's the gradient-wash bug), got %s" % [type_name, item_name, box.get_class()])
			if box is StyleBoxFlat and type_name != "PopupMenu":
				_assert((box as StyleBoxFlat).shadow_size == 0, "%s/%s should carry no soft shadow outside the system menu layer" % [type_name, item_name])

	# --- form fields (index.html:420-426, :465-470) ----------------------------
	var field := theme.get_stylebox("normal", "LineEdit")
	_assert(field is StyleBoxFlat, "the LineEdit normal stylebox should be a flat white field, got %s" % field.get_class())
	if field is StyleBoxFlat:
		_assert(_brightness(field.bg_color) > 0.95, "the form field should be white, got %s" % field.bg_color)
	_assert(theme.get_color("font_color", "LineEdit") == Color.BLACK, "the form field text should be black, got %s" % theme.get_color("font_color", "LineEdit"))
	_assert(theme.get_constant("alignment", "LineEdit") == HORIZONTAL_ALIGNMENT_RIGHT, "the form fields should be right-aligned like the prototype's inputs")

	# --- dialog titlebar: flat navy, zero gradients ------------------------------
	var titlebox := theme.get_stylebox("normal", "TitlebarDialog")
	_assert(titlebox is StyleBoxFlat, "the dialog titlebar should be a flat navy box, got %s" % titlebox.get_class())
	if titlebox is StyleBoxFlat:
		_assert(titlebox.bg_color == Palette.TITLEBAR, "the titlebar should be flat navy, got %s" % titlebox.bg_color)

	# --- menu layer: system-styled, light (not Win98) ---------------------------
	_assert(theme.get_color("font_color", "PopupMenu") == Color.BLACK, "the dropdown menu text should be black on the light panel, got %s" % theme.get_color("font_color", "PopupMenu"))
	var menu_panel := theme.get_stylebox("panel", "PopupMenu")
	var menu_panel_bg := Color.BLACK
	if menu_panel is StyleBoxFlat:
		menu_panel_bg = menu_panel.bg_color
	_assert(menu_panel is StyleBoxFlat and _brightness(menu_panel_bg) > 0.8, "the dropdown panel should be light, got %s" % menu_panel_bg)
	var strip := theme.get_stylebox("panel", "MenubarStrip")
	var strip_bg := Color.BLACK
	if strip is StyleBoxFlat:
		strip_bg = strip.bg_color
	_assert(strip is StyleBoxFlat and _brightness(strip_bg) > 0.85, "the menubar strip should be a light neutral, not the Win98 face, got %s" % strip_bg)

	# --- dialog button row (index.html:404-411) ---------------------------------
	var dialog := QuantityDialog.new().present(Copy.DLG_BUY, "test", 5)
	var buttons := _find_named(dialog, "Buttons")
	_assert(buttons != null, "the quantity dialog should carry its button row")
	if buttons != null:
		_assert(buttons.get_parent() is MarginContainer, "the dialog button row should sit in a margin, not flush on the frame")
		if buttons.get_parent() is MarginContainer:
			_assert((buttons.get_parent() as MarginContainer).get_theme_constant("margin_bottom") >= 8, "the button row needs bottom clearance under the frame, got %d" % (buttons.get_parent() as MarginContainer).get_theme_constant("margin_bottom"))
	dialog.free()


# The window is one fixed size on both axes: the Win98 chrome is fixed-width so
# widening would only stretch it, and nothing needs extra height (see
# _test_tables_fit_twelve_drugs). Resizing is also visibly broken on macOS --
# Godot renders into an unflipped view's CAMetalLayer, so a height change shows
# one frame of displaced content -- which is why this is pinned rather than
# merely bounded. See TASK-005.
func _test_window_pinned() -> void:
	var window := get_window()
	_assert(window.min_size == window.max_size, "min and max size should match to pin the window, got min=%v max=%v" % [window.min_size, window.max_size])
	_assert(window.min_size.x > 0 and window.min_size.y > 0, "the window should be pinned to a real size, got %v" % window.min_size)
	_assert(
		ProjectSettings.get_setting("display/window/size/resizable") == false,
		"window/size/resizable should be false so the OS draws no drag edge"
	)
	_assert(
		ProjectSettings.get_setting("display/window/size/maximize_disabled") == true,
		"window/size/maximize_disabled should be true so the maximize button cannot resize the window"
	)
	_assert(
		ProjectSettings.get_setting("display/window/stretch/aspect") == "keep_width",
		"stretch/aspect should be keep_width so the fixed-width chrome never stretches"
	)


# The reason the window needs no resizing: every borough with maxDrugs: 12 can
# trade all DW_NUM_DRUGS at once, and the coat holds one row per drug, so twelve
# rows is the largest either table ever renders. Asserting it fits without
# scrolling is what keeps the pinned height honest if a row's height changes.
func _test_tables_fit_twelve_drugs() -> void:
	var seed_with_full_market := 0
	for candidate in range(1, 400):
		_main.start_new_game(candidate)
		await get_tree().process_frame
		if _main.hud().market_table().row_count() == SimWorld.NUM_DRUGS:
			seed_with_full_market = candidate
			break
	_assert(seed_with_full_market > 0, "no seed under 400 produced a market trading all %d drugs" % SimWorld.NUM_DRUGS)
	if seed_with_full_market == 0:
		return
	await get_tree().process_frame
	var tree: Tree = _main.hud().market_table().tree()
	var last: TreeItem = null
	for item in tree.get_root().get_children():
		last = item
	_assert(last != null, "a market of %d drugs should render rows" % SimWorld.NUM_DRUGS)
	if last == null:
		return
	var area := tree.get_item_area_rect(last)
	_assert(
		area.position.y + area.size.y <= tree.size.y,
		"twelve market rows should fit the table without scrolling: last row ends at %d, table is %d tall" % [area.position.y + area.size.y, tree.size.y]
	)
	_assert(tree.get_scroll().y == 0.0, "a full twelve-drug market should not scroll, got scroll y=%d" % tree.get_scroll().y)


# --- harness ----------------------------------------------------------------



## A real press-and-release over the rendered row, pushed through the viewport
## so the click travels the same path a player's does -- Tree.gui_input does the
## selecting, which is the only way to arm the mouse-selection guard. Press and
## release are a frame apart, and a spare frame follows, so a rebuild that lands
## between them has settled before the next assertion.
##
## The point comes from get_global_transform, so it is already in viewport
## coordinates and push_input takes in_local_coords: a headless window is a
## different size from the 704x620 viewport and stretch/aspect=keep rescales
## between the two, which puts a window-coordinate click nowhere near the row.
func _click_row(tree: Tree, drug_index: int) -> void:
	var item := _row_item(tree, drug_index)
	if item == null:
		_fail("click", "no rendered row for drug %d" % drug_index)
		return
	var point: Vector2 = tree.get_global_transform() * tree.get_item_area_rect(item, 0).get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	press.global_position = point
	get_viewport().push_input(press, true)
	await _idle()
	var release := press.duplicate()
	release.pressed = false
	get_viewport().push_input(release, true)
	await _idle()
	await _idle()


## The rendered row for `drug_index`, found by the metadata MarketTable and
## CoatTable both stamp on their items. Walking the visible rows rather than
## reaching into `_items` keeps this on the same side of the fence as a player:
## what is on screen, not what the table believes it built.
static func _row_item(tree: Tree, drug_index: int) -> TreeItem:
	var root := tree.get_root()
	if root == null:
		return null
	var item := root.get_first_child()
	while item != null:
		if item.has_meta(&"drug_index") and int(item.get_meta(&"drug_index")) == drug_index:
			return item
		item = item.get_next()
	return null


## Every Label under `node`, flattened, so an assertion can read what a dialog
## is actually showing rather than what it was asked to show.
static func _copy_text(node: Object) -> String:
	if node == null:
		return ""
	var parts: Array[String] = []
	var stack: Array = [node]
	while not stack.is_empty():
		var current = stack.pop_back()
		if current is Label:
			parts.append(String(current.text))
		for child in current.get_children():
			stack.append(child)
	return " ".join(parts)


## A fresh game on a fixed seed, so every case is reproducible. Also clears any
## save left by an earlier case, or the boot would resume it instead.
func _fresh(seed_value: int) -> SimWorld:
	SaveStore.new().clear()
	_main.start_new_game(seed_value)
	return _main.simulation()


## One frame, so Control layout and any deferred dialog teardown settle before
## the next assertion.
func _idle() -> void:
	await get_tree().process_frame


func _drain() -> void:
	var guard := 0
	while _main.dialogs().is_open() and guard < 20:
		guard += 1
		_main.dialogs().confirm()
		await _idle()


## The drug index with the lowest current price, -1 if nothing is traded.
static func _cheapest_traded(world: SimWorld) -> int:
	var best := -1
	var best_price := 0
	for slot in world.prices_copy():
		var price := int(slot["price"])
		if best == -1 or price < best_price:
			best = int(slot["drug_index"])
			best_price = price
	return best


static func _price_of(world: SimWorld, drug_index: int) -> int:
	for slot in world.prices_copy():
		if int(slot["drug_index"]) == drug_index:
			return int(slot["price"])
	return 0


## Held quantity of one drug, 0 if not held.
static func _held(world: SimWorld, drug_index: int) -> int:
	for slot in world.inventory_copy():
		if int(slot["drug_index"]) == drug_index:
			return int(slot["qty"])
	return 0


## A perceptual-enough brightness in 0..1 for the near-gray chrome colors; the
## theme's point is light-against-dark, and the palette is achromatic.
static func _brightness(color: Color) -> float:
	return (color.r + color.g + color.b) / 3.0


## A descendant by node name, for assertions that read the dialog's own
## structure rather than a test-only accessor.
static func _find_named(node: Node, what: String) -> Node:
	if node.name == what:
		return node
	for child in node.get_children():
		var found := _find_named(child, what)
		if found != null:
			return found
	return null


## The SpinBox a dialog shows, found by walking its tree. Reaching for the
## widget rather than a test-only method is the point: the typed-text cases
## must drive the real LineEdit a player types into.
static func _spinbox_of(node: Node) -> SpinBox:
	if node is SpinBox:
		return node
	for child in node.get_children():
		var found := _spinbox_of(child)
		if found != null:
			return found
	return null


static func _quantity_line_edit(dialog: Node) -> LineEdit:
	var spin := _spinbox_of(dialog)
	return spin.get_line_edit() if spin != null else null


func _assert(condition: bool, message: String) -> void:
	var current := _per_case.keys()
	if not current.is_empty():
		_per_case[current[current.size() - 1]] = int(_per_case[current[current.size() - 1]]) + 1
	if condition:
		_passed += 1
		return
	_failures.append(message)
	print("  ui-flow FAIL  %s" % message)


func _fail(what: String, why: String) -> void:
	_failures.append("%s — %s" % [what, why])


## Records that a case started, and remembers how many assertions it was
## running when. The count is corrected as assertions land, so an early return
## inside a case still shows up as "ran but asserted too little".
func _case(name: String) -> void:
	_per_case[name] = 0


# Fires only when a synchronous _ready error skipped _finish and the scene would
# otherwise never quit; a healthy run reconciles on the first frame.
func _process(_delta: float) -> void:
	if not _reconciled:
		_frames += 1
		if _frames >= WATCHDOG_FRAMES:
			_finish()


func _finish() -> void:
	if _reconciled:
		return
	_reconciled = true
	for name: String in CASES:
		if not _per_case.has(name):
			_failures.append("suite ran — case '%s' never executed" % name)
		elif int(_per_case[name]) < CASE_FLOORS[name]:
			_failures.append(
				"case '%s' died mid-function (ran %d assertions, expected %d)"
				% [name, int(_per_case[name]), CASE_FLOORS[name]]
			)
	if _passed < MIN_ASSERTIONS:
		_failures.append("suite ran — only %d assertions executed, expected at least %d" % [_passed, MIN_ASSERTIONS])

	for failure in _failures:
		push_error("UI FLOW FAIL  %s" % failure)
	if _failures.is_empty():
		print("ui flow test OK: %d assertions" % _passed)
		get_tree().quit(0)
	else:
		print("ui flow test FAILED: %d failures" % _failures.size())
		get_tree().quit(1)
