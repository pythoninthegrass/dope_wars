class_name Hud
extends PanelContainer

## The main game window (index.html:509-603): the menubar, the LED / subway /
## finish top row, the action row, both tables, and the footer. The
## prototype's titlebar is a window decoration this app does not draw -- the
## OS does -- so the day readout sits at the right of the menubar strip.
##
## This is pure rendering plus input forwarding. Every refresh re-reads the
## world, because `docs/layer-boundaries.md` forbids mirroring dw_world state
## into GDScript fields -- so there is no "model" here, only widgets and a
## rebuild-from-world pass. The two selections the prototype keeps in closure
## variables (`selectedBuyDrug`, `selectedSellDrug`, index.html:1088-1089) are
## the one exception the same rule explicitly allows, since they are UI state
## with no counterpart in the world.

## Emitted whenever a button is pressed; Main owns the behavior.
signal buy_pressed()
signal sell_pressed()
signal finances_pressed()
signal finish_pressed()
signal travel_requested(location_index: int)
signal new_game_requested()
signal scores_requested()
signal help_requested()
signal exit_requested()
signal buy_drug_selected(drug_index: int)
signal sell_drug_selected(drug_index: int)

## A click on either table changed the selection, so the action buttons and the
## two tables' highlights have to be recomputed. index.html:1189 and :1210 both
## end their click handler with a full render(); Main listens here and does the
## same, rather than this method re-entering its own refresh.
signal selection_changed()

## index.html:1158-1161. Separate from refresh() so Main can raise it as a
## modal rather than having the HUD reach for the DialogHost.
signal alert_last_day()

var selected_buy_drug := -1
var selected_sell_drug := -1

## The prototype's `state.lastDayWarned` (index.html:1158-1161). Read-only
## through the ABI -- the world carries the flag but exposes no setter -- so
## the "shown" half of it lives here as UI state, seeded from the world on
## load. A save written before the warning was seen comes back with the flag
## still clear and the player is told once more, which is what the JS does too
## since the flag only ever gets set on the client.
var _last_day_warned := false

var _title: Label
var _leds: Dictionary = {}
var _health: HealthBar
var _subway_from: Label
var _subway_panel: Control
var _finish_panel: Control
var _boroughs: Array[Button] = []
var _buy_button: Button
var _sell_button: Button
var _market: MarketTable
var _coat: CoatTable

## Which drugs are tradable at the current location, as of the last refresh.
## index.html:1217-1218 asks the same question twice per render; it is the
## market table's row set, not a second copy of the price list.
var _traded: Dictionary = {}


func _init() -> void:
	theme = Win95Theme.shared()
	theme_type_variation = &"WindowFace"
	_build()


## Rebuilds every widget from the world. The prototype's `render()`
## (index.html:1128-1164), minus the save call, which Main owns.
func refresh(world: SimWorld) -> void:
	var state := world.state_get()
	var day := int(state.get("day", 1))
	var num_days := int(state.get("num_days", 31))
	var dead := bool(state.get("dead", false))

	_title.text = Copy.day_of(day, num_days)
	_leds["cash"].text = Copy.fmt(state.get("cash", 0))
	_leds["bank"].text = Copy.fmt(state.get("bank", 0))
	_leds["debt"].text = Copy.fmt(state.get("debt", 0))
	_leds["guns"].text = Copy.fmt(state.get("guns", 0))
	_health.set_health(int(state.get("health", 0)))

	var location_index := int(state.get("location_index", 0))
	_subway_from.text = Copy.subway_from(Roster.location_name(location_index))

	# index.html:1140-1142: the last day hides the subway and shows Finish.
	var is_last_day := day >= num_days
	_subway_panel.visible = not is_last_day
	_finish_panel.visible = is_last_day and not dead

	var locations := Roster.locations()
	for i in range(_boroughs.size()):
		var button := _boroughs[i]
		# index.html:1149: the borough you are in, and everything once you
		# are dead, is not a destination.
		button.disabled = i == location_index or dead
		button.text = String(locations[i]["name"]) if i < locations.size() else str(i)

	# index.html:1176: no trend arrows on day 1, because there is no previous
	# turn to compare against.
	_market.refresh(world, selected_buy_drug, day > 1)
	_coat.refresh(world, selected_sell_drug)
	_traded = {}
	for drug_index in _market.shown_drug_indices():
		_traded[drug_index] = true
	_refresh_actions(world)

	if is_last_day and not _last_day_warned:
		_last_day_warned = true
		alert_last_day.emit()


