class_name FinancesDialog
extends DopeDialog

## Beermat 2.1's Finances window, laid out as its form is
## (vendor/dopewars-2001/re/forms/FinanceDlg.dfm): a bevelled money panel
## holding the read-only Cash and Bank boxes beside their four buttons in a 2x2
## grid, a group box captioned with the outstanding total around the loans
## table and Repay Loan, and a second captioned "Loan Shark offerings:" around
## the offerings table, the debt cap note, the borrow prompt, the spinner and
## Borrow. The form's right column carries the shark name and OK; the shark
## portrait 2.1 paints there from EXE resources is not recreated.
##
## Deposit and Withdraw still open a QuantityDialog, as the oracle opens its
## "How much?" prompt. The DialogHost has one slot, so the owner re-presents
## this dialog after each amount (index.html:1348-1363). Repay and Borrow are
## reported as finRepay<shark index> and finBorrow<shark index>:<amount>, since
## the host has already closed the dialog by the time the owner hears of them.

## The form is 564 wide, 352 of it the left column and 200 the right; the port
## is wider because its chrome measures in 15px rem rather than Delphi pixels,
## and the whole dialog has to stay inside the 704x620 game window.
const WIDTH := 672.0
const LEFT_WEIGHT := 352.0
## Narrower than the form's 200: that column is sized around the shark portrait
## 2.1 paints there, which the port does not draw, and the left column needs the
## width for the debt cap note to read on one line as the oracle's does.
const RIGHT_WEIGHT := 170.0
## The form's lists are 100 tall in a 446-tall dialog; the port's window leaves
## less room once its larger type is counted.
const TABLE_HEIGHT := 90.0

## The column widths the form gives each list, in the order its columns appear.
const LOAN_COLUMNS := [142, 80, 50, 64]
const OFFER_COLUMNS := [172, 50, 64, 50]
## A Tree's title button carries 6px of padding on each side (Win98Theme._tree),
## so a column narrower than its title plus this clips the heading.
const TITLE_PAD := 12

var _loans_tree: Tree
var _offers_tree: Tree
var _repay_button: Button
var _borrow_button: Button
var _borrow_spinner: SpinBox
var _shark_label: Label
var _cash := 0
var _loans: Array
var _offers: Array


func present(cash: int, bank: int, debt: int, offers: Array, loans: Array, withhold: int) -> FinancesDialog:
	setup(Copy.DLG_FINANCES)
	custom_minimum_size = Vector2(WIDTH, 0)
	_cash = cash
	_loans = loans
	_offers = offers

	var columns := HBoxContainer.new()
	columns.name = "Columns"
	columns.add_theme_constant_override("separation", 10)
	body().add_child(columns)

	var left := VBoxContainer.new()
	left.name = "LeftColumn"
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = LEFT_WEIGHT
	columns.add_child(left)

	var right := VBoxContainer.new()
	right.name = "RightColumn"
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = RIGHT_WEIGHT
	columns.add_child(right)

	# OK is filled first because add_button() makes the first button added the
	# dialog's default action, which is what the form's Default = True says.
	_right_column(right)
	_money_panel(left, cash, bank, withhold)
	_loans_group(left, debt, loans)
	_offers_group(left, offers)
	return self


## The form's SkinMoneyPanel: Cash and Bank as read-only boxes with their own
## labels, each row ending in the two buttons that move that balance.
func _money_panel(parent: Container, cash: int, bank: int, withhold: int) -> void:
	var panel := PanelContainer.new()
	panel.name = "MoneyPanel"
	panel.theme_type_variation = &"Outset"
	parent.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	margin.add_child(grid)

	_value_box(grid, "CashValue", tr(Copy.FIN_CASH), Copy.fmt(cash))
	# index.html:1336-1338: each action is disabled when it could not move a dollar.
	_panel_button(grid, "finDeposit", Copy.BTN_DEPOSIT, Copy.HINT_DEPOSIT, cash <= 0)
	# 2.1's Deposit All But.. acts at once, so it is disabled when it would move nothing.
	_panel_button(grid, "finDepositAllBut", Copy.BTN_DEPOSIT_ALL_BUT, Copy.HINT_DEPOSIT_ALL_BUT, cash <= withhold)

	_value_box(grid, "BankValue", tr(Copy.FIN_BANK), Copy.fmt(bank))
	_panel_button(grid, "finWithdraw", Copy.BTN_WITHDRAW, Copy.HINT_WITHDRAW, bank <= 0)
	_panel_button(grid, "finWithdrawAll", Copy.BTN_WITHDRAW_ALL, Copy.HINT_WITHDRAW_ALL, bank <= 0)


