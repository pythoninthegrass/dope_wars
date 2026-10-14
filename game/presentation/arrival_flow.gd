class_name ArrivalFlow
extends RefCounted

## What happens when the player arrives somewhere new, as an explicit queue
## instead of the prototype's recursive `processQueue` closure chain
## (index.html:1378-1470).
##
## The order is Beermat's, and the order is load-bearing because every step
## draws from the one world RNG stream:
##
##   0. before the day advances, one loan shark visit per overdue loan
##      (docs/beermat-2.1-re.md, N-08); a beating can kill, which ends the game
##      before the travel happens
##   1. one toast per cheap/expensive price event, cheapest to draw no news
##   2. if should_start_chase fired, the chase -- and nothing else. A chase
##      skips the dealer and the arrival event entirely.
##   3. otherwise the jail release roll (docs/beermat-2.1-re.md, N-09), the
##      dealer visit roll, then (once that dealer's dialog is done) the
##      arrival event, rolled lazily so a purchase comes first
##   4. last, a "will be visiting you tomorrow" line per loan with one day left
##
## The chase is a state rather than a queue entry because it is not linear:
## Run and Stay re-present it, and only a win or a death ends it.

signal state_changed()
signal finished()

enum Step { TOAST, SHARK_RELEASED, EVENT_ROLL, COAT_DEALER, VISIT_TOMORROW }

## The live chase, or {} when none is unresolved. Carries the deputy count
## and whether the player may fight, both read off dw_start_chase.
var _chase: Dictionary = {}

var _queue: Array[Dictionary] = []

## The overdue sharks still to visit before the day advances, the size of the
## visit list when it was built, and the travel waiting on them.
var _visits: Array = []
var _visit_total := 0
var _pending_dest := -1
var _on_arrived: Callable
var _world: SimWorld
var _dialogs: DialogHost
var _on_died: Callable
var _sound: SoundPlayer


## Main owns the one SoundPlayer for the session; this just points at it. No
## default -- `begin()` is only ever called after Main has set one.
func set_sound_player(sound: SoundPlayer) -> void:
	_sound = sound


## Travel to `dest`: the overdue loan shark visits come first, before the day
## advances. `on_arrived` runs once the travel has happened and before the
## arrival sequence starts, so the caller can repaint the new market. A travel
## the core would refuse skips the visits and just reports finished.
func begin_travel(world: SimWorld, dialogs: DialogHost, on_died: Callable, dest: int, on_arrived: Callable) -> void:
	_world = world
	_dialogs = dialogs
	_on_died = on_died
	_on_arrived = on_arrived
	_chase = {}
	_queue = []
	_visits = []
	_pending_dest = dest
	var state := _world.state_get()
	# Mirrors the core's travel guards: no visits for a travel it would refuse.
	var refused := bool(state.get("dead", false)) \
		or dest == int(state.get("location_index", -1)) \
		or int(state.get("day", 0)) >= int(state.get("num_days", 0))
	if not refused:
		_visits = _world.visits_copy(SimWorld.VISITS_OVERDUE)
	_visit_total = _visits.size()
	_next_visit()


func _next_visit() -> void:
	state_changed.emit()
	if _visits.is_empty():
		_depart()
		return
	var shark_index := int(_visits.pop_front())
	var visit := _world.shark_visit(shark_index)
	if int(visit.get("result", SimWorld.ERR_INVALID_ARGUMENT)) != SimWorld.OK:
		_next_visit()
		return
	_present_visit(shark_index, visit, _visit_total - _visits.size())


