class_name QuantityDialog
extends DopeDialog

## The prototype's showQuantityDialog (index.html:1251-1280): a prompt, a
## bounded number spinner, and OK/Cancel.
##
## The confirm value is clamped to 0..max on the way out, not on the way in, so
## a player who types nonsense sees what they typed and the world still never
## sees an out-of-range amount. `value()` is only meaningful on the OK key --
## the action signal carries "qtyOk" and the caller reads it there, matching
## the prototype's `opts.onConfirm(qty)` ordering (close, then act).

var _spinner: SpinBox
var _max := 0


## `unit_label` is preformatted (see Copy.units_at) because the prototype
## renders it as static text next to the input, not as part of the prompt.
func present(title_key: String, prompt: String, max_value: int, unit_label: String = "") -> QuantityDialog:
	setup(title_key)

	var text := Label.new()
	text.text = prompt
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	body().add_child(row)

	_max = maxi(0, max_value)
	_spinner = SpinBox.new()
	_spinner.min_value = 0
	_spinner.max_value = _max
	_spinner.step = 1
	_spinner.value = _max
	_spinner.custom_minimum_size = Vector2(128, 0)
	_spinner.select_all_on_focus = true
	row.add_child(_spinner)

	if not unit_label.is_empty():
		var unit := Label.new()
		unit.text = unit_label
		row.add_child(unit)

	add_button("qtyOk", Copy.BTN_OK)
	add_button("qtyCancel", Copy.BTN_CANCEL, true)
	return self


## Clamped to the same 0..max the spinner enforces, in case a test or a
## keyboard paste set the value directly.
func value() -> int:
	if _spinner == null:
		return 0
	return clampi(int(_spinner.value), 0, _max)


## Sets the amount, clamped the same way. A test needs this because there is
## no meaningful way to "type" into a SpinBox from a script, and the clamp is
## the behavior under test either way.
func set_value(amount: int) -> void:
	if _spinner != null:
		_spinner.value = clampi(amount, 0, _max)


func max_value() -> int:
	return _max
