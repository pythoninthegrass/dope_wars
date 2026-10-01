class_name SimWorld
extends RefCounted

## The only .gd file allowed to reference DopeWarsWorld, the GDExtension
## class registered in extension/src/register_types.cpp --
## tools/validate_game_boundary.py fails if any other script names it. Every
## other layer reaches the simulation through this wrapper.
##
## Each method forwards to exactly one DopeWarsWorld method and does nothing
## else: no rule is recomputed here, and no world value is cached. A caller
## that wants the current cash re-asks for it, because
## docs/layer-boundaries.md forbids mirroring dw_world state into GDScript
## fields. Dictionaries come back as the shim's untyped Dictionary/Array, so
## the key names here are the shim's, not the ABI struct field names.
##
## Re-exported DopeWarsWorld constants, so callers never need to reference
## DopeWarsWorld directly merely to check a result code.
const OK := DopeWarsWorld.DW_OK
const ERR_INVALID_ARGUMENT := DopeWarsWorld.DW_ERR_INVALID_ARGUMENT
const ERR_BUFFER_TOO_SMALL := DopeWarsWorld.DW_ERR_BUFFER_TOO_SMALL
const ERR_ABI_VERSION_MISMATCH := DopeWarsWorld.DW_ERR_ABI_VERSION_MISMATCH
const ERR_UNKNOWN_LOCATION := DopeWarsWorld.DW_ERR_UNKNOWN_LOCATION
const ERR_UNKNOWN_DRUG := DopeWarsWorld.DW_ERR_UNKNOWN_DRUG
const ERR_NOT_TRADED_HERE := DopeWarsWorld.DW_ERR_NOT_TRADED_HERE
const ERR_INSUFFICIENT_CASH := DopeWarsWorld.DW_ERR_INSUFFICIENT_CASH
const ERR_INSUFFICIENT_BANK := DopeWarsWorld.DW_ERR_INSUFFICIENT_BANK
const ERR_INSUFFICIENT_INVENTORY := DopeWarsWorld.DW_ERR_INSUFFICIENT_INVENTORY
const ERR_INSUFFICIENT_SPACE := DopeWarsWorld.DW_ERR_INSUFFICIENT_SPACE
const ERR_GAME_OVER := DopeWarsWorld.DW_ERR_GAME_OVER
const ERR_DEAD := DopeWarsWorld.DW_ERR_DEAD
const ERR_SERIALIZATION_FAILED := DopeWarsWorld.DW_ERR_SERIALIZATION_FAILED

const ARRIVAL_NONE := DopeWarsWorld.DW_ARRIVAL_NONE
const ARRIVAL_MUGGED := DopeWarsWorld.DW_ARRIVAL_MUGGED
const ARRIVAL_FREE_DRUGS := DopeWarsWorld.DW_ARRIVAL_FREE_DRUGS
const ARRIVAL_DOG_CHASE := DopeWarsWorld.DW_ARRIVAL_DOG_CHASE
const ARRIVAL_FOUND_DRUGS := DopeWarsWorld.DW_ARRIVAL_FOUND_DRUGS
const ARRIVAL_MAMAS_BROWNIES := DopeWarsWorld.DW_ARRIVAL_MAMAS_BROWNIES
const ARRIVAL_FREE_WEED_DEATH := DopeWarsWorld.DW_ARRIVAL_FREE_WEED_DEATH
const ARRIVAL_FLAVOR := DopeWarsWorld.DW_ARRIVAL_FLAVOR

const DEALER_NONE := DopeWarsWorld.DW_DEALER_NONE
const DEALER_COAT := DopeWarsWorld.DW_DEALER_COAT
const DEALER_GUN := DopeWarsWorld.DW_DEALER_GUN

const PRICE_EVENT_CHEAP := DopeWarsWorld.DW_PRICE_EVENT_CHEAP
const PRICE_EVENT_EXPENSIVE := DopeWarsWorld.DW_PRICE_EVENT_EXPENSIVE
const PRICE_EVENT_BUST := DopeWarsWorld.DW_PRICE_EVENT_BUST

