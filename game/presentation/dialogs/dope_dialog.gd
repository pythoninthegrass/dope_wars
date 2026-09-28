class_name DopeDialog
extends PanelContainer

## Base for every modal in the game. Gives the subclass a titlebar, a body, a
## button row, and the two things the input router needs: a primary action to
## run on Enter and a secondary action to run on Escape.
##
## The prototype gets this by string-matching button ids
## (`'[id$="Cancel"], [id$="Decline"], ...'`, index.html:1680-1684), which also
## means its Enter/Escape behavior is a side effect of which ids a particular
## dialog happened to use. Here it is declared instead of inferred: a dialog
## names its cancel button, or falls back to its default button, which is what
## the id-matching happened to do for the alert and scores dialogs.
##
## Every button funnels into one `action` signal, so a click, an Enter key and
## an Escape key all reach the same handler by the same route.

signal action(key: String)

var _body: VBoxContainer
var _buttons: HBoxContainer
var _default_key := ""
var _cancel_key := ""


func setup(title_key: String) -> void:
	theme = Win95Theme.shared()
	theme_type_variation = &"Outset"
	# index.html:369: .dialog { width: min(100% - 2rem, 26rem) }. The cap is
	# what makes the finances dialog wrap Close onto its own row, so it is
	# load-bearing rather than cosmetic.
	custom_minimum_size = Vector2(26.0 * 15.0, 0)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 2)
	add_child(frame)

	var title := Label.new()
	title.name = "Title"
	title.text = tr(title_key)
	title.theme_type_variation = &"TitlebarDialog"
	title.add_theme_color_override("font_color", Palette.TITLEBAR_TEXT)
	title.custom_minimum_size = Vector2(240, 0)
	frame.add_child(title)

	var body_frame := PanelContainer.new()
	body_frame.name = "BodyFrame"
	body_frame.theme_type_variation = &"Outset"
	frame.add_child(body_frame)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	body_frame.add_child(margin)

	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override("separation", 10)
	margin.add_child(_body)

	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 8)
	frame.add_child(_buttons)


## The container a subclass fills with its prompt, spinner, and rows.
func body() -> VBoxContainer:
	return _body


## Adds a button to the dialog's button row and returns it. The first one added
## becomes the default, matching the prototype's reading order -- its
## `[id$="Ok"]` query also picks the first match in document order.
func add_button(key: String, label_key: String, is_cancel: bool = false) -> Button:
	var button := Button.new()
	button.name = key
	button.text = tr(label_key)
	button.custom_minimum_size = Vector2(84, 0)
	_buttons.add_child(button)
	if _default_key.is_empty():
		_default_key = key
	if is_cancel:
		_cancel_key = key
	button.pressed.connect(_on_button_pressed.bind(key))
	return button


## Runs the primary action. Bound to Enter.
func confirm() -> void:
	_fire(_default_key)


## Runs the secondary action, or the primary one when the dialog has none --
## which is what the id-matching did for the alert and high-score dialogs,
## where Escape was wired to OK.
func cancel() -> void:
	_fire(_cancel_key if not _cancel_key.is_empty() else _default_key)


## Puts keyboard focus on the dialog's default button, matching the
## prototype's `document.getElementById('alertOk').focus()`.
func focus_default() -> void:
	for child in _buttons.get_children():
		var button := child as Button
		if button != null and button.name == _default_key:
			button.grab_focus()
			return


func _fire(key: String) -> void:
	if key.is_empty():
		return
	action.emit(StringName(key))


func _on_button_pressed(key: String) -> void:
	action.emit(StringName(key))
