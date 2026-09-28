class_name ChaseDialog
extends DopeDialog

## The cop chase (index.html:1477-1525): the cop's line, a health bar, and
## Run / Stay / Fight. Fight is disabled until the player has a gun, which is
## `can_fight` off the chase rather than a UI guess (index.html:1494).
##
## Re-presents itself after every exchange rather than closing, because Run
## and Stay are not terminal -- only a win or a death is. The health bar
## re-reads from the world each time, so it tracks damage taken mid-chase.

var deputies := 0
var can_fight := false


func present(deputy_count: int, health: int, may_fight: bool) -> ChaseDialog:
	deputies = deputy_count
	can_fight = may_fight
	setup(Copy.DLG_COP_CHASE)
	custom_minimum_size = Vector2(360, 0)

	var media := HBoxContainer.new()
	media.add_theme_constant_override("separation", 10)
	body().add_child(media)

	var icon_frame := PanelContainer.new()
	icon_frame.theme_type_variation = &"DialogIcon"
	icon_frame.custom_minimum_size = Vector2(40, 40)
	media.add_child(icon_frame)
	var icon := Label.new()
	icon.text = AlertDialog.ICON_POLICE
	icon.custom_minimum_size = Vector2(40, 40)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_frame.add_child(icon)

	var text := Label.new()
	text.text = Copy.chase_intro(deputies)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media.add_child(text)

	# index.html:1485-1490 -- the same health row the HUD shows.
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

	add_button("chaseRun", Copy.BTN_RUN)
	add_button("chaseStay", Copy.BTN_STAY)
	var fight := add_button("chaseFight", Copy.BTN_FIGHT)
	fight.disabled = not may_fight
	return self
