class_name Main
extends Control

## Composition root for the whole game. main.tscn holds only this script on a
## single Control; the window, the modal layer and the input router are all
## built here or by Hud.
##
## The wiring is the whole point of this file, and it is where the four layers
## meet exactly once each:
##
##   content/     Copy, Palette, Win95Theme -- strings and chrome
##   simulation/  SimWorld -- the only handle on the GDExtension class
##   platform/    InputRouter, SaveStore, HighscoreStore -- keys and files
##   presentation/ Hud, DialogHost, ArrivalFlow -- widgets and flow
##
## Everything below `sim/` is a port of `<script id="ui">`, index.html:1081-1710.
## Each handler cites the line it replaces.

signal state_changed()

var _world: SimWorld
var _hud: Hud
var _dialogs: DialogHost
var _router: InputRouter
var _saves := SaveStore.new()
var _scores := HighscoreStore.new()
var _arrival := ArrivalFlow.new()

## Guards a second finish() -- the prototype disables the Finish button
## instead (index.html:1635), and dw_finish is const so calling it twice is
## harmless but the dialog would stack.
var _finished := false

## index.html:1114-1118: the prototype reads ?seed= from the URL so a run is
## reproducible. Godot's equivalent is a `--seed=<n>` command-line user arg,
## so `godot --path game -- --seed=12345` replays that seed.
const SEED_ARG := "--seed="


func _ready() -> void:
	theme = Win95Theme.shared()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_hud = Hud.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_hud)

	_dialogs = DialogHost.new()
	_dialogs.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dialogs)

	_router = InputRouter.new()
	_router.intent.connect(_on_intent)
	add_child(_router)

	_connect_hud()
	_arrival.finished.connect(_refresh)

	_world = SimWorld.new()
	_boot()


## Load the save if there is a usable one, otherwise start fresh --
## index.html:1700-1706.
func _boot() -> void:
	if _saves.load_into(_world):
		_hud.seed_last_day_warning(_world)
		_hud.clear_selection()
		_refresh()
		return
	start_new_game(_seed_from_args())


func _seed_from_args() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(SEED_ARG):
			return int(arg.substr(SEED_ARG.length()))
	# A bare --seed=N is also accepted, since that is what a packaged build
	# will hand the player rather than a Godot-style `--` user arg.
	for arg in OS.get_cmdline_args():
		if arg.begins_with(SEED_ARG):
			return int(arg.substr(SEED_ARG.length()))
	return -1


# --- new game / persistence -------------------------------------------------


