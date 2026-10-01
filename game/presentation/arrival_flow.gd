class_name ArrivalFlow
extends RefCounted

## What happens when the player arrives somewhere new, as an explicit queue
## instead of the prototype's recursive `processQueue` closure chain
## (index.html:1378-1470).
##
## The order is the prototype's, and the order is load-bearing because every
## step draws from the one world RNG stream:
##
##   1. one toast per cheap/expensive price event, cheapest to draw no news
##   2. if should_start_chase fired, the chase -- and nothing else. The
##      prototype's `else` at index.html:1383 skips the arrival event *and*
##      both dealer rolls entirely, so the RNG stream lines up.
##   3. otherwise one arrival event, unless it rolled NONE
##   4. then the coat and gun dealer visits, drawn together by
##      dw_roll_dealer_visits so the pair cannot be reordered or half-skipped
##
## The chase is a state rather than a queue entry because it is not linear:
## Run and Stay re-present it, and only a win or a death ends it.

signal state_changed()
signal finished()

enum Step { TOAST, EVENT, COAT_DEALER, GUN_DEALER }

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

	var arrival := _world.roll_arrival_event()
	if int(arrival.get("result", SimWorld.ERR_INVALID_ARGUMENT)) == SimWorld.OK \
			and int(arrival.get("kind", SimWorld.ARRIVAL_NONE)) != SimWorld.ARRIVAL_NONE:
		_queue.append({"step": Step.EVENT, "event": arrival})

	# Both draws happen here regardless of what the event was, and regardless
	# of whether the player died in it -- that is the point of routing them
	# through one ABI call.
	var visits := _world.roll_dealer_visits()
	if int(visits.get("result", SimWorld.ERR_INVALID_ARGUMENT)) != SimWorld.OK:
		return
	if bool(visits.get("coat_visit", false)):
		_queue.append({"step": Step.COAT_DEALER})
	if bool(visits.get("gun_visit", false)):
		_queue.append({"step": Step.GUN_DEALER})


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
		Step.EVENT:
			_present_event(entry["event"])
		Step.COAT_DEALER:
			_present_dealer(false)
		Step.GUN_DEALER:
			_present_dealer(true)


func _present_alert(title_key: String, message: String, icon: String) -> void:
	_dialogs.open(AlertDialog.new().present(title_key, message, icon), func(_key: String) -> void: _advance())


func _present_event(event: Dictionary) -> void:
	var message := Copy.arrival_message(event, Roster.drug_name(int(event.get("drug_index", -1))))
	var icon := AlertDialog.ICON_SKULL if int(event.get("kind", 0)) == SimWorld.ARRIVAL_FREE_WEED_DEATH else AlertDialog.ICON_WARNING
	_dialogs.open(AlertDialog.new().present(Copy.DLG_RANDOM_EVENT, message, icon), func(_key: String) -> void:
		state_changed.emit()
		if _is_dead():
			_on_died.call()
			return
		_advance()
	)


func _present_dealer(is_gun: bool) -> void:
	var state := _world.state_get()
	var offer := _world.roll_gun_dealer_offer() if is_gun else _world.roll_coat_dealer_offer()
	var dialog := DealerDialog.new()
	dialog.offer = offer
	dialog.present(is_gun, _world, int(state.get("cash", 0)), int(state.get("bank", 0)))

	_dialogs.open(dialog, func(key: String) -> void:
		if key == "dealerBuy" and dialog.can_buy:
			if is_gun:
				_world.accept_gun_offer(dialog.price(), int(offer.get("damage", 0)), int(offer.get("space", 0)))
			else:
				_world.accept_coat_offer(dialog.pockets(), dialog.price())
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


## The prototype always passes was_aggressor = false -- nothing in its flow
## ever set it true (index.html:1474 and every re-render through :1523) -- so
## the run chance is always the 60% escape roll, not the 30% one.
func _on_chase_action(key: String, dialog: ChaseDialog) -> void:
	var deputies := int(_chase["deputies"])

	match key:
		"chaseRun":
			var run := _world.run_from_chase(deputies, false)
			if _is_dead():
				_on_died.call()
				return
			if bool(run.get("escaped", false)):
				_chase = {}
				_present_alert(Copy.DLG_COP_CHASE, tr(Copy.MSG_CHASE_ESCAPED), AlertDialog.ICON_FLAG)
				return
			# A miss is not terminal: the cops are still on you, so re-present.
			_present_alert(Copy.DLG_COP_CHASE, tr(Copy.MSG_CHASE_FIRED_ON), AlertDialog.ICON_BULLET)
			return
		"chaseStay":
			_present_alert(Copy.DLG_COP_CHASE, tr(Copy.MSG_CHASE_STAND_GROUND), AlertDialog.ICON_HOURGLASS)
			return
		"chaseFight":
			var fight := _world.fight(deputies)
			if bool(fight.get("dead", false)) or _is_dead():
				_on_died.call()
				return
			if bool(fight.get("won", false)):
				_chase = {}
				_present_alert(Copy.DLG_COP_CHASE, tr(Copy.MSG_CHASE_WON), AlertDialog.ICON_FLAG)
				return
			_chase = _chase.duplicate()
			_chase["deputies"] = int(fight.get("deputies", deputies))
			_present_alert(
				Copy.DLG_COP_CHASE,
				Copy.fight_message(bool(fight.get("hit", false)), int(_chase["deputies"]), int(fight.get("damage_taken", 0))),
				AlertDialog.ICON_DAGGER if bool(fight.get("hit", false)) else AlertDialog.ICON_BULLET
			)
			return

	_advance()


func _is_dead() -> bool:
	return bool(_world.state_get().get("dead", false))
