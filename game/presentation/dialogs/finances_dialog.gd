class_name FinancesDialog
extends DopeDialog

## The prototype's doFinances (index.html:1328-1365): read-only cash / bank /
## debt rows plus Deposit, Withdraw and Pay Loan, each of which opens a
## QuantityDialog rather than acting immediately.
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


func present(cash: int, bank: int, debt: int) -> FinancesDialog:
	setup(Copy.DLG_FINANCES)

	_field(tr(Copy.FIN_CASH), Copy.money(cash))
	_field(tr(Copy.FIN_BANK), Copy.money(bank))
	_field(tr(Copy.FIN_DEBT), Copy.money(debt))

	# index.html:1336-1338: each action is disabled when it could not move a
	# dollar. floor() on bank and debt because the core keeps them as float64
	# and the ABI projects them down.
	var deposit := add_button("finDeposit", Copy.BTN_DEPOSIT)
	deposit.disabled = cash <= 0
	var withdraw := add_button("finWithdraw", Copy.BTN_WITHDRAW)
	withdraw.disabled = bank <= 0
	var pay := add_button("finPayLoan", Copy.BTN_PAY_LOAN)
	pay.disabled = debt <= 0 or cash <= 0
	add_button("finClose", Copy.BTN_CLOSE, true)
	return self


## The amount each action may move, matching the prototype's `max` for each
## spinner (index.html:1347, 1354, 1361).
func amount_for(action: int, cash: int, bank: int, debt: int) -> int:
	match action:
		SimWorld.FINANCES_DEPOSIT:
			return int(floor(float(cash)))
		SimWorld.FINANCES_WITHDRAW:
			return int(floor(float(bank)))
		SimWorld.FINANCES_PAY_LOAN:
			return mini(int(floor(float(cash))), int(floor(float(debt))))
	return 0


## The prompt for each action's spinner (index.html:1346, 1353, 1360).
func prompt_for(action: int, cash: int, bank: int, debt: int) -> String:
	match action:
		SimWorld.FINANCES_DEPOSIT:
			return tr(Copy.MSG_DEPOSIT_PROMPT).format([Copy.fmt(cash)])
		SimWorld.FINANCES_WITHDRAW:
			return tr(Copy.MSG_WITHDRAW_PROMPT).format([Copy.fmt(bank)])
		SimWorld.FINANCES_PAY_LOAN:
			return tr(Copy.MSG_PAY_LOAN_PROMPT).format([Copy.fmt(debt)])
	return ""


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
