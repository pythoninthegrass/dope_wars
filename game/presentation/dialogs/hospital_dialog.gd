class_name HospitalDialog
extends DopeDialog

## The hospital: buy health points at the current per-point price. The price
## rolls daily with the market (Beermat 2.1 N-10, health_price_multiplier), so
## the dialog shows the point cost and the cost to fill to 100, the spinner
## caps at what cash and the remaining health allow, and Buy pays and restores.
##
## The core rolls the "nasty doctor" after a purchase (N-31) and reports the
## outcome; the dialog surfaces it verbatim.

var _price := 0
var _max := 0
var _spinner: SpinBox


## `max_value` is the smaller of "points cash affords" and "points to 100"; the
## spinner pre-fills with it, matching the prototype's pre-filled maximum.
func present(health: int, price: int, max_value: int) -> HospitalDialog:
	setup(Copy.DLG_HOSPITAL)
	_price = price
	_max = maxi(0, max_value)

	var text := Label.new()
	text.text = Copy.hospital_offer(health, price, _max)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	body().add_child(row)

	var spinner := SpinBox.new()
	spinner.min_value = 0
	spinner.max_value = _max
	spinner.step = 1
	spinner.value = _max
	spinner.custom_minimum_size = Vector2(128, 0)
	spinner.select_all_on_focus = true
	_spinner = spinner
	register_primary_field(spinner.get_line_edit())
	bind_spinner(spinner)
	row.add_child(spinner)

	add_button("hospitalBuy", Copy.BTN_BUY)
	add_button("hospitalCancel", Copy.BTN_CANCEL, true)
	return self


## The per-point price the dialog showed, for the caller to build its own
## follow-up message.
func price() -> int:
	return _price


func max_value() -> int:
	return _max


## Sets the points, clamped the same way, and mirrors it into the field so the
## two stores agree. A test needs this because there is no meaningful way to
## "type" into a SpinBox from a script, and the clamp is the behavior under
## test either way.
func set_value(points: int) -> void:
	if _spinner != null:
		var clamped := clampi(points, 0, _max)
		_spinner.value = clamped
		_spinner.get_line_edit().text = str(clamped)


## The number of points the player chose, clamped to 0..max_value. A purchase
## of 0 (full health, or cash that affords no point) is reported as 0 so the
## caller treats it as a clean no-op, matching the core's ERR_INSUFFICIENT_CASH
## / no-op split.
func value() -> int:
	if _spinner == null:
		return 0
	if _spinner.get_line_edit().text.is_empty():
		return 0 if _spinner_typed else clampi(int(_spinner.value), 0, _max)
	apply_spinner(_spinner)
	return clampi(int(_spinner.value), 0, _max)
