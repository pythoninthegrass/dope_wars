class_name MarketTable
extends VBoxContainer

## The "Available drugs" table (index.html:1166-1193): one row per drug traded
## at the current location, showing its price and -- from day 2 on -- a trend
## glyph against last turn's price.
##
## The two price lists come from separate ABI calls and the drug sets need not
## match, so they are intersected on drug_index rather than zipped by position
## (index.html:1174 looks up by id for the same reason). A drug with no
## previous price gets the neutral glyph, which is what the prototype renders
## for a null prevPrice (index.html:1182).
##
## A Tree rather than a column of Buttons: it is a two-column table with a
## sticky header, and rebuilding the rows on every render is what the
## prototype does anyway (it clears `innerHTML`, index.html:1167).

signal drug_selected(drug_index: int)

var _tree: Tree
var _items: Dictionary = {}

## Tree.set_selected() emits item_selected, so applying a selection
## programmatically would re-enter _on_item_selected and rebuild the selection
## forever. Set while the table is driving the Tree itself; the click path is
## the only one allowed to emit drug_selected.
var _applying := false


func _init() -> void:
	theme = Win95Theme.shared()
	add_theme_constant_override("separation", 2)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var title := Label.new()
	title.text = tr(Copy.TABLE_AVAILABLE_DRUGS)
	title.theme_type_variation = &"TableTitle"
	add_child(title)

	_tree = Tree.new()
	_tree.name = "Tree"
	_tree.theme = Win95Theme.shared()
	# The prototype's price cell is one <td> holding the trend glyph and the
	# number (index.html:500-505), which a Tree cell cannot do -- one cell is
	# one color. So the glyph is its own column, sized to the CSS slot
	# (.price-arrow { width: 1.1em; margin-right: 5% }) and left untitled,
	# which is what the prototype's two-header row looks like anyway.
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.set_column_title(0, tr(Copy.COL_DRUG))
	_tree.set_column_title(1, "")
	_tree.set_column_title(2, tr(Copy.COL_PRICE))
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_expand(2, false)
	_tree.set_column_custom_minimum_width(1, Win95Theme.TREND_SLOT)
	_tree.set_column_custom_minimum_width(2, Win95Theme.PRICE_COLUMN)
	_tree.item_selected.connect(_on_item_selected)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tree)


## Rebuilds the whole table from the world. `selected` is the buy-side
## selection or -1, and `show_trend` is the prototype's `state.day > 1` guard.
func refresh(world: SimWorld, selected: int, show_trend: bool) -> void:
	_tree.clear()
	_items.clear()
	var root := _tree.create_item()
	var current := world.prices_copy()
	var previous := _previous_by_drug(world)
	var drugs := Roster.drugs()

	for drug_index in Roster.sorted_drug_indices():
		var price := -1
		for slot in current:
			if int(slot["drug_index"]) == drug_index:
				price = int(slot["price"])
				break
		if price < 0:
			continue

		var item := _tree.create_item(root)
		# Godot 4 dropped Tree.set_column_align in favour of a per-cell
		# alignment, so the prototype's left-aligned price column is set on
		# each cell rather than once on the column.
		item.set_text_alignment(2, HORIZONTAL_ALIGNMENT_LEFT)
		item.set_text_alignment(1, HORIZONTAL_ALIGNMENT_CENTER)
		item.set_text(0, String(drugs[drug_index]["name"]))
		item.set_meta(&"drug_index", drug_index)
		item.set_selectable(0, true)
		item.set_text(2, Copy.fmt(price))
		if show_trend:
			# index.html:480-498: the glyph is its own color and its own
			# smaller size, so the price next to it stays black.
			item.set_text(1, Copy.trend(price, previous.get(drug_index)))
			item.set_custom_font(1, Win95Theme.trend_font())
			item.set_custom_font_size(1, Win95Theme.FONT_TREND)
			item.set_custom_color(1, _trend_color(price, previous.get(drug_index)))
		_items[drug_index] = item

	selected_changed(selected)


## Applies the prototype's selection highlight (index.html:1172) without a
## rebuild, so clicking a row does not have to regenerate the table.
##
## The trend column keeps its own color: `.price-arrow-up` and friends set a
## color on the glyph itself, which outranks the selected row's white
## (index.html:331-333), so only the background changes there.
func selected_changed(drug_index: int) -> void:
	_applying = true
	for drug_index_held: int in _items:
		var item: TreeItem = _items[drug_index_held]
		var is_selected := drug_index_held == drug_index
		item.set_custom_bg_color(0, Palette.ROW_SELECTED if is_selected else Color.TRANSPARENT)
		item.set_custom_color(0, Palette.ROW_SELECTED_TEXT if is_selected else Color.BLACK)
		item.set_custom_bg_color(1, Palette.ROW_SELECTED if is_selected else Color.TRANSPARENT)
		item.set_custom_bg_color(2, Palette.ROW_SELECTED if is_selected else Color.TRANSPARENT)
		item.set_custom_color(2, Palette.ROW_SELECTED_TEXT if is_selected else Color.BLACK)
	_select_row(drug_index)
	_applying = false


func row_count() -> int:
	return _items.size()


## The rows in the order they are shown, for the ui_flow test.
func shown_drug_indices() -> Array[int]:
	var out: Array[int] = []
	for drug_index in Roster.sorted_drug_indices():
		if _items.has(drug_index):
			out.append(drug_index)
	return out


## The rendered price cell, for the ui_flow test. "" when the row is absent.
func price_text(drug_index: int) -> String:
	if not _items.has(drug_index):
		return ""
	return (_items[drug_index] as TreeItem).get_text(2)


## The rendered trend glyph, for the ui_flow test. Empty on day 1 and on any
## row that is not in the market, which is what index.html:1176-1184 renders.
func trend_text(drug_index: int) -> String:
	if not _items.has(drug_index):
		return ""
	return (_items[drug_index] as TreeItem).get_text(1)


static func _previous_by_drug(world: SimWorld) -> Dictionary:
	var by_drug := {}
	for slot in world.prev_prices_copy():
		by_drug[int(slot["drug_index"])] = int(slot["price"])
	return by_drug


static func _trend_color(price: int, previous: Variant) -> Color:
	if previous == null:
		return Palette.TREND_NEUTRAL
	if price > int(previous):
		return Palette.TREND_UP
	if price < int(previous):
		return Palette.TREND_DOWN
	return Palette.TREND_NEUTRAL


## Selects the row for `drug_index` the way a click does. Tree.set_selected
## emits item_selected, so this runs the real handler -- including the render()
## that index.html:1189 and :1210 end their click handlers with. A test that
## called Hud.select_buy_drug directly would skip exactly that.
func select_drug(drug_index: int) -> bool:
	if not _items.has(drug_index):
		return false
	_tree.set_selected(_items[drug_index], 0)
	return true


## Tree.set_selected rejects a null item, so clearing the selection is
## deselect_all() rather than selecting nothing.
func _select_row(drug_index: int) -> void:
	if _items.has(drug_index):
		_tree.set_selected(_items[drug_index], 0)
	else:
		_tree.deselect_all()


func _on_item_selected() -> void:
	if _applying:
		return
	var item := _tree.get_selected()
	if item == null:
		return
	if item.has_meta(&"drug_index"):
		drug_selected.emit(int(item.get_meta(&"drug_index")))