## index.html:1216-1220. Pure enablement from the current selection; the
## selection itself only ever changes on a click (select_buy_drug /
## select_sell_drug), never as a side effect of rendering.
func _refresh_actions(world: SimWorld) -> void:
	var dead := bool(world.state_get().get("dead", false))
	_buy_button.disabled = selected_buy_drug < 0 or not _traded.has(selected_buy_drug) or dead
	_sell_button.disabled = selected_sell_drug < 0 or not _coat.is_traded(selected_sell_drug) or dead


# --- selection --------------------------------------------------------------


## index.html:1186-1190 -- a click on the market table sets the buy selection
## and points the sell selection at the same drug if any is held.
func select_buy_drug(drug_index: int) -> void:
	selected_buy_drug = drug_index
	selected_sell_drug = drug_index if _coat.holds(drug_index) else -1
	_market.selected_changed(drug_index)
	_coat.selected_changed(selected_sell_drug)


## index.html:1207-1211 -- a click on the coat table sets both, with no
## null-out when the drug is not traded here; the row goes dark red and the
## Sell button stays disabled instead.
func select_sell_drug(drug_index: int) -> void:
	selected_sell_drug = drug_index
	selected_buy_drug = drug_index
	_market.selected_changed(drug_index)
	_coat.selected_changed(drug_index)


## What index.html:1123-1124 does on a new game.
func clear_selection() -> void:
	selected_buy_drug = -1
	selected_sell_drug = -1
	_market.selected_changed(-1)
	_coat.selected_changed(-1)


func seed_last_day_warning(world: SimWorld) -> void:
	_last_day_warned = bool(world.state_get().get("last_day_warned", false))


func market_table() -> MarketTable:
	return _market


func coat_table() -> CoatTable:
	return _coat


func title_text() -> String:
	return _title.text


func led_text(led: String) -> String:
	return _leds[led].text if _leds.has(led) else ""


# --- test surface -----------------------------------------------------------
#
# The ui_flow_test drives the game through Main, but asserting on "is the Buy
# button live" needs the button rather than a click, and a button's enabled
# state after a click is exactly the thing a test should read. So these expose
# state and press buttons instead of reaching into the tree.


# index.html:1217.
func can_buy() -> bool:
	return not _buy_button.disabled


# index.html:1218-1219.
func can_sell() -> bool:
	return not _sell_button.disabled


# index.html:1141 -- the subway panel is the only way to advance a day, so it
# disappears on the last day.
func borough_panel_visible() -> bool:
	return _subway_panel.visible


func finish_panel_visible() -> bool:
	return _finish_panel.visible


## Presses borough `index` as a click would, and is a no-op for an out-of-range
## index or a disabled button -- the same guard the disabled state implies.
func borough_pressed(index: int) -> void:
	if index < 0 or index >= _boroughs.size() or _boroughs[index].disabled:
		return
	_boroughs[index].pressed.emit()


## Clicks a market row, going through the table's own selection path.
func market_drug_pressed(drug_index: int) -> void:
	_market.select_drug(drug_index)


## Clicks a coat row, going through the table's own selection path.
func coat_drug_pressed(drug_index: int) -> void:
	_coat.select_drug(drug_index)


# --- construction -----------------------------------------------------------


func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	add_child(column)

	column.add_child(_build_menubar())

	var content := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 8)
	# The tables are the only part of the window that grows, so the content
	# area has to be the part that takes the slack.
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	content.add_child(stack)

	stack.add_child(_build_top_row())
	stack.add_child(_build_action_row())

	var tables := HBoxContainer.new()
	tables.add_theme_constant_override("separation", 8)
	tables.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tables.add_child(_build_market_column())
	tables.add_child(_build_coat_column())
	stack.add_child(tables)

	stack.add_child(_build_footer())


## The prototype's titlebar (index.html:66-76, :511) is a window decoration,
## and a native app has one already -- Godot's, which Main keeps in sync with
## the day. So the title text lives in the menubar strip instead, on the right
## of the menus, where a Win95 status field would sit.
func _build_day_readout() -> Control:
	_title = Label.new()
	_title.name = "DayReadout"
	_title.text = Copy.day_of(1, 31)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	return _title