## The form's Outstanding Loans group: the loans table and Repay Loan, under a
## caption that carries the total owed.
func _loans_group(parent: Container, debt: int, loans: Array) -> void:
	var group := _group_box(parent, "LoansGroup", tr(Copy.FIN_LOANS_TOTAL).format([Copy.fmt(debt)]))
	_loans_tree = _table(
		group, "LoansTree", [Copy.FIN_COL_SHARK_NAME, Copy.FIN_COL_AMOUNT, Copy.FIN_COL_RATE, Copy.FIN_COL_DAYS_LEFT], LOAN_COLUMNS
	)
	for loan in loans:
		var shark_index := int(loan["shark_index"])
		_add_row(_loans_tree, shark_index, [
			Roster.shark_name(shark_index), Copy.fmt(int(loan["balance"])),
			str(Roster.sharks()[shark_index]["rate_percent"]), str(int(loan["days_left"])),
		])
	_loans_tree.item_selected.connect(_on_loan_selected)
	# The form's LoanLV.OnDblClick is SkinRepayBtnClick.
	_loans_tree.item_activated.connect(_on_repay_pressed)

	_repay_button = Button.new()
	_repay_button.name = "finRepay"
	_repay_button.text = tr(Copy.BTN_REPAY_LOAN)
	_repay_button.tooltip_text = tr(Copy.HINT_REPAY_LOAN)
	_repay_button.disabled = true
	_repay_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_repay_button.pressed.connect(_on_repay_pressed)
	group.add_child(_repay_button)


## The form's Loan Shark offerings group: the offerings table, the debt cap
## note, and the "How much to borrow?" row.
func _offers_group(parent: Container, offers: Array) -> void:
	var group := _group_box(parent, "OffersGroup", tr(Copy.FIN_OFFERINGS))
	_offers_tree = _table(
		group, "OffersTree", [Copy.FIN_COL_NAME, Copy.FIN_COL_RATE, Copy.FIN_COL_DURATION, Copy.FIN_COL_AMOUNT], OFFER_COLUMNS
	)
	for offer in offers:
		var shark_index := int(offer["shark_index"])
		var shark: Dictionary = Roster.sharks()[shark_index]
		_add_row(_offers_tree, shark_index, [
			shark["name"], str(shark["rate_percent"]),
			tr(Copy.MSG_DURATION_DAYS).format([shark["duration_days"]]), Copy.fmt(int(offer["max_amount"])),
		])
	_offers_tree.item_selected.connect(_on_offer_selected)
	# The form's LoanSharkLV.OnDblClick is SkinBorrowBtnClick.
	_offers_tree.item_activated.connect(_on_borrow_pressed)

	_note(group, tr(Copy.FIN_DEBT_CAP_NOTE))
	_borrow_row(group)


## The form's right column: the shark name over the dialog's OK button, with
## the space between them where 2.1 paints the shark's portrait.
func _right_column(right: VBoxContainer) -> void:
	_shark_label = Label.new()
	_shark_label.name = "SharkNameLabel"
	_shark_label.text = tr(Copy.FIN_SHARKS_LABEL)
	_shark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shark_label.add_theme_font_size_override("font_size", Win98Theme.FONT_DIALOG_HEADING)
	right.add_child(_shark_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)

	var ok := add_button("finOk", Copy.BTN_OK, true, right)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END


