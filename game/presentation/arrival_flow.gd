class_name ArrivalFlow
extends RefCounted

## What happens when the player arrives somewhere new, as an explicit queue
## instead of the prototype's recursive `processQueue` closure chain
## (index.html:1378-1470).
##
## The order is Beermat's, and the order is load-bearing because every step
## draws from the one world RNG stream:
##
##   1. one toast per cheap/expensive price event, cheapest to draw no news
##   2. if should_start_chase fired, the chase -- and nothing else. A chase
##      skips the dealer and the arrival event entirely.
##   3. otherwise the dealer visit roll, then (once that dealer's dialog is
##      done) the arrival event, rolled lazily so a purchase comes first
##
## The chase is a state rather than a queue entry because it is not linear:
## Run and Stay re-present it, and only a win or a death ends it.

signal state_changed()
signal finished()

enum Step { TOAST, EVENT_ROLL, COAT_DEALER, GUN_DEALER }

## The live chase, or {} when none is unresolved. Carries the deputy count
## and whether the player may fight, both read off dw_start_chase.
var _chase: Dictionary = {}

var _queue: Array[Dictionary] = []
var _world: SimWorld
var _dialogs: DialogHost
var _on_died: Callable


## `on_died` is invoked instead of continuing the queue when the player dies
## mid-sequence, matching the prototype's `handleDeath()` branches
## (index.html:1406, 1500, 1515).
func begin(world: SimWorld, dialogs: DialogHost, on_died: Callable) -> void:
	_world = world
	_dialogs = dialogs
	_on_died = on_died
	_chase = {}
	_queue = []
	_build()
	_advance()


## True while a modal owned by this flow is up, so the caller can tell a
## pending arrival sequence from a finished one.
func is_active() -> bool:
	return not _queue.is_empty() or not _chase.is_empty()