func _build_menubar() -> Control:
	# index.html:100-106: the strip is the window face with a hairline under
	# it, so the entries sit on their own panel rather than on the content
	# background.
	var strip := PanelContainer.new()
	strip.name = "MenubarStrip"
	strip.theme_type_variation = &"MenubarStrip"
	var bar := HBoxContainer.new()
	bar.name = "Menubar"
	# index.html:101: gap: 1rem.
	bar.add_theme_constant_override("separation", 15)
	strip.add_child(bar)
	bar.add_child(_menu_button(Copy.MENU_FILE, [
		[Copy.ITEM_NEW_GAME, "_on_new_game"],
		[Copy.ITEM_EXIT, "_on_exit"],
	]))
	bar.add_child(_menu_button(Copy.MENU_SCORES, [
		[Copy.ITEM_HIGH_SCORES, "_on_scores"],
	]))
	# index.html:534-536: the Sounds menu is present but inert, with one
	# disabled item saying so.
	bar.add_child(_menu_button(Copy.MENU_SOUNDS, [[Copy.MENU_NO_SOUND, ""]], true))
	bar.add_child(_menu_button(Copy.MENU_HELP, [
		[Copy.ITEM_HOW_TO_PLAY, "_on_help"],
	]))
	bar.add_child(_build_day_readout())
	return strip


## `items` is a list of [label_key, handler_method] pairs. An empty handler
## name lists an item that does nothing, which is how the Sounds menu renders
## in the prototype. The frame is the theme's, not Button's: index.html:109-118
## draws these as bare text that highlights on hover.
func _menu_button(label_key: String, items: Array, inert: bool = false) -> Control:
	var root := MenuButton.new()
	root.name = "Menu" + label_key
	root.text = tr(label_key)
	root.disabled = inert

	var popup := root.get_popup()
	var handlers := {}
	var next_id := 0
	for pair: Array in items:
		popup.add_item(tr(String(pair[0])), next_id)
		var handler := String(pair[1])
		if not handler.is_empty():
			handlers[next_id] = handler
		next_id += 1

	popup.id_pressed.connect(func(chosen: int) -> void:
		var handler := String(handlers.get(chosen, ""))
		if not handler.is_empty():
			call(handler)
	)
	return root


func _on_new_game() -> void:
	new_game_requested.emit()


func _on_exit() -> void:
	exit_requested.emit()


func _on_scores() -> void:
	scores_requested.emit()


func _on_help() -> void:
	help_requested.emit()


func _build_top_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "TopRow"
	row.add_theme_constant_override("separation", 8)

	# index.html:159-164: .top-row { align-items: start }, so each panel is
	# as tall as its own content rather than stretched to the tallest sibling.
	row.add_child(_build_status_column())
	row.add_child(_build_subway_panel())

	_finish_panel = PanelContainer.new()
	_finish_panel.name = "FinishPanel"
	_finish_panel.theme_type_variation = &"Outset"
	_finish_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_finish_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var finish := Button.new()
	finish.name = "finishBtn"
	finish.text = tr(Copy.BTN_FINISH)
	finish.add_theme_font_size_override("font_size", 22)
	# index.html:245-251: the Finish button fills its panel and is never
	# shorter than 90px.
	finish.custom_minimum_size = Vector2(0, 90)
	finish.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finish.pressed.connect(func() -> void: finish_pressed.emit())
	_finish_panel.add_child(finish)
	row.add_child(_finish_panel)
	return row