## A captioned frame, as the form's TGroupBoxes are: the caption above an inset
## panel holding the group's controls. Returns the container to fill.
func _group_box(parent: Container, node_name: String, caption: String) -> VBoxContainer:
	var group := VBoxContainer.new()
	group.name = node_name
	group.add_theme_constant_override("separation", 2)
	parent.add_child(group)

	var label := Label.new()
	label.name = node_name + "Caption"
	label.text = caption
	label.add_theme_font_size_override("font_size", Win98Theme.FONT_DIALOG_HEADING)
	group.add_child(label)

	var frame := PanelContainer.new()
	frame.theme_type_variation = &"Inset"
	group.add_child(frame)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	frame.add_child(margin)

	var content := VBoxContainer.new()
	content.name = node_name + "Content"
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	return content


## A read-only balance box with its label, as the form's BDCash and BDBank are:
## focusable and selectable, but not typed into.
func _value_box(grid: GridContainer, node_name: String, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", Win98Theme.bold_font())
	label.add_theme_font_size_override("font_size", Win98Theme.FONT_DIALOG_HEADING)
	grid.add_child(label)

	var value := LineEdit.new()
	value.name = node_name
	value.text = value_text
	value.editable = false
	# The oracle's boxes read "1,000", left-aligned and unprefixed; the theme
	# right-aligns a LineEdit for the quantity dialogs' spinners.
	value.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# A Godot LineEdit greys its text when it is not editable; the oracle's
	# read-only boxes print theirs in the same black as an editable field.
	value.add_theme_color_override("font_uneditable_color", Color.BLACK)
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(value)


func _panel_button(grid: GridContainer, key: String, label_key: String, hint_key: String, disabled: bool) -> void:
	var button := add_button(key, label_key, false, grid)
	button.tooltip_text = tr(hint_key)
	button.disabled = disabled


## A list, framed like the market table on the main window: a white inset
## frame around the Tree, with each column title aligned the way its cells are,
## which is what the oracle's TListView headers do (the form right-justifies
## every column but the name).
func _table(parent: Container, node_name: String, column_keys: Array, widths: Array) -> Tree:
	var tree := Tree.new()
	tree.name = node_name
	tree.columns = column_keys.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.custom_minimum_size = Vector2(0, TABLE_HEIGHT)
	# Tree shows a cell's own text as a tooltip when no tooltip_text is set
	# (scene/gui/tree.cpp); neither the oracle nor the main window's tables do.
	tree.auto_tooltip = false
	for column in column_keys.size():
		var title := tr(String(column_keys[column]))
		tree.set_column_title(column, title)
		tree.set_column_title_alignment(
			column, HORIZONTAL_ALIGNMENT_LEFT if column == 0 else HORIZONTAL_ALIGNMENT_RIGHT
		)
		tree.set_column_expand(column, column == 0)
		tree.set_column_custom_minimum_width(column, _column_width(title, int(widths[column])))
	tree.create_item()

	# market_table.gd: the frame belongs to a wrapper rather than the Tree,
	# whose own opaque header strip would paint over a border along its top.
	var frame := PanelContainer.new()
	frame.name = node_name + "Frame"
	frame.theme_type_variation = &"TableFrame"
	frame.add_child(tree)
	parent.add_child(frame)
	return tree


## The form's column width, widened when the port's font needs more room for
## the heading than Delphi's did -- a clipped title is worse than a wide column.
static func _column_width(title: String, form_width: int) -> int:
	var text := Win98Theme.bold_font().get_string_size(
		title, HORIZONTAL_ALIGNMENT_LEFT, -1, Win98Theme.FONT_TABLE
	).x
	return maxi(form_width, int(ceil(text)) + TITLE_PAD)


## A row whose first column is the shark's name and whose metadata is the shark
## index, which is what the buttons act on. Number columns align right.
func _add_row(tree: Tree, shark_index: int, cells: Array) -> void:
	var item := tree.create_item(tree.get_root())
	item.set_metadata(0, shark_index)
	for column in cells.size():
		item.set_text(column, String(cells[column]))
		if column > 0:
			item.set_text_alignment(column, HORIZONTAL_ALIGNMENT_RIGHT)


## "How much to borrow?" with its spinner and Borrow button, below the debt cap
## note; both wait for an offer to be selected.
func _borrow_row(parent: Container) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var label := Label.new()
	label.text = tr(Copy.FIN_BORROW_PROMPT)
	label.add_theme_font_override("font", Win98Theme.bold_font())
	row.add_child(label)

	_borrow_spinner = SpinBox.new()
	_borrow_spinner.name = "BorrowSpinner"
	_borrow_spinner.min_value = 0
	_borrow_spinner.max_value = 0
	_borrow_spinner.step = 1
	_borrow_spinner.select_all_on_focus = true
	_borrow_spinner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_borrow_spinner)

	_borrow_button = Button.new()
	_borrow_button.name = "finBorrow"
	_borrow_button.text = tr(Copy.BTN_BORROW)
	_borrow_button.tooltip_text = tr(Copy.HINT_BORROW)
	_borrow_button.disabled = true
	_borrow_button.pressed.connect(_on_borrow_pressed)
	row.add_child(_borrow_button)