func _build() -> void:
	# index.html:1380 -- a toast per price event, in the order the core
	# reported them.
	for event in _world.price_events_drain():
		_queue.append({"step": Step.TOAST, "event": event})

	var chase := _world.should_start_chase()
	if int(chase.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.OK and bool(chase.get("should_start", false)):
		_chase = _world.start_chase()
		_chase.erase("result")
		return

	var visit := _world.roll_dealer_visit()
	if int(visit.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.OK:
		match int(visit.get("kind", SimWorld.DEALER_NONE)):
			SimWorld.DEALER_COAT:
				_queue.append({"step": Step.COAT_DEALER})
			SimWorld.DEALER_GUN:
				_queue.append({"step": Step.GUN_DEALER})
	_queue.append({"step": Step.EVENT_ROLL})


func _advance() -> void:
	state_changed.emit()
	if not _chase.is_empty():
		_present_chase()
		return
	if _queue.is_empty():
		finished.emit()
		return

	var entry: Dictionary = _queue.pop_front()
	match int(entry["step"]):
		Step.TOAST:
			var event: Dictionary = entry["event"]
			_present_alert(
				Copy.DLG_WORD_ON_THE_STREET,
				Copy.price_event_message(int(event["kind"]), Roster.drug_id(int(event["drug_index"])), Roster.drug_name(int(event["drug_index"]))),
				AlertDialog.ICON_NEWS
			)
		Step.EVENT_ROLL:
			var arrival := _world.roll_arrival_event()
			if int(arrival.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.OK \
					and int(arrival.get("kind", SimWorld.ARRIVAL_NONE)) != SimWorld.ARRIVAL_NONE:
				_present_event(arrival)
			else:
				_advance()
		Step.COAT_DEALER:
			_present_dealer(false)
		Step.GUN_DEALER:
			_present_dealer(true)


func _present_alert(title_key: String, message: String, icon: String) -> void:
	_dialogs.open(AlertDialog.new().present(title_key, message, icon), func(_key: String) -> void: _advance())


func _present_event(event: Dictionary) -> void:
	var location_index := int(_world.state_get().get("location_index", 0))
	var message := Copy.arrival_message(event, Roster.drug_name(int(event.get("drug_index", -1))), Roster.location_name(location_index))
	_dialogs.open(AlertDialog.new().present(Copy.DLG_RANDOM_EVENT, message, AlertDialog.ICON_WARNING), func(_key: String) -> void:
		state_changed.emit()
		_advance()
	)


func _present_dealer(is_gun: bool) -> void:
	var offer := _world.roll_gun_dealer_offer() if is_gun else _world.roll_coat_dealer_offer()
	if not bool(offer.get("offered", false)):
		_advance()
		return
	var dialog := DealerDialog.new()
	dialog.offer = offer
	dialog.present(is_gun)

	_dialogs.open(dialog, func(key: String) -> void:
		if key == "dealerBuy":
			if is_gun:
				_world.accept_gun_offer(dialog.price(), dialog.name_index())
			else:
				_world.accept_coat_offer(dialog.price())
		state_changed.emit()
		_advance()
	)


func _present_chase() -> void:
	var state := _world.state_get()
	var dialog := ChaseDialog.new().present(
		int(_chase["deputies"]),
		int(state.get("health", 0)),
		bool(_chase.get("can_fight", false))
	)
	_dialogs.open(dialog, func(key: String) -> void: _on_chase_action(key, dialog))


func _on_chase_action(key: String, _dialog: ChaseDialog) -> void:
	var deputies := int(_chase["deputies"])

	match key:
		"chaseRun":
			var run := _world.run_from_chase()
			if bool(run.get("dead", false)):
				_on_died.call()
				return
			if bool(run.get("escaped", false)):
				_chase = {}
				_present_alert(Copy.DLG_COP_CHASE, tr(Copy.MSG_CHASE_ESCAPED), AlertDialog.ICON_FLAG)
				return
			# A failed run is not terminal: the cops fired and are still on you, so re-present.
			var run_message := Copy.MSG_CHASE_RUN_HIT if bool(run.get("hit", false)) else Copy.MSG_CHASE_RUN_MISSED
			_present_alert(Copy.DLG_COP_CHASE, tr(run_message), AlertDialog.ICON_BULLET)
			return
		"chaseStay":
			var stay := _world.stay_in_chase()
			if bool(stay.get("dead", false)):
				_on_died.call()
				return
			var stay_message := Copy.MSG_CHASE_STAY_HIT if bool(stay.get("hit", false)) else Copy.MSG_CHASE_STAY_MISSED
			_present_alert(Copy.DLG_COP_CHASE, tr(stay_message), AlertDialog.ICON_BULLET)
			return
		"chaseFight":
			var fight := _world.fight(deputies)
			if int(fight.get("result", SimWorld.ERR_INVALID_ARGUMENT)) != SimWorld.OK:
				_advance()
				return
			if bool(fight.get("dead", false)):
				_on_died.call()
				return
			if bool(fight.get("won", false)):
				_chase = {}
				_present_win(int(fight.get("reward", 0)), int(fight.get("doctor_price", 0)))
				return
			_chase = _chase.duplicate()
			_chase["deputies"] = int(fight.get("deputies", deputies))
			_present_alert(
				Copy.DLG_COP_CHASE,
				Copy.fight_message(bool(fight.get("cop_hit", false))),
				AlertDialog.ICON_BULLET
			)
			return

	_advance()


## The kill message, then the doctor offer the core priced in the same call.
func _present_win(reward: int, doctor_price: int) -> void:
	_dialogs.open(AlertDialog.new().present(Copy.DLG_COP_CHASE, tr(Copy.MSG_CHASE_WON), AlertDialog.ICON_FLAG), func(_key: String) -> void:
		state_changed.emit()
		var dialog := DoctorDialog.new().present(reward, doctor_price)
		_dialogs.open(dialog, func(answer: String) -> void:
			if answer == "doctorYes":
				_world.accept_doctor_offer(dialog.price)
			_advance()
		)
	)


func _is_dead() -> bool:
	return bool(_world.state_get().get("dead", false))
