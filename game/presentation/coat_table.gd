class_name CoatTable
extends VBoxContainer

## The trenchcoat contents table (index.html:1195-1214): one row per drug
## held, with quantity and running average buy price.
##
## The average is `avg_price_cents` over 100. The prototype prints
## `fmt(avgPrice)` -- a whole-dollar rounding of a float64 the core also keeps
## as a float64. The ABI projects it to integer cents, so this shows dollars
## rounded from cents: same display, computed from the value the core actually
## publishes.
##
## index.html:1205 colors the *selected* row dark red when the drug it holds is
## not traded here, because the Sell button will be disabled. Same rule, same
## place: on selection only.

signal drug_selected(drug_index: int)

var _title: Label
var _tree: Tree
var _items: Dictionary = {}
var _traded: Dictionary = {}

## Tree.set_selected() emits item_selected, so applying a selection
## programmatically would re-enter _on_item_selected and rebuild the selection
## forever. Set while the table is driving the Tree itself.
var _applying := false


func _init() -> void:
	theme = Win98Theme.shared()
	add_theme_constant_override("separation", 2)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_title = Label.new()
	_title.theme_type_variation = &"TableTitle"
	add_child(_title)

	_tree = Tree.new()
	_tree.name = "Tree"
	_tree.theme = Win98Theme.shared()
	_tree.columns = 3
	_tree.column_titles_visible = true
	_tree.hide_root = true
	_tree.set_column_title(0, tr(Copy.COL_DRUG))
	_tree.set_column_title(1, tr(Copy.COL_QTY))
	_tree.set_column_title(2, tr(Copy.COL_PRICE))
	for column in range(1, 3):
		_tree.set_column_custom_minimum_width(column, 72)
	_tree.set_column_expand(0, true)
	_tree.item_selected.connect(_on_item_selected)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tree)


func refresh(world: SimWorld, selected: int) -> void:
	_tree.clear()
	_items.clear()

	# Which drugs are tradable here decides the unavailable styling and the
	# Sell button's enabled state, so it is read alongside the inventory
	# rather than derived from a second source.
	_traded = {}
	for slot in world.prices_copy():
		_traded[int(slot["drug_index"])] = true

	var used := world.coat_used()
	_title.text = Copy.coat_space(
		int(used.get("used", 0)),
		int(world.state_get().get("coat_capacity", 0))
	)

	var root := _tree.create_item()
	var drugs := Roster.drugs()
	var slots := _by_drug(world)

	for drug_index in Roster.sorted_drug_indices():
		if not slots.has(drug_index):
			continue
		var slot: Dictionary = slots[drug_index]
		var item := _tree.create_item(root)
		# index.html:319-321 right-aligns the numeric columns; Godot 4 dropped
		# Tree.set_column_align in favour of a per-cell alignment.
		for column in range(1, 3):
			item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_RIGHT)
		item.set_text(0, String(drugs[drug_index]["name"]))
		item.set_meta(&"drug_index", drug_index)
		item.set_selectable(0, true)
		item.set_text(1, Copy.fmt(int(slot["qty"])))
		item.set_text(2, Copy.fmt(int(slot["avg_price_cents"]) / 100.0))
		_items[drug_index] = item

	selected_changed(selected)


## Selection plus the unavailable variant (index.html:1205).
func selected_changed(drug_index: int) -> void:
	_applying = true
	for held: int in _items:
		var item: TreeItem = _items[held]
		var is_selected := held == drug_index
		var available := _traded.has(held)
		var bg := Color.TRANSPARENT
		var fg := Color.BLACK
		if is_selected:
			if available:
				bg = Palette.ROW_SELECTED
				fg = Palette.ROW_SELECTED_TEXT
			else:
				bg = Palette.ROW_UNAVAILABLE
				fg = Palette.ROW_UNAVAILABLE_TEXT
		for column in range(3):
			item.set_custom_bg_color(column, bg)
			item.set_custom_color(column, fg)
	_select_row(drug_index)
	_applying = false


## True when the held drug can be sold here -- index.html:1218's canSell test,
## minus the selection and the dead check.
func is_traded(drug_index: int) -> bool:
	return _traded.has(drug_index)


## Whether the drug is held at all, which is what index.html:1188 tests before
## pointing the sell selection at a drug the player clicked in the market.
func holds(drug_index: int) -> bool:
	return _items.has(drug_index)


func row_count() -> int:
	return _items.size()


## The Tree itself, for the ui_flow test's routed click. See the note on
## MarketTable.tree().
func tree() -> Tree:
	return _tree


## The rows in the order they are shown, for the ui_flow test.
func shown_drug_indices() -> Array[int]:
	var out: Array[int] = []
	for drug_index in Roster.sorted_drug_indices():
		if _items.has(drug_index):
			out.append(drug_index)
	return out


func quantity_text(drug_index: int) -> String:
	if not _items.has(drug_index):
		return ""
	return (_items[drug_index] as TreeItem).get_text(1)


static func _by_drug(world: SimWorld) -> Dictionary:
	var slots := {}
	for slot in world.inventory_copy():
		slots[int(slot["drug_index"])] = slot
	return slots


## Selects the row for `drug_index` the way a click does. Tree.set_selected
## emits item_selected, so this runs the real handler -- including the render()
## that index.html:1189 and :1210 end their click handlers with. A test that
## called Hud.select_buy_drug directly would skip exactly that. The render
## itself is deferred out of the selection event, so a caller that wants the
## post-render state has to give it a frame.
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


## A click rebuilds the table, the way the prototype's handler ends in a full
## render() (index.html:1210) -- but a Tree refuses to clear itself or create
## items while it is still inside its own mouse-selection event, so emitting
## synchronously aborted the rebuild and left the table empty. Deferring puts
## the refresh after the event, in the same frame.
func _on_item_selected() -> void:
	if _applying:
		return
	var item := _tree.get_selected()
	if item == null:
		return
	if item.has_meta(&"drug_index"):
		# The index is read now, while the clicked item is still the selected
		# one; only the notify is deferred.
		drug_selected.emit.call_deferred(int(item.get_meta(&"drug_index")))