func _selected_shark(tree: Tree) -> int:
	var item := tree.get_selected()
	return int(item.get_metadata(0)) if item != null else -1


func _on_loan_selected() -> void:
	var shark_index := _selected_shark(_loans_tree)
	_name_shark(shark_index)
	for loan in _loans:
		if int(loan["shark_index"]) == shark_index:
			_repay_button.text = tr(Copy.BTN_REPAY).format([Copy.fmt(int(loan["payoff"]))])
			_repay_button.disabled = _cash < int(loan["payoff"])


func _on_offer_selected() -> void:
	var shark_index := _selected_shark(_offers_tree)
	_name_shark(shark_index)
	for offer in _offers:
		if int(offer["shark_index"]) == shark_index:
			_borrow_spinner.max_value = int(offer["max_amount"])
			_borrow_spinner.value = int(offer["max_amount"])
			_borrow_button.disabled = int(offer["max_amount"]) <= 0


## The form's SharkNameLabel: the selected shark's name, or the generic caption
## while nothing is selected.
func _name_shark(shark_index: int) -> void:
	_shark_label.text = tr(Copy.FIN_SHARKS_LABEL) if shark_index < 0 else Roster.shark_name(shark_index)


func _on_repay_pressed() -> void:
	if _repay_button.disabled:
		return
	var shark_index := _selected_shark(_loans_tree)
	if shark_index >= 0:
		_on_button_pressed("finRepay%d" % shark_index)


func _on_borrow_pressed() -> void:
	if _borrow_button.disabled:
		return
	var shark_index := _selected_shark(_offers_tree)
	if shark_index >= 0:
		# apply() commits typed text the way Enter would.
		_borrow_spinner.apply()
		_on_button_pressed("finBorrow%d:%d" % [shark_index, int(_borrow_spinner.value)])


## The amount each action may move, matching the prototype's `max` for each
## spinner (index.html:1347, 1354).
func amount_for(action: int, cash: int, bank: int) -> int:
	match action:
		SimWorld.FINANCES_DEPOSIT:
			return int(floor(float(cash)))
		SimWorld.FINANCES_WITHDRAW:
			return int(floor(float(bank)))
	return 0


## The prompt for each action's spinner (index.html:1346, 1353).
func prompt_for(action: int, cash: int, bank: int) -> String:
	match action:
		SimWorld.FINANCES_DEPOSIT:
			return tr(Copy.MSG_DEPOSIT_PROMPT).format([Copy.fmt(cash)])
		SimWorld.FINANCES_WITHDRAW:
			return tr(Copy.MSG_WITHDRAW_PROMPT).format([Copy.fmt(bank)])
	return ""


func _note(parent: Container, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
