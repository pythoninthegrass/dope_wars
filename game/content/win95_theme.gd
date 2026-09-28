class_name Win95Theme
extends RefCounted

## The Win95 chrome from `index.html:7-505`, as a Godot Theme assembled in
## code. Built rather than authored as a .tres so the palette has exactly one
## home (content/palette.gd) and so the bevel is a function rather than twelve
## hand-copied StyleBox resources.
##
## The whole look is one trick: a 2px border in two colors, light edge
## top/left and dark edge bottom/right for an outset, the reverse for an inset.
## CSS spells that `border-color: light dark dark light`; StyleBoxFlat has a
## single `border_color` for all four sides, so the second tone comes from its
## shadow -- an offset drop shadow in the light color, pushed up-left for an
## outset and down-right for an inset. Everything else in the prototype (LEDs,
## health bar, tables, dialog frames) is those two plus a background color.
##
## Registered variations are consumed by setting `theme_type_variation` on a
## Control, which is why nothing here needs a per-node stylebox override.

static var _shared: Theme = null


static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15

	# Panel is a built-in theme type, so it cannot itself be registered as a
	# variation of itself; its stylebox is set in place instead. Every other
	# frame in the game is one of the variations below.
	theme.set_stylebox("panel", "Panel", bevel(Palette.WIN_FACE, true))
	_outset(theme, "Outset", Palette.WIN_FACE)
	_outset(theme, "DialogIcon", Palette.WIN_FACE_LIGHT2)
	_inset(theme, "Inset", Palette.WIN_FACE)
	_inset(theme, "HealthTrack", Palette.LED_RED)

	_button(theme)

	# Each of the prototype's four LEDs is the same inset frame around a
	# near-black face with a glow color on top (index.html:189-191).
	_led(theme, "LedCash", Palette.LED_GREEN_BG, Palette.LED_GREEN)
	_led(theme, "LedBank", Palette.LED_GREEN_BG, Palette.LED_GREEN)
	_led(theme, "LedDebt", Palette.LED_RED_BG, Palette.LED_RED)
	_led(theme, "LedGuns", Palette.LED_YELLOW_BG, Palette.LED_YELLOW)

	# Table rows carry their state as a background and a font color rather
	# than as a bevel, because the prototype's <tr> has no border.
	_row(theme, "RowIdle", Color.TRANSPARENT, Color.BLACK)
	_row(theme, "RowSelected", Palette.ROW_SELECTED, Palette.ROW_SELECTED_TEXT)
	_row(theme, "RowUnavailable", Palette.ROW_UNAVAILABLE, Palette.ROW_UNAVAILABLE_TEXT)
	# The titlebar is the one gradient in the prototype (index.html:67).
	_titlebar(theme, "Titlebar", Palette.TITLEBAR_TEXT)
	_titlebar(theme, "TitlebarDialog", Palette.TITLEBAR_TEXT)

	# Table chrome. A caption over a table (index.html:293) is a label on the
	# window face; a cell inside one is a label on white.
	_label(theme, "TableTitle", Palette.WIN_FACE, Color.BLACK)
	_label(theme, "TableCell", Color.WHITE, Color.BLACK)

	# Tree chrome. The default theme draws the column-title row as a dark
	# strip; index.html:310-316 makes it the window face.
	theme.set_stylebox("panel", "Tree", flat(Color.WHITE))
	theme.set_stylebox("focus", "Tree", flat(Color.WHITE))
	theme.set_stylebox("cursor", "Tree", flat(Palette.WIN_FACE_DARK))
	theme.set_stylebox("title_button", "Tree", flat(Palette.WIN_FACE))
	theme.set_stylebox("title_button_pressed", "Tree", flat(Palette.WIN_FACE))
	theme.set_stylebox("hovered_selected", "Tree", flat(Palette.ROW_SELECTED))
	theme.set_color("title_button_color", "Tree", Color.BLACK)
	theme.set_color("font_color", "Tree", Color.BLACK)

	# HealthBar is a ProgressBar: a red inset track with a flat blue fill and
	# a yellow label on top (index.html:200-217).
	theme.set_type_variation("HealthBar", "ProgressBar")
	theme.set_stylebox("background", "HealthBar", bevel(Palette.LED_RED, false))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.HEALTH_FILL
	theme.set_stylebox("fill", "HealthBar", fill)
	theme.set_color("font_color", "HealthBar", Palette.LED_YELLOW)

	theme.set_color("font_color", "Label", Color.BLACK)
	return theme