const FINANCES_DEPOSIT := DopeWarsWorld.DW_FINANCES_DEPOSIT
const FINANCES_WITHDRAW := DopeWarsWorld.DW_FINANCES_WITHDRAW
const FINANCES_PAY_LOAN := DopeWarsWorld.DW_FINANCES_PAY_LOAN

const NUM_LOCATIONS := DopeWarsWorld.DW_NUM_LOCATIONS
const NUM_DRUGS := DopeWarsWorld.DW_NUM_DRUGS
const MAX_HIGHSCORES := DopeWarsWorld.DW_MAX_HIGHSCORES
const ABI_VERSION := DopeWarsWorld.DW_ABI_VERSION

var _world: DopeWarsWorld = DopeWarsWorld.new()


# --- lifecycle --------------------------------------------------------------

func init(rng_seed: int, num_days: int = 0, start_cash: int = -1) -> int:
	return _world.init(rng_seed, num_days, start_cash)


func reset() -> int:
	return _world.reset()


## Shim-only: whether dw_world_init succeeded. Not an ABI function.
func is_ready() -> bool:
	return _world.is_ready()


func abi_version() -> int:
	return _world.abi_version()


# --- live-state queries -----------------------------------------------------


## day, num_days, cash, bank, debt, health, coat_capacity, coat_used, guns,
## location_index, dead, last_day_warned. cash is int32 in the ABI; bank and
## debt are int64 projections of the core's float64.
func state_get() -> Dictionary:
	return _world.state_get()


func coat_used() -> Dictionary:
	return _world.coat_used()


## Array of {drug_index, price, was_event} for the drugs traded here this turn.
func prices_copy() -> Array:
	return _world.prices_copy()


## Same shape as prices_copy, for the previous turn. The two drug sets need
## not match, so intersect on drug_index rather than zipping by position.
func prev_prices_copy() -> Array:
	return _world.prev_prices_copy()


## Array of {drug_index, qty, avg_price_cents}; only slots with qty > 0.
func inventory_copy() -> Array:
	return _world.inventory_copy()


func find_drug_index(id: String) -> Dictionary:
	return _world.find_drug_index(id)


func find_location_index(id: String) -> Dictionary:
	return _world.find_location_index(id)


# --- turn actions -----------------------------------------------------------


func generate_prices() -> int:
	return _world.generate_prices()


## Array of {kind, drug_index}. Does not clear: repeated calls return the same
## events until the next generate_prices.
func price_events_drain() -> Array:
	return _world.price_events_drain()


func buy(drug_index: int, qty: int) -> int:
	return _world.buy(drug_index, qty)


func sell(drug_index: int, qty: int) -> int:
	return _world.sell(drug_index, qty)


func travel(dest_location_index: int) -> int:
	return _world.travel(dest_location_index)


## Returns {result, actual}; `actual` is what the core could actually move,
## which may be less than `amount`.
func finances(action: int, amount: int) -> Dictionary:
	return _world.finances(action, amount)


# --- arrival / dealer events ------------------------------------------------


## The world's state is already mutated by the time this returns. Fields past
## `kind` are only meaningful for the kinds documented on dw_arrival_event in
## include/dopewars.h.
func roll_arrival_event() -> Dictionary:
	return _world.roll_arrival_event()


## Returns {result, kind} with kind one of DEALER_NONE / DEALER_COAT /
## DEALER_GUN. Only call it when should_start_chase came back false -- a
## chase skips the dealers entirely.
func roll_dealer_visit() -> Dictionary:
	return _world.roll_dealer_visit()


func roll_coat_dealer_offer() -> Dictionary:
	return _world.roll_coat_dealer_offer()


func accept_coat_offer(price: int) -> Dictionary:
	return _world.accept_coat_offer(price)


func roll_gun_dealer_offer() -> Dictionary:
	return _world.roll_gun_dealer_offer()


func accept_gun_offer(price: int, name_index: int) -> Dictionary:
	return _world.accept_gun_offer(price, name_index)


# --- chase / combat ---------------------------------------------------------


