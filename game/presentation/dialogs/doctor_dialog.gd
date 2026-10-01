class_name DoctorDialog
extends DopeDialog

## The doctor offered after a chase win. The core rolls the price and always
## offers it, so there is no affordability state to show here. Yes pays the
## price and restores health; No keeps the money.

var reward := 0
var price := 0


func present(reward_total: int, doctor_price: int) -> DoctorDialog:
	reward = reward_total
	price = doctor_price
	setup(Copy.DLG_DOCTOR)

	var text := Label.new()
	text.text = Copy.doctor_offer(reward, price)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(text)

	add_button("doctorYes", Copy.BTN_YES)
	add_button("doctorNo", Copy.BTN_NO, true)
	return self