func _present_visit(shark_index: int, visit: Dictionary, visit_number: int) -> void:
	var health := int(_world.state_get().get("health", 0))
	var dialog := LoanSharkDialog.new().present(Roster.sharks()[shark_index], visit, health, visit_number, _visit_total)
	_dialogs.open(dialog, func(key: String) -> void:
		match key:
			"loanPayNow":
				var paid := _world.repay(shark_index)
				if int(paid.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.ERR_INSUFFICIENT_CASH:
					_dialogs.open(AlertDialog.new().present(Copy.DLG_LOAN_SHARK, tr(Copy.MSG_PAY_OFF_SHORT), AlertDialog.ICON_WARNING), func(_ack: String) -> void:
						_present_visit(shark_index, visit, visit_number)
					)
					return
				_next_visit()
			"loanPayLater":
				_next_visit()
			_:
				# The beating has landed; death ends the game before the travel.
				if _is_dead():
					_visits = []
					_pending_dest = -1
					_on_died.call()
					return
				_next_visit()
	)


## The visits are over: the day advances and the arrival sequence starts.
func _depart() -> void:
	var dest := _pending_dest
	_pending_dest = -1
	if _world.travel(dest) != SimWorld.OK:
		finished.emit()
		return
	_on_arrived.call()
	begin(_world, _dialogs, _on_died)


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
	return not _queue.is_empty() or not _chase.is_empty() or _pending_dest >= 0


func _build() -> void:
	# index.html:1380 -- a toast per price event, in the order the core
	# reported them.
	for event in _world.price_events_drain():
		_queue.append({"step": Step.TOAST, "event": event})

	var chase := _world.should_start_chase()
	if int(chase.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.OK and bool(chase.get("should_start", false)):
		_chase = _world.start_chase()
		_chase.erase("result")
		_queue_visit_warnings()
		return

	# The arrival roll does not run on the last day (docs/beermat-2.1-re.md, "Travel").
	var state := _world.state_get()
	if int(state.get("day", 0)) < int(state.get("num_days", 0)):
		var release := _world.roll_shark_release()
		if int(release.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.OK and int(release.get("shark_index", -1)) >= 0:
			_queue.append({"step": Step.SHARK_RELEASED, "shark_index": int(release["shark_index"])})

	var visit := _world.roll_dealer_visit()
	if int(visit.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.OK and int(visit.get("kind", SimWorld.DEALER_NONE)) == SimWorld.DEALER_COAT:
		_queue.append({"step": Step.COAT_DEALER})
	_queue.append({"step": Step.EVENT_ROLL})
	_queue_visit_warnings()


## Beermat's step 10: after interest and the price roll, a line per loan with one day left.
func _queue_visit_warnings() -> void:
	for shark_index in _world.visits_copy(SimWorld.VISITS_TOMORROW):
		_queue.append({"step": Step.VISIT_TOMORROW, "shark_index": int(shark_index)})


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
		Step.SHARK_RELEASED:
			_present_alert(
				Copy.DLG_WORD_ON_THE_STREET,
				tr(Copy.MSG_SHARK_RELEASED).format([Roster.shark_name(int(entry["shark_index"]))]),
				AlertDialog.ICON_NEWS
			)
		Step.VISIT_TOMORROW:
			_present_alert(
				Copy.DLG_WORD_ON_THE_STREET,
				tr(Copy.MSG_VISIT_TOMORROW).format([Roster.shark_name(int(entry["shark_index"]))]),
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
			_present_dealer()


func _present_alert(title_key: String, message: String, icon: String) -> void:
	_dialogs.open(AlertDialog.new().present(title_key, message, icon), func(_key: String) -> void: _advance())


func _present_event(event: Dictionary) -> void:
	# docs/beermat-re.md "Sounds": outcome 1 (mugged) and outcome 3 (dog chase)
	# are the only two arrival events with a cue; free/found drugs are silent.
	match int(event.get("kind", SimWorld.ARRIVAL_NONE)):
		SimWorld.ARRIVAL_MUGGED:
			_sound.play(SoundPlayer.Cue.MUGGED)
		SimWorld.ARRIVAL_DOG_CHASE:
			_sound.play(SoundPlayer.Cue.POLICE_DOG)

	var location_index := int(_world.state_get().get("location_index", 0))
	var message := Copy.arrival_message(event, Roster.drug_name(int(event.get("drug_index", -1))), Roster.location_name(location_index))
	_dialogs.open(AlertDialog.new().present(Copy.DLG_RANDOM_EVENT, message, AlertDialog.ICON_WARNING), func(_key: String) -> void:
		state_changed.emit()
		_advance()
	)


func _present_dealer() -> void:
	var offer := _world.roll_coat_dealer_offer()
	if not bool(offer.get("offered", false)):
		_advance()
		return
	var dialog := DealerDialog.new()
	dialog.offer = offer
	dialog.present(false)

	_dialogs.open(dialog, func(key: String) -> void:
		if key == "dealerBuy":
			_world.accept_coat_offer(dialog.price())
		state_changed.emit()
		_advance()
	)


func _present_chase() -> void:
	# docs/beermat-re.md "Sounds": DWCopChase plays each time the chase dialog
	# opens, including every re-presentation after a failed Run/Stay/Fight.
	_sound.play(SoundPlayer.Cue.COP_CHASE)
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
			# docs/beermat-re.md "Sounds": DWYouHitByGun/DWCopGunShot fire for
			# the cops' volley on Run and Stay alike; a clean escape draws none.
			if not bool(run.get("escaped", false)):
				_sound.play(SoundPlayer.Cue.YOU_HIT_BY_GUN if bool(run.get("hit", false)) else SoundPlayer.Cue.COP_GUN_SHOT)
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
			_sound.play(SoundPlayer.Cue.YOU_HIT_BY_GUN if bool(stay.get("hit", false)) else SoundPlayer.Cue.COP_GUN_SHOT)
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
			# docs/beermat-re.md "Sounds": the player's own shot always has a
			# cue (DWCopHitByGun on a kill, DWYourGunShot on a miss); the cops'
			# return fire (DWYouHitByGun/DWCopGunShot) only follows when the
			# chase isn't won, since a win ends it before they can fire back.
			_sound.play(SoundPlayer.Cue.COP_HIT_BY_GUN if bool(fight.get("killed", false)) else SoundPlayer.Cue.YOUR_GUN_SHOT)
			if bool(fight.get("won", false)):
				_chase = {}
				_present_win(int(fight.get("reward", 0)), int(fight.get("doctor_price", 0)))
				return
			_sound.play(SoundPlayer.Cue.YOU_HIT_BY_GUN if bool(fight.get("cop_hit", false)) else SoundPlayer.Cue.COP_GUN_SHOT)
			if bool(fight.get("dead", false)):
				_on_died.call()
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
