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
##
## Resolution rule, which cost a screenshot to pin down: a variation is looked
## up by NAME, under the theme ITEM the consuming class reads. `PanelContainer`
## reads "panel"; `Label` reads "normal". The base type passed to
## `set_type_variation` only drives the editor's suggestion list, never the
## lookup. So a frame consumed by a PanelContainer must store its stylebox
## under "panel" -- registering the titlebar gradient under "normal" (the Label
## item) left a PanelContainer titlebar wearing the default dark panel.

## The prototype's rem ladder against the 15px :root (index.html:101, 193, 228,
## 253, 307): 0.85rem table text, 0.9rem controls (13.5px) and 0.95rem titlebar
## (14.25px) -- both of which round to the one body size -- and the LED clamp
## landing on its 1.15rem upper bound at this window width.
const FONT_TABLE := 13
const FONT_BODY := 14
const FONT_LED := 17
## index.html:483: .price-arrow { font-size: 0.75em } -- a fifth under the
## table text it sits in, in a fixed 1.1em slot with 5% of breathing room
## after it (index.html:500-505 puts the pair in a 7.5rem price column).
const FONT_TREND := 10
## The glyph needs its 0.75em box plus the table's 6px of cell padding on each
## side (index.html:323-329, :500-505) before the price column can start, so
## the slot is sized to fit it rather than to the bare 1.1em.
const TREND_SLOT := 26
const PRICE_COLUMN := 112

static var _shared: Theme = null
static var _fonts := {}


static func shared() -> Theme:
	if _shared == null:
		_shared = build()
	return _shared


## index.html:42 asks for Tahoma, then MS Sans Serif, Geneva, Verdana. A
## SystemFont with that list resolves against whatever the host has and falls
## back to Godot's own face when none of them are installed.
static func ui_font() -> Font:
	if not _fonts.has(&"ui"):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Tahoma", "MS Sans Serif", "Geneva", "Verdana"])
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_fonts[&"ui"] = font
	return _fonts[&"ui"]


## Bold where the prototype says `font-weight: bold`: the titlebar, the LED
## readouts and the table column titles. Asking the system for the bold face
## rather than emboldening the regular one, so the metrics are the real bold
## metrics -- Tahoma Bold and Courier New Bold are core web faces, present
## wherever the regular ones are.
static func bold_font() -> Font:
	if not _fonts.has(&"bold"):
		_fonts[&"bold"] = _system_font(["Tahoma", "MS Sans Serif", "Geneva", "Verdana"], 700)
	return _fonts[&"bold"]


## The LEDs are the one monospace surface in the game (index.html:178-180:
## "Courier New", bold, letter-spaced).
static func led_font() -> Font:
	if not _fonts.has(&"led"):
		_fonts[&"led"] = _system_font(["Courier New", "Courier", "monospace"], 700)
	return _fonts[&"led"]


## The trend glyphs (▲ ▼ —, index.html:481-497) are geometric shapes, and
## neither Tahoma nor Godot's own fallback font carries them -- which is why
## a browser swaps in another family for exactly those three characters. A
## SystemFont cannot do that: it resolves to one family and does not merge
## coverage. So the indicator column asks for the first family in this stack
## that has all of them, and the lookup happens once when the theme is built.
static func trend_font() -> Font:
	if _fonts.has(&"trend"):
		return _fonts[&"trend"]
	for family: String in ["Arial", "Arial Unicode MS", "Menlo", "Courier New", "DejaVu Sans"]:
		var candidate := _system_font([family], 400)
		if candidate.has_char(0x25B2) and candidate.has_char(0x25BC) and candidate.has_char(0x2014):
			_fonts[&"trend"] = candidate
			return candidate
	_fonts[&"trend"] = ui_font()
	return _fonts[&"trend"]


static func _system_font(names: Array, weight: int) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_weight = weight
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	return font


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = ui_font()
	# index.html:23 -- :root { font-size: 15px }, which every rem below is a
	# fraction of.
	theme.default_font_size = 15

	# The window face. A Panel (flat) and a PanelContainer (framed) are
	# different classes reading the same item name, and only the container
	# takes a theme_type_variation.
	theme.set_stylebox("panel", "Panel", bevel(Palette.WIN_FACE, true))
	_outset(theme, "WindowFace", Palette.WIN_FACE)

	_outset(theme, "Outset", Palette.WIN_FACE)
	_outset(theme, "DialogIcon", Palette.WIN_FACE_LIGHT2)
	_inset(theme, "Inset", Palette.WIN_FACE)
	_inset(theme, "HealthTrack", Palette.LED_RED)
	# index.html:100-106: the menubar strip is the window face with a single
	# hairline under it.
	_menubar_strip(theme)

	_button(theme)
	_menu(theme)
	_popup(theme)

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
	# The titlebar is the one gradient in the prototype (index.html:67). The
	# app itself has no titlebar -- the OS draws that -- so this serves the
	# dialogs, whose title is a Label.
	_titlebar(theme, "TitlebarDialog", "Label")

	# Table chrome. A caption over a table (index.html:293) is a label on the
	# window face; a cell inside one is a label on white.
	_label(theme, "TableTitle", Palette.WIN_FACE, Color.BLACK, FONT_TABLE)
	_label(theme, "TableCell", Color.WHITE, Color.BLACK, FONT_TABLE)

	_tree(theme)

	# HealthBar is a ProgressBar: a red inset track with a flat blue fill and
	# a yellow label on top (index.html:200-217).
	theme.set_type_variation("HealthBar", "ProgressBar")
	theme.set_stylebox("background", "HealthBar", bevel(Palette.LED_RED, false))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Palette.HEALTH_FILL
	theme.set_stylebox("fill", "HealthBar", fill)
	theme.set_color("font_color", "HealthBar", Palette.LED_YELLOW)
	theme.set_font_size("font_size", "HealthBar", FONT_TABLE)

	theme.set_color("font_color", "Label", Color.BLACK)
	theme.set_font_size("font_size", "Label", FONT_BODY)
	return theme


