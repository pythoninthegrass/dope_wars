class_name LoanSharkDialog
extends DopeDialog

## A loan shark's visit (docs/beermat-2.1-re.md, "Visits"): the lender, how late
## the loan is, what is owed, the player's health and "Visit N of M". Below
## level 4 the player answers Pay Now or Pay Later; from level 4 the beating has
## already landed, Pay Now and Pay Later are disabled and OK moves on.

const BEATING_LEVEL := 4

var level := 0


## `visit` is the dict dw_shark_visit returned; `health` is read after the beating.
func present(shark: Dictionary, visit: Dictionary, health: int, visit_number: int, visit_total: int) -> LoanSharkDialog:
	level = int(visit["level"])
	var shark_name := String(shark["name"])
	setup(Copy.DLG_LOAN_SHARK)
	custom_minimum_size = Vector2(380, 0)

	var lines: Array[String] = [Copy.visit_status(int(visit["days_left"])), Copy.visit_demand(shark_name, int(visit["owed"]))]
	if level == 3:
		lines.append(Copy.visit_warning(shark_name))
	if level >= BEATING_LEVEL:
		lines.append(Copy.visit_beating(int(visit["message"]), shark_name, bool(shark["female"])))

	var media := HBoxContainer.new()
	media.add_theme_constant_override("separation", 10)
	body().add_child(media)

	var icon_frame := PanelContainer.new()
	icon_frame.theme_type_variation = &"DialogIcon"
	icon_frame.custom_minimum_size = Vector2(40, 40)
	media.add_child(icon_frame)
	var icon := Label.new()
	icon.text = AlertDialog.ICON_WARNING
	icon.custom_minimum_size = Vector2(40, 40)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_frame.add_child(icon)

	var text := Label.new()
	text.name = "VisitText"
	text.text = "\n".join(lines)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media.add_child(text)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = tr(Copy.HEALTH)
	row.add_child(label)
	var bar := HealthBar.new()
	bar.set_health(health)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	body().add_child(row)

	var counter := Label.new()
	counter.name = "VisitCounter"
	counter.text = tr(Copy.MSG_VISIT_OF).format([visit_number, visit_total])
	body().add_child(counter)

	if level < BEATING_LEVEL:
		add_button("loanPayNow", Copy.BTN_PAY_NOW)
		add_button("loanPayLater", Copy.BTN_PAY_LATER, true)
		return self
	add_button("loanPayNow", Copy.BTN_PAY_NOW).disabled = true
	add_button("loanPayLater", Copy.BTN_PAY_LATER).disabled = true
	add_button("loanOk", Copy.BTN_OK, true)
	return self


## Enter must not reach the disabled Pay Now that the base class would run.
func confirm() -> void:
	if level >= BEATING_LEVEL:
		action.emit(&"loanOk")
		return
	super.confirm()
