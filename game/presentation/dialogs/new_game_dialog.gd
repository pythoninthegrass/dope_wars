class_name NewGameDialog
extends DopeDialog

## The new-game form: game length and starting cash.
##
## The length is one of Beermat 2.1's four (15, 30, 60, 90 days; docs/parity-deltas.md
## records that the registration gate on all but 30 is not ported), picked from a
## selector rather than typed. Starting cash keeps the prototype's floor-and-default
## clamping on Start rather than on the input (index.html:1608-1627).
##
## The seed is not a field. The prototype rolls a fresh one
## (`Math.random() * 2^31`, index.html:1625); `requested_seed()` exists so a
## reproducible run can pass one in, which is how the ui_flow test gets a
## deterministic boot.

## `default_days` / `default_cash` are the ruleset defaults, passed in from
## whoever owns the world rather than read off a throwaway instance here.
const GAME_LENGTHS: Array[int] = [15, 30, 60, 90]
const CASH_MIN := 500
const CASH_MAX := 100000

var _days: OptionButton
var _cash: SpinBox
var _default_cash := 2000
var _seed := -1


func present(default_days: int, default_cash: int) -> NewGameDialog:
	setup(Copy.DLG_NEW_GAME)
	_default_cash = default_cash

	_field(tr(Copy.LBL_NUM_DAYS), _make_days(default_days))
	_field(tr(Copy.LBL_START_CASH), _make_cash(default_cash))

	add_button("ngStart", Copy.BTN_START_GAME)
	add_button("ngCancel", Copy.BTN_CANCEL, true)
	return self


func num_days() -> int:
	return GAME_LENGTHS[_days.selected]


func length_options() -> Array[int]:
	return GAME_LENGTHS


func start_cash() -> int:
	var typed := _cash.get_line_edit().text
	if typed.is_empty():
		return _default_cash
	if not typed.is_valid_int():
		return _default_cash
	return maxi(CASH_MIN, int(typed))


## -1 means "no seed given"; the caller rolls one.
func requested_seed() -> int:
	return _seed


## Fills the form, for the same reason QuantityDialog has set_value: a SpinBox
## cannot meaningfully be typed into from a script. The values are mirrored into
## the fields so the text and the value cannot disagree.
func set_values(days: int, cash: int, seed_value: int = -1) -> NewGameDialog:
	_days.select(GAME_LENGTHS.find(days))
	_cash.value = cash
	_cash.get_line_edit().text = str(cash)
	_seed = seed_value
	return self


func _field(label_text: String, editor: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	editor.custom_minimum_size = Vector2(128, 0)
	row.add_child(editor)
	body().add_child(row)


func _make_days(default_days: int) -> OptionButton:
	_days = OptionButton.new()
	for length in GAME_LENGTHS:
		_days.add_item(str(length))
	_days.select(maxi(GAME_LENGTHS.find(default_days), 0))
	return _days


func _make_cash(default_cash: int) -> SpinBox:
	_cash = SpinBox.new()
	_cash.min_value = CASH_MIN
	_cash.max_value = CASH_MAX
	_cash.step = 100
	_cash.value = default_cash
	_cash.select_all_on_focus = true
	bind_spinner(_cash)
	return _cash