func _build_status_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "StatusColumn"
	column.add_theme_constant_override("separation", 4)
	column.custom_minimum_size = Vector2(220, 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	for led in [["cash", Copy.LED_CASH, &"LedCash"], ["bank", Copy.LED_BANK, &"LedBank"],
			["debt", Copy.LED_DEBT, &"LedDebt"], ["guns", Copy.LED_GUNS, &"LedGuns"]]:
		column.add_child(_build_led(String(led[0]), String(led[1]), led[2]))

	var health_row := HBoxContainer.new()
	health_row.name = "HealthRow"
	health_row.add_theme_constant_override("separation", 8)
	var health_label := Label.new()
	health_label.text = tr(Copy.HEALTH)
	health_row.add_child(health_label)
	_health = HealthBar.new()
	_health.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(_health)
	column.add_child(health_row)
	return column


## `variation` names the inset frame the prototype gives this LED; the two text
## variations are that name with "Label" and "Value" appended, which is how the
## theme registers the dimmed label and the full-brightness value
## (index.html:186).
func _build_led(key: String, label_key: String, variation: StringName) -> Control:
	var frame := PanelContainer.new()
	frame.name = key.capitalize() + "Led"
	frame.theme_type_variation = variation
	# index.html:189-191 plus the 2px inset frame around it: the prototype's
	# LED is 29px tall at 17px of glowing text.
	frame.custom_minimum_size = Vector2(0, 29)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	frame.add_child(row)

	var label := Label.new()
	label.text = tr(label_key)
	label.theme_type_variation = StringName(String(variation) + "Label")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value := Label.new()
	value.theme_type_variation = StringName(String(variation) + "Value")
	value.name = "Value"
	value.text = "0"
	row.add_child(value)
	_leds[key] = value
	return frame


func _build_subway_panel() -> Control:
	_subway_panel = PanelContainer.new()
	_subway_panel.name = "SubwayPanel"
	_subway_panel.theme_type_variation = &"Outset"
	_subway_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	# index.html:160: the top row is a two-column 1fr 1fr grid, so the status
	# LEDs and the subway panel split the window evenly.
	_subway_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	_subway_panel.add_child(stack)

	var label := Label.new()
	label.name = "SubwayFrom"
	label.theme_type_variation = &"TableTitle"
	_subway_from = label
	stack.add_child(label)

	# index.html:1148-1151: one button per borough, built once. The prototype
	# rebuilds the grid every render; there are six of them and the enabled
	# state is the only thing that varies.
	var grid := GridContainer.new()
	grid.name = "BoroughGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	for i in range(Roster.location_count()):
		var index := i
		var button := Button.new()
		button.name = "Borough%d" % i
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: travel_requested.emit(index))
		grid.add_child(button)
		_boroughs.append(button)
	stack.add_child(grid)
	return _subway_panel


func _build_action_row() -> Control:
	var row := HBoxContainer.new()
	row.name = "ActionRow"
	row.add_theme_constant_override("separation", 6)

	_buy_button = Button.new()
	_buy_button.name = "buyBtn"
	_buy_button.text = tr(Copy.BTN_BUY)
	_buy_button.disabled = true
	_buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buy_button.pressed.connect(func() -> void: buy_pressed.emit())
	row.add_child(_buy_button)

	_sell_button = Button.new()
	_sell_button.name = "sellBtn"
	_sell_button.text = tr(Copy.BTN_SELL)
	_sell_button.disabled = true
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_button.pressed.connect(func() -> void: sell_pressed.emit())
	row.add_child(_sell_button)

	var finances := Button.new()
	finances.name = "financesBtn"
	finances.text = tr(Copy.BTN_FINANCES)
	finances.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finances.pressed.connect(func() -> void: finances_pressed.emit())
	row.add_child(finances)
	return row


func _build_market_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "MarketColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_market = MarketTable.new()
	_market.drug_selected.connect(_on_market_drug_selected)
	column.add_child(_market)
	return column


func _on_market_drug_selected(drug_index: int) -> void:
	select_buy_drug(drug_index)
	buy_drug_selected.emit(drug_index)
	selection_changed.emit()


func _build_coat_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "CoatColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_coat = CoatTable.new()
	_coat.drug_selected.connect(_on_coat_drug_selected)
	column.add_child(_coat)
	return column


func _on_coat_drug_selected(drug_index: int) -> void:
	select_sell_drug(drug_index)
	sell_drug_selected.emit(drug_index)
	selection_changed.emit()


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.name = "FooterRow"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 6)

	var new_game := Button.new()
	new_game.name = "footerNewGame"
	new_game.text = tr(Copy.ITEM_NEW_GAME)
	new_game.pressed.connect(func() -> void: new_game_requested.emit())
	row.add_child(new_game)

	var exit := Button.new()
	exit.name = "footerExit"
	exit.text = tr(Copy.ITEM_EXIT)
	exit.pressed.connect(func() -> void: exit_requested.emit())
	row.add_child(exit)
	return row
