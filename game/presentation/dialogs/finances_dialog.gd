class_name FinancesDialog
extends DopeDialog

## Beermat 2.1's Finances window (docs/beermat-2.1-re.md): Cash and Bank with
## their Deposit / Withdraw buttons in a grid, the Outstanding Loans table with
## a Repay Loan button, and the Loan Shark offerings table with the "How much to
## borrow?" spinner and a Borrow button. Rows are selected, then acted on; the
## artwork on the oracle's right-hand side is not recreated.
##
## Deposit and Withdraw still open a QuantityDialog, as the oracle opens its
## "How much?" prompt. The DialogHost has one slot, so the owner re-presents
## this dialog after each amount (index.html:1348-1363). Repay and Borrow are
## reported as finRepay<shark index> and finBorrow<shark index>:<amount>, since
## the host has already closed the dialog by the time the owner hears of them.

const WIDTH := 540.0
const TABLE_HEIGHT := 96.0

var _loans_tree: Tree
var _offers_tree: Tree
var _repay_button: Button
var _borrow_button: Button
var _borrow_spinner: SpinBox
var _cash := 0
var _loans: Array
var _offers: Array


func present(cash: int, bank: int, debt: int, offers: Array, loans: Array, withhold: int) -> FinancesDialog:
	setup(Copy.DLG_FINANCES)
	custom_minimum_size = Vector2(WIDTH, 0)
	_cash = cash
	_loans = loans
	_offers = offers

	_balances_grid(cash, bank, withhold)

	_heading(tr(Copy.FIN_LOANS_TOTAL).format([Copy.fmt(debt)]))
	_loans_tree = _table([Copy.FIN_COL_SHARK_NAME, Copy.FIN_COL_AMOUNT, Copy.FIN_COL_RATE, Copy.FIN_COL_DAYS_LEFT], "LoansTree")
	for loan in loans:
		var shark_index := int(loan["shark_index"])
		_add_row(_loans_tree, shark_index, [
			Roster.shark_name(shark_index), Copy.fmt(int(loan["balance"])),
			str(Roster.sharks()[shark_index]["rate_percent"]), Copy.loan_days(int(loan["days_left"])),
		])
	_loans_tree.item_selected.connect(_on_loan_selected)
	_repay_button = Button.new()
	_repay_button.name = "finRepay"
	_repay_button.text = tr(Copy.BTN_REPAY_LOAN)
	_repay_button.disabled = true
	_repay_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_repay_button.pressed.connect(_on_repay_pressed)
	body().add_child(_repay_button)

	_heading(tr(Copy.FIN_OFFERINGS))
	_offers_tree = _table([Copy.FIN_COL_NAME, Copy.FIN_COL_RATE, Copy.FIN_COL_DURATION, Copy.FIN_COL_AMOUNT], "OffersTree")
	for offer in offers:
		var shark_index := int(offer["shark_index"])
		var shark: Dictionary = Roster.sharks()[shark_index]
		_add_row(_offers_tree, shark_index, [
			shark["name"], str(shark["rate_percent"]),
			tr(Copy.MSG_DURATION_DAYS).format([shark["duration_days"]]), Copy.fmt(int(offer["max_amount"])),
		])
	_offers_tree.item_selected.connect(_on_offer_selected)

	_note(tr(Copy.FIN_DEBT_CAP_NOTE))
	_borrow_row()

	add_button("finClose", Copy.BTN_CLOSE, true)
	return self


## Cash and Bank on one grid with the buttons that act on each; the values are
## read-only, as the oracle's boxes are.
func _balances_grid(cash: int, bank: int, withhold: int) -> void:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	body().add_child(grid)

	_grid_value(grid, tr(Copy.FIN_CASH), Copy.money(cash))
	var deposit := add_button("finDeposit", Copy.BTN_DEPOSIT, false, grid)
	# index.html:1336-1338: each action is disabled when it could not move a dollar.
	deposit.disabled = cash <= 0
	# 2.1's Deposit All But.. acts at once, so it is disabled when it would move nothing.
	var deposit_all_but := add_button("finDepositAllBut", Copy.BTN_DEPOSIT_ALL_BUT, false, grid)
	deposit_all_but.disabled = cash <= withhold

	_grid_value(grid, tr(Copy.FIN_BANK), Copy.money(bank))
	var withdraw := add_button("finWithdraw", Copy.BTN_WITHDRAW, false, grid)
	withdraw.disabled = bank <= 0
	var withdraw_all := add_button("finWithdrawAll", Copy.BTN_WITHDRAW_ALL, false, grid)
	withdraw_all.disabled = bank <= 0


func _grid_value(grid: GridContainer, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_override("font", Win98Theme.bold_font())
	grid.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.add_theme_font_override("font", Win98Theme.bold_font())
	grid.add_child(value)


func _table(column_keys: Array, node_name: String) -> Tree:
	var tree := Tree.new()
	tree.name = node_name
	tree.columns = column_keys.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.select_mode = Tree.SELECT_ROW
	tree.custom_minimum_size = Vector2(0, TABLE_HEIGHT)
	for column in column_keys.size():
		tree.set_column_title(column, tr(String(column_keys[column])))
		tree.set_column_expand(column, column == 0)
		tree.set_column_custom_minimum_width(column, 64 if column > 0 else 120)
	tree.create_item()
	body().add_child(tree)
	return tree


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
func _borrow_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	body().add_child(row)
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
	_borrow_button.disabled = true
	_borrow_button.pressed.connect(_on_borrow_pressed)
	row.add_child(_borrow_button)


func _selected_shark(tree: Tree) -> int:
	var item := tree.get_selected()
	return int(item.get_metadata(0)) if item != null else -1


func _on_loan_selected() -> void:
	var shark_index := _selected_shark(_loans_tree)
	for loan in _loans:
		if int(loan["shark_index"]) == shark_index:
			_repay_button.text = tr(Copy.BTN_REPAY).format([Copy.fmt(int(loan["payoff"]))])
			_repay_button.disabled = _cash < int(loan["payoff"])


func _on_offer_selected() -> void:
	var shark_index := _selected_shark(_offers_tree)
	for offer in _offers:
		if int(offer["shark_index"]) == shark_index:
			_borrow_spinner.max_value = int(offer["max_amount"])
			_borrow_spinner.value = int(offer["max_amount"])
			_borrow_button.disabled = int(offer["max_amount"]) <= 0


func _on_repay_pressed() -> void:
	var shark_index := _selected_shark(_loans_tree)
	if shark_index >= 0:
		_on_button_pressed("finRepay%d" % shark_index)


func _on_borrow_pressed() -> void:
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


func _heading(text: String) -> void:
	var label := Label.new()
	label.add_theme_font_override("font", Win98Theme.bold_font())
	label.text = text
	body().add_child(label)


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(label)