## The 2px two-tone frame every panel in the game is made of. `pad` is the CSS
## `padding` the prototype puts inside that frame (x horizontal, y vertical),
## which is what gives a button its 30px height.
static func bevel(bg: Color, outset: bool, pad: Vector2i = Vector2i.ZERO) -> StyleBoxFlat:
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
	box.content_margin_left = pad.x
	box.content_margin_right = pad.x
	box.content_margin_top = pad.y
	box.content_margin_bottom = pad.y
	return box


## index.html:253-261: the CSS button padding, reused by every frame that has
## to measure like one.
const BUTTON_PAD := Vector2i(8, 5)


static func _outset(theme: Theme, type_name: String, bg: Color) -> void:
	theme.set_type_variation(type_name, "PanelContainer")
	theme.set_stylebox("panel", type_name, bevel(bg, true))


static func _inset(theme: Theme, type_name: String, bg: Color) -> void:
	theme.set_type_variation(type_name, "PanelContainer")
	theme.set_stylebox("panel", type_name, bevel(bg, false))


## index.html:100-106 -- the menubar's own face, its 2px/6px padding, and its
## single hairline.
static func _menubar_strip(theme: Theme) -> void:
	var box := flat(Palette.WIN_FACE)
	box.border_width_bottom = 1
	box.border_color = Palette.WIN_FACE_DARKER
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	theme.set_type_variation("MenubarStrip", "PanelContainer")
	theme.set_stylebox("panel", "MenubarStrip", box)


## A label variation whose whole job is a background and a foreground color.
static func _label(theme: Theme, type_name: String, bg: Color, fg: Color, font_size: int) -> void:
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
	theme.set_font_size("font_size", type_name, font_size)


## index.html:180-191: the LED's own padding, so the label and the number sit
## off the inset frame instead of touching it.
const LED_PAD := Vector2i(8, 3)

## The LED text comes in two brightnesses: index.html:186 dims the label
## (`opacity: 0.85`) and leaves the value at full glow, and the value is the
## one the player reads at a glance.
static func _led(theme: Theme, type_name: String, bg: Color, fg: Color) -> void:
	theme.set_type_variation(type_name, "PanelContainer")
	theme.set_stylebox("panel", type_name, bevel(bg, false, LED_PAD))
	_led_text(theme, type_name + "Label", bg.lerp(fg, 0.85))
	_led_text(theme, type_name + "Value", fg)


