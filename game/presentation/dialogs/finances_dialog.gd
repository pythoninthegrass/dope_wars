class_name FinancesDialog
extends DopeDialog

## The prototype's doFinances (index.html:1328-1365): read-only cash / bank /
## debt rows, the loan sharks' offers and the outstanding loans, plus Deposit and
## Withdraw, which open a QuantityDialog rather than acting immediately. Borrow
## opens one too; Repay settles the whole loan at once.
##
## So the nesting is real -- a quantity dialog opens on top of this one -- and
## the DialogHost only has one slot. The prototype has the same shape via
## `openDialog` replacing `#dialogRoot` wholesale, and gets the same way out:
## after the amount is applied the finances dialog re-opens itself
## (index.html:1348-1363). This dialog therefore exposes the pending action and
## lets the owner re-present it, rather than holding a second modal.

## The finances action, already mapped to a SimWorld constant. -1 when the
## dialog was opened with no action in flight.
var pending_action := -1
var pending_max := 0


func present(cash: int, bank: int, debt: int, offers: Array, loans: Array, withhold: int) -> FinancesDialog:
	setup(Copy.DLG_FINANCES)

	_field(tr(Copy.FIN_CASH), Copy.money(cash))
	_field(tr(Copy.FIN_BANK), Copy.money(bank))
	_field(tr(Copy.FIN_DEBT), Copy.money(debt))

	_offers_section(offers)
	_loans_section(loans, cash)

	var note := Label.new()
	note.text = tr(Copy.FIN_DEBT_CAP_NOTE)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(note)

	# index.html:1336-1338: each action is disabled when it could not move a
	# dollar.
	var deposit := add_button("finDeposit", Copy.BTN_DEPOSIT)
	deposit.disabled = cash <= 0
	# 2.1's Deposit All But.. acts at once, so it is disabled when it would move nothing.
	var deposit_all_but := add_button("finDepositAllBut", Copy.BTN_DEPOSIT_ALL_BUT)
	deposit_all_but.disabled = cash <= withhold
	var withdraw := add_button("finWithdraw", Copy.BTN_WITHDRAW)
	withdraw.disabled = bank <= 0
	add_button("finClose", Copy.BTN_CLOSE, true)
	return self


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


## One button per shark making an offer, named finBorrow<shark index>, laid out
## as Beermat's Name / % Rate / Duration / Amount list. Picking one opens the
## borrow quantity dialog, capped at the offer's max_amount.
func _offers_section(offers: Array) -> void:
	_heading(tr(Copy.FIN_SHARKS))
	if offers.is_empty():
		_note(tr(Copy.FIN_NO_OFFERS))
		return
	_note(tr(Copy.FIN_SHARK_COLUMNS))
	for offer in offers:
		var shark_index := int(offer["shark_index"])
		var shark: Dictionary = Roster.sharks()[shark_index]
		var button := Button.new()
		button.name = "finBorrow%d" % shark_index
		button.text = tr(Copy.MSG_SHARK_OFFER).format([
			shark["name"], shark["rate_percent"], shark["duration_days"], shark["multiplier"],
		])
		button.disabled = int(offer["max_amount"]) <= 0
		button.pressed.connect(_on_button_pressed.bind(String(button.name)))
		body().add_child(button)


## One row per outstanding loan with a Repay button, named finRepay<shark
## index>, that shows what settling the loan costs right now.
func _loans_section(loans: Array, cash: int) -> void:
	_heading(tr(Copy.FIN_LOANS))
	if loans.is_empty():
		_note(tr(Copy.FIN_NO_LOANS))
		return
	for loan in loans:
		var shark_index := int(loan["shark_index"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := Label.new()
		label.text = tr(Copy.MSG_LOAN_ROW).format([
			Roster.shark_name(shark_index), Copy.fmt(int(loan["balance"])), Copy.loan_days(int(loan["days_left"])),
		])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.name = "finRepay%d" % shark_index
		button.text = tr(Copy.BTN_REPAY).format([Copy.fmt(int(loan["payoff"]))])
		button.disabled = cash < int(loan["payoff"])
		button.pressed.connect(_on_button_pressed.bind(String(button.name)))
		row.add_child(button)
		body().add_child(row)


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


func _field(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := Label.new()
	# index.html:1332-1334 wraps each amount in <strong>.
	value.add_theme_font_override("font", Win98Theme.bold_font())
	value.text = value_text
	row.add_child(value)
	body().add_child(row)
