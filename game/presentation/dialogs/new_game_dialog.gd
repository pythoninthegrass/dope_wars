class_name NewGameDialog
extends DopeDialog

## The new-game form (index.html:1608-1627): days and starting cash, with the
## same floor-and-default clamping the prototype does on Start rather than on
## the input.
##
## The seed is not a field. The prototype rolls a fresh one
## (`Math.random() * 2^31`, index.html:1625); `requested_seed()` exists so a
## reproducible run can pass one in, which is how the ui_flow test gets a
## deterministic boot.

## `default_days` / `default_cash` are the ruleset defaults, passed in from
## whoever owns the world rather than read off a throwaway instance here.
## index.html:1612-1613: the input bounds and the values the prototype
## substitutes when the field is blank or unparseable.
const DAYS_MIN := 5
const DAYS_MAX := 99
const CASH_MIN := 500
const CASH_MAX := 100000

var _days: SpinBox
var _cash: SpinBox
var _seed := -1


func present(default_days: int, default_cash: int) -> NewGameDialog:
	setup(Copy.DLG_NEW_GAME)

	_field(tr(Copy.LBL_NUM_DAYS), _make_days(default_days))
	_field(tr(Copy.LBL_START_CASH), _make_cash(default_cash))

	add_button("ngStart", Copy.BTN_START_GAME)
	add_button("ngCancel", Copy.BTN_CANCEL, true)
	return self


## Clamped exactly as index.html:1622-1623 clamps: the minimum wins over the
## field, and a blank or unparseable field falls back to the prototype's
## default rather than to zero.
func num_days() -> int:
	return maxi(DAYS_MIN, int(_days.value))


func start_cash() -> int:
	return maxi(CASH_MIN, int(_cash.value))


## -1 means "no seed given"; the caller rolls one.
func requested_seed() -> int:
	return _seed


## Fills the form, for the same reason QuantityDialog has set_value: a SpinBox
## cannot meaningfully be typed into from a script.
func set_values(days: int, cash: int, seed_value: int = -1) -> NewGameDialog:
	_days.value = days
	_cash.value = cash
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


func _make_days(default_days: int) -> SpinBox:
	_days = SpinBox.new()
	_days.min_value = DAYS_MIN
	_days.max_value = DAYS_MAX
	_days.step = 1
	# The prototype's default is the ruleset's 31, not the field's midpoint.
	_days.value = default_days
	_days.select_all_on_focus = true
	return _days


func _make_cash(default_cash: int) -> SpinBox:
	_cash = SpinBox.new()
	_cash.min_value = CASH_MIN
	_cash.max_value = CASH_MAX
	_cash.step = 100
	_cash.value = default_cash
	_cash.select_all_on_focus = true
	return _cash
