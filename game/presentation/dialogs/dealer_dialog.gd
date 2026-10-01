class_name DealerDialog
extends DopeDialog

## The coat and gun dealer offers. One class for both, because the two
## prompts differ only in the sentence and the numbers; both offer Buy /
## Decline. The core only rolls an offer the player can afford from cash, so
## there is no affordability state to show here.

var offer: Dictionary = {}


func present(is_gun: bool) -> DealerDialog:
	setup(Copy.DLG_GUN_DEALER if is_gun else Copy.DLG_COAT_DEALER)

	var cost := price()
	var message := ""
	if is_gun:
		message = tr(Copy.MSG_GUN_OFFER).format([tr(Copy.GUN_NAME_KEYS[int(offer.get("name_index", 0))]), Copy.fmt(cost)])
	else:
		message = tr(Copy.MSG_COAT_OFFER).format([Copy.fmt(cost)])

	var text := Label.new()
	text.text = message
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(text)

	add_button("dealerBuy", Copy.BTN_BUY)
	add_button("dealerDecline", Copy.BTN_DECLINE, true)
	return self


## The price the core is asked to charge, from the offer it rolled.
func price() -> int:
	return int(offer.get("price", 0))


func name_index() -> int:
	return int(offer.get("name_index", 0))
