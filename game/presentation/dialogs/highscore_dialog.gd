class_name HighscoreDialog
extends DopeDialog

## The end-of-game score entry (index.html:1569-1590): the final score, a name
## field defaulting to "Player", and Save score / Skip. Both buttons close the
## dialog; only Save writes a row.
##
## The name is the one piece of display text in the game that is not a tr()
## key, because it is player input rather than a string the game owns. The
## prototype caps it at 16 characters in the input; dw_highscore_entry's own
## limit is 31 bytes, so the tighter of the two is applied here at the widget
## and the core enforces its own.

const NAME_MAX_LENGTH := 16

var _name_field: LineEdit


## `score` and `day` come from dw_finish_result. `dead` is appended to the
## score line, matching the prototype's `(dead)` suffix.
func present(score: int, day: int, dead: bool) -> HighscoreDialog:
	setup(Copy.DLG_GAME_OVER)

	var summary := Label.new()
	summary.text = Copy.final_score(score, dead)
	body().add_child(summary)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = tr(Copy.LBL_YOUR_NAME)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	_name_field = LineEdit.new()
	_name_field.text = tr(Copy.DEFAULT_NAME)
	_name_field.max_length = NAME_MAX_LENGTH
	_name_field.custom_minimum_size = Vector2(128, 0)
	_name_field.select_all_on_focus = true
	register_primary_field(_name_field)
	row.add_child(_name_field)
	body().add_child(row)

	add_button("scoreSave", Copy.BTN_SAVE_SCORE)
	add_button("scoreSkip", Copy.BTN_SKIP, true)
	return self


## The trimmed name, falling back to the default when the player cleared the
## field -- index.html:1583.
func entered_name() -> String:
	var typed := _name_field.text.strip_edges()
	return typed if not typed.is_empty() else tr(Copy.DEFAULT_NAME)