## The 2px two-tone frame every panel in the game is made of.
static func bevel(bg: Color, outset: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.border_width_left = 2
	box.border_color = Palette.WIN_FACE_DARKER
	box.shadow_color = Palette.WIN_FACE_LIGHT
	box.shadow_size = 2
	box.shadow_offset = Vector2(-1, -1) if outset else Vector2(1, 1)
	return box


static func _outset(theme: Theme, type_name: String, bg: Color) -> void:
	theme.set_type_variation(type_name, "Panel")
	theme.set_stylebox("panel", type_name, bevel(bg, true))


static func _inset(theme: Theme, type_name: String, bg: Color) -> void:
	theme.set_type_variation(type_name, "Panel")
	theme.set_stylebox("panel", type_name, bevel(bg, false))


## A label variation whose whole job is a background and a foreground color.
static func _label(theme: Theme, type_name: String, bg: Color, fg: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	var box := flat(bg)
	# A Label sizes itself from its stylebox, so a margin-less box would clip
	# the text it is there to show.
	box.content_margin_left = 2
	box.content_margin_top = 1
	box.content_margin_right = 2
	box.content_margin_bottom = 1
	theme.set_stylebox("normal", type_name, box)
	theme.set_color("font_color", type_name, fg)


## A label-or-panel variation whose whole job is a foreground color, for the
## glow text in the LEDs and the titlebars.
static func _led(theme: Theme, type_name: String, bg: Color, fg: Color) -> void:
	theme.set_type_variation(type_name, "Panel")
	theme.set_stylebox("panel", type_name, bevel(bg, false))
	theme.set_type_variation(type_name + "Text", "Label")
	theme.set_color("font_color", type_name + "Text", fg)

static func _row(theme: Theme, type_name: String, bg: Color, fg: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_stylebox("normal", type_name, flat(bg))
	theme.set_color("font_color", type_name, fg)


## index.html:253-270: a button is an outset frame over the window face,
## inverting while held, and its hover state is the titlebar fill.
static func _button(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", bevel(Palette.WIN_FACE, true))
	theme.set_stylebox("focus", "Button", bevel(Palette.WIN_FACE, true))
	theme.set_stylebox("pressed", "Button", bevel(Palette.WIN_FACE, false))
	theme.set_stylebox("disabled", "Button", bevel(Palette.WIN_FACE, true))
	theme.set_stylebox("hover", "Button", flat(Palette.TITLEBAR))
	theme.set_color("font_color", "Button", Color.BLACK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", Palette.WIN_FACE_DARK)
	theme.set_color("font_disabled_color", "Button", Palette.WIN_FACE_DARK)
	# Without this the default theme's focus color wins, which is the
	# disabled gray -- so the button a dialog focuses on startup looks dead.
	theme.set_color("font_focus_color", "Button", Color.BLACK)
	theme.set_constant("h_separation", "Button", 0)


## A 2px-tall horizontal gradient, which is all a titlebar needs. Built as a
## 256x2 texture stretched horizontally so the gradient runs left-to-right at
## any window width.
static func _titlebar(theme: Theme, type_name: String, fg: Color) -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Palette.TITLEBAR)
	gradient.set_color(1, Palette.TITLEBAR_GRADIENT_END)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 256
	texture.height = 2
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(1, 0)

	var box := StyleBoxTexture.new()
	box.texture = texture
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	# A Label sizes itself from its stylebox's content margins, so a
	# margin-less StyleBoxTexture would make the titlebar zero-height.
	box.content_margin_left = 6
	box.content_margin_top = 3
	box.content_margin_right = 6
	box.content_margin_bottom = 3
	theme.set_type_variation(type_name, "Label")
	theme.set_stylebox("normal", type_name, box)
	theme.set_color("font_color", type_name, fg)


static func flat(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	return box