## index.html:1120-1126. A new game drops the old save first, so a crash
## before the first refresh cannot resume the previous run. No reset() first:
## dw_world_init overwrites the world wholesale, so a second init with a
## different seed and day count is already a fresh game.
func start_new_game(seed_value: int, num_days: int = 0, start_cash: int = -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	_world.init(seed_value, num_days, start_cash)
	_hud.clear_selection()
	_hud.seed_last_day_warning(_world)
	_finished = false
	_refresh()


func _connect_hud() -> void:
	_hud.buy_pressed.connect(_do_buy)
	_hud.sell_pressed.connect(_do_sell)
	_hud.finances_pressed.connect(_do_finances)
	_hud.finish_pressed.connect(_do_finish)
	_hud.travel_requested.connect(_do_travel)
	_hud.new_game_requested.connect(_show_new_game_dialog)
	_hud.scores_requested.connect(_show_scores)
	_hud.help_requested.connect(_show_help)
	_hud.exit_requested.connect(_do_exit)
	_hud.alert_last_day.connect(_show_last_day_alert)
	_hud.selection_changed.connect(_refresh)
	_arrival.state_changed.connect(_refresh)


## The prototype saves at the end of every render (index.html:1163), which is
## every state change; this is that hook.
func _refresh() -> void:
	_hud.refresh(_world)
	_saves.save(_world)
	state_changed.emit()


# --- input ------------------------------------------------------------------


## index.html:1676-1698, flattened. While a modal is up only confirm and cancel
## route, and everything else is dropped; with no modal, the shortcuts go
## straight to their HUD handler.
func _on_intent(name: StringName, payload: Variant) -> void:
	if _dialogs.is_open():
		match name:
			&"confirm":
				_dialogs.confirm()
			&"cancel":
				_dialogs.cancel()
		return

	match name:
		&"buy":
			_do_buy()
		&"sell":
			_do_sell()
		&"finances":
			_do_finances()
		&"new_game":
			_show_new_game_dialog()
		&"travel_0", &"travel_1", &"travel_2", &"travel_3", &"travel_4", &"travel_5":
			_do_travel(int(payload))


# --- trade ------------------------------------------------------------------


## index.html:1282-1308. Two refusal alerts before the spinner, in the
## prototype's order: too poor, then no room.
func _do_buy() -> void:
	var drug_index := _hud.selected_buy_drug
	if drug_index < 0:
		return
	var drug_name := Roster.drug_name(drug_index)
	var price := _price_of(drug_index)
	var cash := int(_world.state_get().get("cash", 0))
	if price <= 0:
		return
	var space := _coat_space()

	var max_affordable := int(floor(float(cash) / float(price)))
	if max_affordable < 1:
		_alert(Copy.DLG_DEALER, tr(Copy.MSG_DEALER_TOO_DEAR).format([drug_name]), AlertDialog.ICON_SHUGS)
		return
	if space < 1:
		_alert(Copy.DLG_DEALER, tr(Copy.MSG_COAT_FULL), AlertDialog.ICON_COAT)
		return

	var limit := mini(max_affordable, space)
	var prompt := tr(Copy.MSG_BUY_PROMPT).format([max_affordable, drug_name, space])
	var dialog := QuantityDialog.new().present(Copy.DLG_BUY, prompt, limit, Copy.units_at(price))
	_dialogs.open(dialog, func(key: String) -> void:
		if key == "qtyOk" and dialog.value() > 0:
			_world.buy(drug_index, dialog.value())
		_refresh()
	)


## index.html:1310-1326. No affordability or space gate here -- selling is
## always possible, the prototype just spinners up to what is held.
func _do_sell() -> void:
	var drug_index := _hud.selected_sell_drug
	if drug_index < 0:
		return
	var held := _quantity_of(drug_index)
	if held <= 0:
		return
	var prompt := tr(Copy.MSG_SELL_PROMPT).format([held, Roster.drug_name(drug_index)])
	var dialog := QuantityDialog.new().present(Copy.DLG_SELL, prompt, held, Copy.units_at(_price_of(drug_index)))
	_dialogs.open(dialog, func(key: String) -> void:
		if key == "qtyOk" and dialog.value() > 0:
			_world.sell(drug_index, dialog.value())
		_refresh()
	)


# --- finances ---------------------------------------------------------------


## index.html:1328-1365. The dialog re-opens itself after each amount, which
## is what the prototype's `render(); doFinances()` does at :1348.
func _do_finances() -> void:
	var state := _world.state_get()
	var cash := int(state.get("cash", 0))
	var bank := int(state.get("bank", 0))
	var debt := int(state.get("debt", 0))
	_dialogs.open(FinancesDialog.new().present(cash, bank, debt), _on_finances_action)


func _on_finances_action(key: String) -> void:
	if not key.begins_with("fin") or key == "finClose":
		return
	var action := _finances_action_for(key)
	if action < 0:
		return
	var state := _world.state_get()
	var dialog := FinancesDialog.new()
	var limit := dialog.amount_for(action, int(state.get("cash", 0)), int(state.get("bank", 0)), int(state.get("debt", 0)))
	var prompt := dialog.prompt_for(action, int(state.get("cash", 0)), int(state.get("bank", 0)), int(state.get("debt", 0)))
	var amount := QuantityDialog.new().present(_finances_title(action), prompt, limit)
	_dialogs.open(amount, func(confirm_key: String) -> void:
		if confirm_key == "qtyOk":
			_world.finances(action, amount.value())
		_refresh()
		_do_finances()
	)


static func _finances_action_for(key: String) -> int:
	match key:
		"finDeposit":
			return SimWorld.FINANCES_DEPOSIT
		"finWithdraw":
			return SimWorld.FINANCES_WITHDRAW
		"finPayLoan":
			return SimWorld.FINANCES_PAY_LOAN
	return -1


static func _finances_title(action: int) -> String:
	match action:
		SimWorld.FINANCES_DEPOSIT:
			return Copy.DLG_DEPOSIT
		SimWorld.FINANCES_WITHDRAW:
			return Copy.DLG_WITHDRAW
		SimWorld.FINANCES_PAY_LOAN:
			return Copy.DLG_PAY_LOAN
	return Copy.DLG_FINANCES


# --- travel -----------------------------------------------------------------


## index.html:1369-1376. A refused travel (already here, dead, or past the
## last day) just re-renders; a successful one clears both selections before
## the arrival sequence runs, because the new location has a different market.
func _do_travel(dest_location_index: int) -> void:
	if _world.travel(dest_location_index) != SimWorld.OK:
		_refresh()
		return
	_hud.clear_selection()
	_refresh()
	_arrival.begin(_world, _dialogs, _handle_death)


# --- endgame ----------------------------------------------------------------


## index.html:1527-1533, :1633-1638.
func _do_finish() -> void:
	if _finished or bool(_world.state_get().get("dead", false)):
		return
	_finished = true
	_show_score(_world.finish())


func _handle_death() -> void:
	_finished = true
	_dialogs.close()
	_show_score(_world.finish())


## index.html:1569-1590. Save writes a row, Skip does not, and both go on to
## `after` -- the death alert for a death, the new-game form for a finish.
func _show_score(result: Dictionary) -> void:
	var score := int(result.get("score", 0))
	var day := int(result.get("day", 1))
	var dead := bool(result.get("dead", false))
	var was_death := dead
	var dialog := HighscoreDialog.new().present(score, day, dead)
	_dialogs.open(dialog, func(key: String) -> void:
		if key == "scoreSave":
			_scores.insert(_world, {
				"name": dialog.entered_name(),
				"score": score,
				"day": day,
				"dead": dead,
			})
		_after_score(was_death)
	)


func _after_score(was_death: bool) -> void:
	if not was_death:
		_show_new_game_dialog()
		return
	_alert(Copy.DLG_YOU_DIED, tr(Copy.MSG_YOU_DIED), AlertDialog.ICON_SKULL, _show_new_game_dialog)


func _show_new_game_dialog() -> void:
	var world := SimWorld.new()
	var dialog := NewGameDialog.new().present(world.rules_default_num_days(), world.rules_default_start_cash())
	_dialogs.open(dialog, func(key: String) -> void:
		if key == "ngStart":
			start_new_game(dialog.requested_seed(), dialog.num_days(), dialog.start_cash())
	)


func _show_scores() -> void:
	_dialogs.open(ScoresDialog.new().present(_scores.load_all()), func(_key: String) -> void: pass)


func _show_help() -> void:
	var num_days := 31
	if _world.is_ready():
		num_days = int(_world.state_get().get("num_days", num_days))
	_alert(Copy.DLG_HOW_TO_PLAY, Copy.how_to_play(num_days), AlertDialog.ICON_QUESTION)


func _show_last_day_alert() -> void:
	_alert(Copy.DLG_LAST_DAY, tr(Copy.MSG_LAST_DAY), AlertDialog.ICON_MONEY)


# --- helpers ----------------------------------------------------------------


## `after` runs on the OK press, after the alert closes. The prototype chains
## the next dialog off `#alertOk`'s click (index.html:1531); passing a Callable
## here is the same thing without the DOM query.
func _alert(title_key: String, message: String, icon: String, after: Callable = Callable()) -> void:
	_dialogs.open(AlertDialog.new().present(title_key, message, icon), func(_key: String) -> void:
		if after.is_valid():
			after.call()
	)


func _do_exit() -> void:
	# index.html:1663 can only say goodbye -- a browser tab cannot be closed
	# from script. The Godot build can, so it does.
	_saves.save(_world)
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _world != null:
		_saves.save(_world)


## The current price of a drug, or -1 when it is not traded here.
func _price_of(drug_index: int) -> int:
	for slot in _world.prices_copy():
		if int(slot["drug_index"]) == drug_index:
			return int(slot["price"])
	return -1


func _quantity_of(drug_index: int) -> int:
	for slot in _world.inventory_copy():
		if int(slot["drug_index"]) == drug_index:
			return int(slot["qty"])
	return 0


func _coat_space() -> int:
	var state := _world.state_get()
	return int(state.get("coat_capacity", 0)) - int(state.get("coat_used", 0))


# --- test surface -----------------------------------------------------------


## The world under test. Tests drive the game through the same public entry
## points the keyboard and the buttons do.
func simulation() -> SimWorld:
	return _world


func hud() -> Hud:
	return _hud


func dialogs() -> DialogHost:
	return _dialogs


func arrival() -> ArrivalFlow:
	return _arrival