func should_start_chase() -> Dictionary:
	return _world.should_start_chase()


func start_chase() -> Dictionary:
	return _world.start_chase()


func get_fight_ratings() -> Dictionary:
	return _world.get_fight_ratings()


## `deputies` is the live count from the chase; the core does not track the
## chase, so the caller carries it between calls.
func run_from_chase(deputies: int, is_aggressor: bool) -> Dictionary:
	return _world.run_from_chase(deputies, is_aggressor)


## Returns the remaining deputy count, so the caller can keep passing it back.
func fight(deputies: int) -> Dictionary:
	return _world.fight(deputies)


func apply_damage(amount: int) -> Dictionary:
	return _world.apply_damage(amount)


# --- endgame ----------------------------------------------------------------


## Read-only: safe to call more than once, unlike the JS original which the
## UI guards with a disabled button.
func finish() -> Dictionary:
	return _world.finish()


## `scores` and `entry` are arrays/dicts of {name, score, day, dead}. Returns
## {result, scores, count}, sorted by score descending and truncated to
## MAX_HIGHSCORES. Keys outside that set are dropped, so a caller cannot smuggle
## extra per-row state through here.
func insert_highscore(scores: Array, entry: Dictionary) -> Dictionary:
	return _world.insert_highscore(scores, entry)


# --- persistence ------------------------------------------------------------


func world_dump_len() -> int:
	return _world.world_dump_len()


## Returns {result, bytes}.
func world_dump() -> Dictionary:
	return _world.world_dump()


## A failed load leaves the world unchanged, so a caller can retry or discard.
func world_load(bytes: PackedByteArray) -> int:
	return _world.world_load(bytes)


# --- rule tables ------------------------------------------------------------


## The dw_rules_* accessors are bound as *static* methods on DopeWarsWorld and
## are re-exported here as instance methods on purpose. A GDScript `static func`
## does not appear in the script's get_method_list(), so keeping them static
## would put 18 of the ABI's 54 methods permanently outside the reach of
## godot_tests/bridge_test.gd's completeness check -- the check could then
## never catch a wrapper that quietly stopped forwarding one. Instance methods
## cost nothing here (the wrapper is a RefCounted the game owns anyway) and keep
## the whole surface enumerable from one object.


## Array of {id, name}. Static table, so this
## works without an initialized world.
func rules_locations() -> Array:
	return _world.rules_locations()


## Array of {id, name, min_price, max_price, cheap, expensive}. Static table.
func rules_drugs() -> Array:
	return _world.rules_drugs()


func world_size() -> int:
	return DopeWarsWorld.world_size()


func world_align() -> int:
	return DopeWarsWorld.world_align()


func rules_default_num_days() -> int:
	return DopeWarsWorld.rules_default_num_days()


func rules_default_start_cash() -> int:
	return DopeWarsWorld.rules_default_start_cash()


func rules_default_start_debt() -> int:
	return DopeWarsWorld.rules_default_start_debt()


func rules_default_start_health() -> int:
	return DopeWarsWorld.rules_default_start_health()


func rules_default_start_coat_capacity() -> int:
	return DopeWarsWorld.rules_default_start_coat_capacity()


func rules_default_start_location_index() -> int:
	return DopeWarsWorld.rules_default_start_location_index()


func rules_gun_damage() -> int:
	return DopeWarsWorld.rules_gun_damage()


func rules_player_armor() -> int:
	return DopeWarsWorld.rules_player_armor()


func rules_debt_interest_bp() -> int:
	return DopeWarsWorld.rules_debt_interest_bp()


func rules_bank_interest_bp() -> int:
	return DopeWarsWorld.rules_bank_interest_bp()


func rules_cheap_divide() -> int:
	return DopeWarsWorld.rules_cheap_divide()


func rules_expensive_multiply() -> int:
	return DopeWarsWorld.rules_expensive_multiply()


func rules_locations_len() -> int:
	return DopeWarsWorld.rules_locations_len()


func rules_drugs_len() -> int:
	return DopeWarsWorld.rules_drugs_len()