static func _led_text(theme: Theme, type_name: String, fg: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_color("font_color", type_name, fg)
	theme.set_font("font", type_name, led_font())
	theme.set_font_size("font_size", type_name, FONT_LED)

static func _row(theme: Theme, type_name: String, bg: Color, fg: Color) -> void:
	theme.set_type_variation(type_name, "Label")
	theme.set_stylebox("normal", type_name, flat(bg))
	theme.set_color("font_color", type_name, fg)


## index.html:253-270: a button is an outset frame over the window face which
## inverts while held. There is deliberately no hover color here -- the
## prototype styles `button:hover` not at all, and a titlebar-blue hover (the
## one high-contrast state the old theme invented) is exactly the kind of
## modern affordance the source does not have. Only the menubar and the
## dropdowns highlight on hover, because the prototype styles those two.
static func _button(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", bevel(Palette.WIN_FACE, true, BUTTON_PAD))
	theme.set_stylebox("focus", "Button", bevel(Palette.WIN_FACE, true, BUTTON_PAD))
	theme.set_stylebox("hover", "Button", bevel(Palette.WIN_FACE, true, BUTTON_PAD))
	theme.set_stylebox("pressed", "Button", bevel(Palette.WIN_FACE, false, BUTTON_PAD))
	theme.set_stylebox("disabled", "Button", bevel(Palette.WIN_FACE, true, BUTTON_PAD))
	theme.set_color("font_color", "Button", Color.BLACK)
	theme.set_color("font_hover_color", "Button", Color.BLACK)
	theme.set_color("font_pressed_color", "Button", Color.BLACK)
	theme.set_color("font_disabled_color", "Button", Palette.WIN_FACE_DARK)
	theme.set_constant("h_separation", "Button", 0)
	theme.set_font_size("font_size", "Button", FONT_BODY)


## index.html:109-118: the menubar entries are bare text that lights up
## titlebar-blue on hover -- no button frame at any point, which is why
## MenuButton gets empty styleboxes rather than Button's bevels.
static func _menu(theme: Theme) -> void:
	theme.set_stylebox("normal", "MenuButton", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "MenuButton", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "MenuButton", flat(Palette.TITLEBAR))
	theme.set_stylebox("pressed", "MenuButton", flat(Palette.TITLEBAR))
	theme.set_stylebox("disabled", "MenuButton", StyleBoxEmpty.new())
	theme.set_color("font_color", "MenuButton", Color.BLACK)
	theme.set_color("font_hover_color", "MenuButton", Color.WHITE)
	theme.set_color("font_pressed_color", "MenuButton", Color.WHITE)
	theme.set_color("font_disabled_color", "MenuButton", Palette.WIN_FACE_DARK)
	theme.set_font_size("font_size", "MenuButton", FONT_BODY)


## index.html:124-150: the dropdowns are outset-framed items that go
## titlebar-blue on hover.
static func _popup(theme: Theme) -> void:
	theme.set_stylebox("panel", "PopupMenu", bevel(Palette.WIN_FACE, true))
	theme.set_stylebox("hover", "PopupMenu", flat(Palette.TITLEBAR))
	theme.set_color("font_color", "PopupMenu", Color.BLACK)
	theme.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	theme.set_color("font_disabled_color", "PopupMenu", Palette.WIN_FACE_DARK)
	theme.set_font_size("font_size", "PopupMenu", FONT_TABLE)


## index.html:297-330: a white inset-framed table whose column titles are the
## window face, sticky, and hairline-separated from the body. The row metrics
## are what let all twelve drugs fit without scrolling, so the font is
## 0.85rem, the gaps collapse, and the cells keep the prototype's 6px of
## side padding.
static func _tree(theme: Theme) -> void:
	theme.set_stylebox("panel", "Tree", bevel(Color.WHITE, false))
	theme.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	# index.html:310-316: a sticky window-face title row with a hairline
	# under it, not the default theme's dark strip.
	var header := flat(Palette.WIN_FACE)
	header.border_width_bottom = 1
	header.border_color = Palette.WIN_FACE_DARKER
	theme.set_stylebox("title_button_normal", "Tree", header)
	theme.set_stylebox("title_button_hover", "Tree", flat(Palette.WIN_FACE))
	theme.set_stylebox("title_button_pressed", "Tree", flat(Palette.WIN_FACE))
	# The prototype's table has no column rules and no focus rectangle; the
	# selection highlight is the row background set per-cell instead.
	theme.set_stylebox("cursor", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("cursor_unfocused", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("selected", "Tree", StyleBoxEmpty.new())
	theme.set_stylebox("selected_focus", "Tree", StyleBoxEmpty.new())
	theme.set_constant("draw_guides", "Tree", 0)
	theme.set_color("title_button_color", "Tree", Color.BLACK)
	theme.set_color("font_color", "Tree", Color.BLACK)
	theme.set_font("font", "Tree", ui_font())
	theme.set_font_size("font_size", "Tree", FONT_TABLE)
	# <th> is bold in a browser and Tree has a separate font slot for it.
	theme.set_font("title_button_font", "Tree", bold_font())
	theme.set_font_size("title_button_font_size", "Tree", FONT_TABLE)
	theme.set_constant("v_separation", "Tree", 0)
	theme.set_constant("h_separation", "Tree", 4)
	# index.html:323-329 -- tbody td { padding: 2px 6px }.
	theme.set_constant("inner_item_margin_left", "Tree", 6)
	theme.set_constant("inner_item_margin_right", "Tree", 6)
	theme.set_constant("inner_item_margin_top", "Tree", 1)
	theme.set_constant("inner_item_margin_bottom", "Tree", 1)


## A 2px-tall horizontal gradient, which is all a titlebar needs. Built as a
## 256x2 texture stretched horizontally so the gradient runs left-to-right at
## any window width. `base_type` is the class that will wear it, which decides
## the item the stylebox is filed under -- see the resolution rule above.
static func _titlebar(theme: Theme, type_name: String, base_type: String) -> void:
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
	theme.set_type_variation(type_name, base_type)
	theme.set_stylebox("normal" if base_type == "Label" else "panel", type_name, box)
	theme.set_color("font_color", type_name, Palette.TITLEBAR_TEXT)
	theme.set_font("font", type_name, bold_font())
	theme.set_font_size("font_size", type_name, FONT_BODY)


static func flat(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	return box
