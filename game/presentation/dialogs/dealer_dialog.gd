class_name DealerDialog
extends DopeDialog

## The coat and gun dealer offers. One class for both, because the prototype's
## two branches (index.html:1411-1463) differ only in the sentence and the
## numbers: both compute the ATM fee, both grey out Buy when the bank cannot
## cover price + fee, and both offer Buy / Decline.
##
## The fee is arithmetic over values the core already returned -- price from
## the offer, cash and bank from the world -- so it is display math, not a
## game rule: dw_accept_coat_offer / dw_accept_gun_offer apply the same 25%
## (rules_bank_purchase_fee_bp) on the way in and are what actually move money.

var offer: Dictionary = {}
var fee := 0
var can_buy := true


## `is_gun` selects the sentence and the title; the rest is shared. The fee
## rate comes off the world rather than a constant, so the number on screen is
## the same basis-point value dw_accept_coat_offer charged.
func present(is_gun: bool, world: SimWorld, cash: int, bank: int) -> DealerDialog:
	setup(Copy.DLG_GUN_DEALER if is_gun else Copy.DLG_COAT_DEALER)
	can_buy = true

	# The prototype recomputes the fee as ceil(price * 0.25)
	# (index.html:1414). ceil on the basis-point product matches exactly and
	# reads better than going through a float.
	var price := int(offer.get("price", 0))
	fee = int(ceil(float(price) * float(world.rules_bank_purchase_fee_bp()) / 10000.0))
	var needs_bank := price > cash
	var total := price + fee
	if needs_bank and bank < total:
		can_buy = false

	var message := ""
	if is_gun:
		message = tr(Copy.MSG_GUN_OFFER).format([Copy.fmt(price)])
	else:
		message = tr(Copy.MSG_COAT_OFFER).format([int(offer.get("pockets", 0)), Copy.fmt(price)])

	var text := Label.new()
	text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(text)

	# Only shown when cash is short (index.html:1418-1420), which is the only
	# case where the bank and the fee are the player's problem.
	if needs_bank:
		var note := Label.new()
		note.text = tr(Copy.MSG_DEALER_FEE_NOTE).format([Copy.fmt(fee), Copy.fmt(total)])
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_color_override("font_color", Palette.ROW_UNAVAILABLE)
		body().add_child(note)

	var buy := add_button("dealerBuy", Copy.BTN_BUY)
	buy.disabled = not can_buy
	add_button("dealerDecline", Copy.BTN_DECLINE, true)
	return self


## The price the core is asked to charge, from the offer it rolled.
func price() -> int:
	return int(offer.get("price", 0))


func pockets() -> int:
	return int(offer.get("pockets", 0))
