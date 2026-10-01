// extension/src/dopewars_world.cpp — 1:1 forwarding to include/dopewars.h
// (TASK-001.05). No game logic lives here.

#include "dopewars_world.hpp"

#include <cstring>

#include <godot_cpp/core/class_db.hpp>

namespace godot {

namespace {

// Carves a dw_world_align()-aligned pointer out of `buf`, which must be at
// least dw_world_size() + dw_world_align() - 1 bytes long. Assumes
// dw_world_align() returns a power of two, matching every real alignment value
// the C ABI can report.
dw_world *align_world_ptr(std::vector<uint8_t> &buf) {
	size_t align = dw_world_align();
	uintptr_t base = reinterpret_cast<uintptr_t>(buf.data());
	uintptr_t aligned = (base + align - 1) & ~(align - 1);
	return reinterpret_cast<dw_world *>(aligned);
}

void copy_string_to_name(const String &value, char (&out)[DW_MAX_HIGHSCORE_NAME_LEN]) {
	std::memset(out, 0, sizeof(out));
	CharString utf8 = value.utf8();
	int len = utf8.length();
	if (len > static_cast<int>(DW_MAX_HIGHSCORE_NAME_LEN) - 1) {
		len = static_cast<int>(DW_MAX_HIGHSCORE_NAME_LEN) - 1;
	}
	std::memcpy(out, utf8.get_data(), static_cast<size_t>(len));
}

String name_to_string(const char (&name)[DW_MAX_HIGHSCORE_NAME_LEN]) {
	return String::utf8(name, static_cast<int>(strnlen(name, DW_MAX_HIGHSCORE_NAME_LEN)));
}

} // namespace

void DopeWarsWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("init", "rng_seed", "num_days", "start_cash"), &DopeWarsWorld::init, DEFVAL(0), DEFVAL(-1));
	ClassDB::bind_method(D_METHOD("reset"), &DopeWarsWorld::reset);
	ClassDB::bind_method(D_METHOD("is_ready"), &DopeWarsWorld::is_ready);
	ClassDB::bind_method(D_METHOD("abi_version"), &DopeWarsWorld::abi_version);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("world_size"), &DopeWarsWorld::world_size);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("world_align"), &DopeWarsWorld::world_align);

	ClassDB::bind_method(D_METHOD("state_get"), &DopeWarsWorld::state_get);
	ClassDB::bind_method(D_METHOD("coat_used"), &DopeWarsWorld::coat_used);
	ClassDB::bind_method(D_METHOD("prices_copy"), &DopeWarsWorld::prices_copy);
	ClassDB::bind_method(D_METHOD("prev_prices_copy"), &DopeWarsWorld::prev_prices_copy);
	ClassDB::bind_method(D_METHOD("inventory_copy"), &DopeWarsWorld::inventory_copy);
	ClassDB::bind_method(D_METHOD("find_drug_index", "id"), &DopeWarsWorld::find_drug_index);
	ClassDB::bind_method(D_METHOD("find_location_index", "id"), &DopeWarsWorld::find_location_index);

	ClassDB::bind_method(D_METHOD("generate_prices"), &DopeWarsWorld::generate_prices);
	ClassDB::bind_method(D_METHOD("price_events_drain"), &DopeWarsWorld::price_events_drain);
	ClassDB::bind_method(D_METHOD("buy", "drug_index", "qty"), &DopeWarsWorld::buy);
	ClassDB::bind_method(D_METHOD("sell", "drug_index", "qty"), &DopeWarsWorld::sell);
	ClassDB::bind_method(D_METHOD("travel", "dest_location_index"), &DopeWarsWorld::travel);
	ClassDB::bind_method(D_METHOD("finances", "action", "amount"), &DopeWarsWorld::finances);

	ClassDB::bind_method(D_METHOD("roll_arrival_event"), &DopeWarsWorld::roll_arrival_event);
	ClassDB::bind_method(D_METHOD("roll_coat_dealer_offer"), &DopeWarsWorld::roll_coat_dealer_offer);
	ClassDB::bind_method(D_METHOD("accept_coat_offer", "pockets", "price"), &DopeWarsWorld::accept_coat_offer);
	ClassDB::bind_method(D_METHOD("roll_gun_dealer_offer"), &DopeWarsWorld::roll_gun_dealer_offer);
	ClassDB::bind_method(D_METHOD("accept_gun_offer", "price", "damage", "space"), &DopeWarsWorld::accept_gun_offer);
	ClassDB::bind_method(D_METHOD("roll_dealer_visits"), &DopeWarsWorld::roll_dealer_visits);

	ClassDB::bind_method(D_METHOD("should_start_chase"), &DopeWarsWorld::should_start_chase);
	ClassDB::bind_method(D_METHOD("start_chase"), &DopeWarsWorld::start_chase);
	ClassDB::bind_method(D_METHOD("get_fight_ratings"), &DopeWarsWorld::get_fight_ratings);
	ClassDB::bind_method(D_METHOD("run_from_chase", "deputies", "is_aggressor"), &DopeWarsWorld::run_from_chase);
	ClassDB::bind_method(D_METHOD("fight", "deputies"), &DopeWarsWorld::fight);
	ClassDB::bind_method(D_METHOD("apply_damage", "amount"), &DopeWarsWorld::apply_damage);

	ClassDB::bind_method(D_METHOD("finish"), &DopeWarsWorld::finish);
	ClassDB::bind_method(D_METHOD("insert_highscore", "scores", "entry"), &DopeWarsWorld::insert_highscore);

	ClassDB::bind_method(D_METHOD("world_dump_len"), &DopeWarsWorld::world_dump_len);
	ClassDB::bind_method(D_METHOD("world_dump"), &DopeWarsWorld::world_dump);
	ClassDB::bind_method(D_METHOD("world_load", "bytes"), &DopeWarsWorld::world_load);

	ClassDB::bind_method(D_METHOD("rules_locations"), &DopeWarsWorld::rules_locations);
	ClassDB::bind_method(D_METHOD("rules_drugs"), &DopeWarsWorld::rules_drugs);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_default_num_days"), &DopeWarsWorld::rules_default_num_days);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_default_start_cash"), &DopeWarsWorld::rules_default_start_cash);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_default_start_debt"), &DopeWarsWorld::rules_default_start_debt);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_default_start_health"), &DopeWarsWorld::rules_default_start_health);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_default_start_coat_capacity"), &DopeWarsWorld::rules_default_start_coat_capacity);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_default_start_location_index"), &DopeWarsWorld::rules_default_start_location_index);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_gun_damage"), &DopeWarsWorld::rules_gun_damage);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_gun_space"), &DopeWarsWorld::rules_gun_space);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_player_armor"), &DopeWarsWorld::rules_player_armor);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_debt_interest_bp"), &DopeWarsWorld::rules_debt_interest_bp);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_bank_interest_bp"), &DopeWarsWorld::rules_bank_interest_bp);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_bank_purchase_fee_bp"), &DopeWarsWorld::rules_bank_purchase_fee_bp);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_cheap_divide"), &DopeWarsWorld::rules_cheap_divide);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_expensive_multiply"), &DopeWarsWorld::rules_expensive_multiply);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_locations_len"), &DopeWarsWorld::rules_locations_len);
	ClassDB::bind_static_method(get_class_static(), D_METHOD("rules_drugs_len"), &DopeWarsWorld::rules_drugs_len);

	// BIND_CONSTANT, not BIND_ENUM_CONSTANT: these come from dopewars.h's
	// anonymous C enums and #defines, which have no registered Variant enum
	// type for BIND_ENUM_CONSTANT's GetTypeInfo lookup to resolve.
	BIND_CONSTANT(DW_ABI_VERSION);
	BIND_CONSTANT(DW_NUM_LOCATIONS);
	BIND_CONSTANT(DW_NUM_DRUGS);
	BIND_CONSTANT(DW_MAX_HIGHSCORES);

	BIND_CONSTANT(DW_OK);
	BIND_CONSTANT(DW_ERR_INVALID_ARGUMENT);
	BIND_CONSTANT(DW_ERR_BUFFER_TOO_SMALL);
	BIND_CONSTANT(DW_ERR_ABI_VERSION_MISMATCH);
	BIND_CONSTANT(DW_ERR_UNKNOWN_LOCATION);
	BIND_CONSTANT(DW_ERR_UNKNOWN_DRUG);
	BIND_CONSTANT(DW_ERR_NOT_TRADED_HERE);
	BIND_CONSTANT(DW_ERR_INSUFFICIENT_CASH);
	BIND_CONSTANT(DW_ERR_INSUFFICIENT_BANK);
	BIND_CONSTANT(DW_ERR_INSUFFICIENT_INVENTORY);
	BIND_CONSTANT(DW_ERR_INSUFFICIENT_SPACE);
	BIND_CONSTANT(DW_ERR_GAME_OVER);
	BIND_CONSTANT(DW_ERR_DEAD);
	BIND_CONSTANT(DW_ERR_SERIALIZATION_FAILED);

	BIND_CONSTANT(DW_ARRIVAL_NONE);
	BIND_CONSTANT(DW_ARRIVAL_MUGGED);
	BIND_CONSTANT(DW_ARRIVAL_FREE_DRUGS);
	BIND_CONSTANT(DW_ARRIVAL_DOG_CHASE);
	BIND_CONSTANT(DW_ARRIVAL_FOUND_DRUGS);
	BIND_CONSTANT(DW_ARRIVAL_MAMAS_BROWNIES);
	BIND_CONSTANT(DW_ARRIVAL_FREE_WEED_DEATH);
	BIND_CONSTANT(DW_ARRIVAL_FLAVOR);

	BIND_CONSTANT(DW_PRICE_EVENT_CHEAP);
	BIND_CONSTANT(DW_PRICE_EVENT_EXPENSIVE);
	BIND_CONSTANT(DW_PRICE_EVENT_BUST);

	BIND_CONSTANT(DW_FINANCES_DEPOSIT);
	BIND_CONSTANT(DW_FINANCES_WITHDRAW);
	BIND_CONSTANT(DW_FINANCES_PAY_LOAN);
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

void DopeWarsWorld::ensure_storage() {
	if (world_ != nullptr) {
		return;
	}
	size_t align = dw_world_align();
	size_t size = dw_world_size();
	storage_.assign(size + align - 1, 0);
	world_ = align_world_ptr(storage_);
}

int DopeWarsWorld::init(int rng_seed, int num_days, int start_cash) {
	dw_config config{};
	config.abi_version = static_cast<uint16_t>(DW_ABI_VERSION);
	config.rng_seed = static_cast<uint32_t>(rng_seed);
	config.num_days = static_cast<uint32_t>(num_days);
	config.start_cash = static_cast<int32_t>(start_cash);

	ensure_storage();
	dw_result result = dw_world_init(world_, &config);
	ready_ = result == DW_OK;
	return result;
}

int DopeWarsWorld::reset() {
	if (!is_ready()) {
		return DW_ERR_INVALID_ARGUMENT;
	}
	return dw_world_reset(world_);
}

uint32_t DopeWarsWorld::abi_version() const {
	return dw_abi_version();
}

// ---------------------------------------------------------------------------
// Live-state queries
// ---------------------------------------------------------------------------

Dictionary DopeWarsWorld::state_get() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_state_view view{};
	dw_result result = dw_state_get(world_, &view);
	out["result"] = result;
	if (result == DW_OK) {
		out["day"] = view.day;
		out["num_days"] = view.num_days;
		out["cash"] = view.cash;
		out["bank"] = view.bank;
		out["debt"] = view.debt;
		out["health"] = view.health;
		out["coat_capacity"] = view.coat_capacity;
		out["coat_used"] = view.coat_used;
		out["guns"] = view.guns;
		out["location_index"] = view.location_index;
		out["dead"] = view.dead;
		out["last_day_warned"] = view.last_day_warned;
	}
	return out;
}

Dictionary DopeWarsWorld::coat_used() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	int32_t used = 0;
	dw_result result = dw_coat_used(world_, &used);
	out["result"] = result;
	out["used"] = used;
	return out;
}

Array DopeWarsWorld::prices_copy() {
	Array out;
	if (!is_ready()) {
		return out;
	}
	size_t required = 0;
	dw_prices_copy(world_, nullptr, 0, &required);
	std::vector<dw_price_slot> slots(required);
	size_t actual = 0;
	dw_result result = dw_prices_copy(world_, slots.data(), slots.size(), &actual);
	if (result != DW_OK) {
		return out;
	}
	for (size_t i = 0; i < actual; i++) {
		Dictionary entry;
		entry["drug_index"] = slots[i].drug_index;
		entry["price"] = slots[i].price;
		entry["was_event"] = slots[i].was_event;
		out.push_back(entry);
	}
	return out;
}

Array DopeWarsWorld::prev_prices_copy() {
	Array out;
	if (!is_ready()) {
		return out;
	}
	size_t required = 0;
	dw_prev_prices_copy(world_, nullptr, 0, &required);
	std::vector<dw_price_slot> slots(required);
	size_t actual = 0;
	dw_result result = dw_prev_prices_copy(world_, slots.data(), slots.size(), &actual);
	if (result != DW_OK) {
		return out;
	}
	for (size_t i = 0; i < actual; i++) {
		Dictionary entry;
		entry["drug_index"] = slots[i].drug_index;
		entry["price"] = slots[i].price;
		entry["was_event"] = slots[i].was_event;
		out.push_back(entry);
	}
	return out;
}

Array DopeWarsWorld::inventory_copy() {
	Array out;
	if (!is_ready()) {
		return out;
	}
	size_t required = 0;
	dw_inventory_copy(world_, nullptr, 0, &required);
	std::vector<dw_inventory_slot> slots(required);
	size_t actual = 0;
	dw_result result = dw_inventory_copy(world_, slots.data(), slots.size(), &actual);
	if (result != DW_OK) {
		return out;
	}
	for (size_t i = 0; i < actual; i++) {
		Dictionary entry;
		entry["drug_index"] = slots[i].drug_index;
		entry["qty"] = slots[i].qty;
		entry["avg_price_cents"] = slots[i].avg_price_cents;
		out.push_back(entry);
	}
	return out;
}

Dictionary DopeWarsWorld::find_drug_index(const String &id) {
	Dictionary out;
	CharString utf8 = id.utf8();
	uint32_t index = 0;
	dw_result result = dw_find_drug_index(utf8.get_data(), &index);
	out["result"] = result;
	out["index"] = index;
	return out;
}

Dictionary DopeWarsWorld::find_location_index(const String &id) {
	Dictionary out;
	CharString utf8 = id.utf8();
	uint32_t index = 0;
	dw_result result = dw_find_location_index(utf8.get_data(), &index);
	out["result"] = result;
	out["index"] = index;
	return out;
}

// ---------------------------------------------------------------------------
// Turn actions
// ---------------------------------------------------------------------------

int DopeWarsWorld::generate_prices() {
	if (!is_ready()) {
		return DW_ERR_INVALID_ARGUMENT;
	}
	return dw_generate_prices(world_);
}

Array DopeWarsWorld::price_events_drain() {
	Array out;
	if (!is_ready()) {
		return out;
	}
	size_t required = 0;
	dw_price_events_drain(world_, nullptr, 0, &required);
	std::vector<dw_price_event> events(required);
	size_t actual = 0;
	dw_result result = dw_price_events_drain(world_, events.data(), events.size(), &actual);
	if (result != DW_OK) {
		return out;
	}
	for (size_t i = 0; i < actual; i++) {
		Dictionary entry;
		entry["kind"] = events[i].kind;
		entry["drug_index"] = events[i].drug_index;
		out.push_back(entry);
	}
	return out;
}

int DopeWarsWorld::buy(int drug_index, int qty) {
	if (!is_ready()) {
		return DW_ERR_INVALID_ARGUMENT;
	}
	return dw_buy(world_, static_cast<uint32_t>(drug_index), static_cast<uint32_t>(qty));
}

int DopeWarsWorld::sell(int drug_index, int qty) {
	if (!is_ready()) {
		return DW_ERR_INVALID_ARGUMENT;
	}
	return dw_sell(world_, static_cast<uint32_t>(drug_index), static_cast<uint32_t>(qty));
}

int DopeWarsWorld::travel(int dest_location_index) {
	if (!is_ready()) {
		return DW_ERR_INVALID_ARGUMENT;
	}
	return dw_travel(world_, static_cast<uint32_t>(dest_location_index));
}

Dictionary DopeWarsWorld::finances(int action, int64_t amount) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	int64_t actual = 0;
	dw_result result = dw_finances(world_, static_cast<dw_finances_action>(action), amount, &actual);
	out["result"] = result;
	out["actual"] = actual;
	return out;
}

// ---------------------------------------------------------------------------
// Arrival / dealer events
// ---------------------------------------------------------------------------

Dictionary DopeWarsWorld::roll_arrival_event() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_arrival_event event{};
	dw_result result = dw_roll_arrival_event(world_, &event);
	out["result"] = result;
	if (result == DW_OK) {
		out["kind"] = event.kind;
		out["drug_index"] = event.drug_index;
		out["qty"] = event.qty;
		out["amount"] = event.amount;
		out["damage"] = event.damage;
	}
	return out;
}

Dictionary DopeWarsWorld::roll_coat_dealer_offer() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_coat_offer offer{};
	dw_result result = dw_roll_coat_dealer_offer(world_, &offer);
	out["result"] = result;
	out["pockets"] = offer.pockets;
	out["price"] = offer.price;
	return out;
}

Dictionary DopeWarsWorld::accept_coat_offer(int pockets, int price) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_coat_offer offer{};
	offer.pockets = static_cast<uint32_t>(pockets);
	offer.price = static_cast<int32_t>(price);
	dw_purchase_result purchase{};
	dw_result result = dw_accept_coat_offer(world_, &offer, &purchase);
	out["result"] = result;
	out["used_bank"] = purchase.used_bank;
	out["fee"] = purchase.fee;
	return out;
}

Dictionary DopeWarsWorld::roll_gun_dealer_offer() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_gun_offer offer{};
	dw_result result = dw_roll_gun_dealer_offer(world_, &offer);
	out["result"] = result;
	out["price"] = offer.price;
	out["damage"] = offer.damage;
	out["space"] = offer.space;
	return out;
}

Dictionary DopeWarsWorld::accept_gun_offer(int price, int damage, int space) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_gun_offer offer{};
	offer.price = static_cast<int32_t>(price);
	offer.damage = static_cast<uint32_t>(damage);
	offer.space = static_cast<uint32_t>(space);
	dw_purchase_result purchase{};
	dw_result result = dw_accept_gun_offer(world_, &offer, &purchase);
	out["result"] = result;
	out["used_bank"] = purchase.used_bank;
	out["fee"] = purchase.fee;
	return out;
}

Dictionary DopeWarsWorld::roll_dealer_visits() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		out["coat_visit"] = 0;
		out["gun_visit"] = 0;
		return out;
	}
	uint8_t coat_visit = 0;
	uint8_t gun_visit = 0;
	dw_result result = dw_roll_dealer_visits(world_, &coat_visit, &gun_visit);
	out["result"] = result;
	out["coat_visit"] = coat_visit;
	out["gun_visit"] = gun_visit;
	return out;
}

// ---------------------------------------------------------------------------
// Chase / combat
// ---------------------------------------------------------------------------

Dictionary DopeWarsWorld::should_start_chase() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	uint8_t should = 0;
	dw_result result = dw_should_start_chase(world_, &should);
	out["result"] = result;
	out["should_start"] = should;
	return out;
}

Dictionary DopeWarsWorld::start_chase() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_chase chase{};
	dw_result result = dw_start_chase(world_, &chase);
	out["result"] = result;
	out["deputies"] = chase.deputies;
	out["can_fight"] = chase.can_fight;
	return out;
}

Dictionary DopeWarsWorld::get_fight_ratings() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_fight_ratings ratings{};
	dw_result result = dw_get_fight_ratings(world_, &ratings);
	out["result"] = result;
	out["attack"] = ratings.attack;
	out["defend"] = ratings.defend;
	return out;
}

Dictionary DopeWarsWorld::run_from_chase(int deputies, bool is_aggressor) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_chase chase{};
	chase.deputies = static_cast<uint32_t>(deputies);
	dw_run_result run{};
	dw_result result = dw_run_from_chase(world_, &chase, is_aggressor ? 1 : 0, &run);
	out["result"] = result;
	out["escaped"] = run.escaped;
	out["damage_taken"] = run.damage_taken;
	return out;
}

Dictionary DopeWarsWorld::fight(int deputies) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_chase chase{};
	chase.deputies = static_cast<uint32_t>(deputies);
	dw_fight_result fight_result{};
	dw_result result = dw_fight(world_, &chase, &fight_result);
	out["result"] = result;
	out["hit"] = fight_result.hit;
	out["dead"] = fight_result.dead;
	out["won"] = fight_result.won;
	out["damage_taken"] = fight_result.damage_taken;
	out["deputies"] = chase.deputies;
	return out;
}

Dictionary DopeWarsWorld::apply_damage(int amount) {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	int32_t health = 0;
	dw_result result = dw_apply_damage(world_, static_cast<int32_t>(amount), &health);
	out["result"] = result;
	out["health"] = health;
	return out;
}

// ---------------------------------------------------------------------------
// Endgame
// ---------------------------------------------------------------------------

Dictionary DopeWarsWorld::finish() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	dw_finish_result finish_result{};
	dw_result result = dw_finish(world_, &finish_result);
	out["result"] = result;
	out["score"] = finish_result.score;
	out["day"] = finish_result.day;
	out["dead"] = finish_result.dead;
	return out;
}

Dictionary DopeWarsWorld::insert_highscore(const Array &scores, const Dictionary &entry) {
	Dictionary out;
	std::vector<dw_highscore_entry> entries(DW_MAX_HIGHSCORES);
	size_t in_count = 0;
	for (int i = 0; i < scores.size() && in_count < DW_MAX_HIGHSCORES; i++) {
		Dictionary existing = scores[i];
		dw_highscore_entry e{};
		copy_string_to_name(existing.get("name", ""), e.name);
		e.score = static_cast<int64_t>(existing.get("score", 0));
		e.day = static_cast<uint32_t>(existing.get("day", 0));
		e.dead = existing.get("dead", false) ? 1 : 0;
		entries[in_count] = e;
		in_count++;
	}

	dw_highscore_entry new_entry{};
	copy_string_to_name(entry.get("name", ""), new_entry.name);
	new_entry.score = static_cast<int64_t>(entry.get("score", 0));
	new_entry.day = static_cast<uint32_t>(entry.get("day", 0));
	new_entry.dead = entry.get("dead", false) ? 1 : 0;

	size_t out_count = 0;
	dw_result result = dw_insert_highscore(entries.data(), entries.size(), in_count, &new_entry, &out_count);
	out["result"] = result;
	if (result == DW_OK) {
		Array out_scores;
		for (size_t i = 0; i < out_count; i++) {
			Dictionary e;
			e["name"] = name_to_string(entries[i].name);
			e["score"] = entries[i].score;
			e["day"] = entries[i].day;
			e["dead"] = entries[i].dead;
			out_scores.push_back(e);
		}
		out["scores"] = out_scores;
		out["count"] = static_cast<int>(out_count);
	}
	return out;
}

// ---------------------------------------------------------------------------
// Serialization
// ---------------------------------------------------------------------------

int DopeWarsWorld::world_dump_len() {
	return static_cast<int>(dw_world_dump_len());
}

Dictionary DopeWarsWorld::world_dump() {
	Dictionary out;
	if (!is_ready()) {
		out["result"] = DW_ERR_INVALID_ARGUMENT;
		return out;
	}
	size_t len = dw_world_dump_len();
	std::vector<uint8_t> buf(len);
	size_t written = 0;
	dw_result result = dw_world_dump(world_, buf.data(), buf.size(), &written);
	out["result"] = result;
	if (result == DW_OK) {
		PackedByteArray bytes;
		bytes.resize(static_cast<int>(written));
		std::memcpy(bytes.ptrw(), buf.data(), written);
		out["bytes"] = bytes;
	}
	return out;
}

int DopeWarsWorld::world_load(const PackedByteArray &bytes) {
	// Deliberately not gated on is_ready(): dw_world_load rehydrates in place
	// from the payload alone, and the caller restoring a save is holding a
	// brand-new handle that has never been initialized. Gating here made
	// "resume on boot" impossible -- every fresh process refused its own save.
	//
	// A rejected load must not clear ready_ either: the header promises "on
	// failure, world state is unchanged" and the core honors it, so a handle
	// that already held a world keeps holding it. ready_ therefore only ever
	// transitions false -> true here, which is what lets a fresh handle that
	// never held a world stay refused after a corrupt save.
	ensure_storage();
	dw_result result = dw_world_load(world_, bytes.ptr(), static_cast<size_t>(bytes.size()));
	if (result == DW_OK) {
		ready_ = true;
	}
	return result;
}

// ---------------------------------------------------------------------------
// Rules
// ---------------------------------------------------------------------------

Array DopeWarsWorld::rules_locations() {
	Array out;
	size_t required = 0;
	dw_rules_locations_copy(nullptr, 0, &required);
	std::vector<dw_location_view> locations(required);
	size_t actual = 0;
	dw_result result = dw_rules_locations_copy(locations.data(), locations.size(), &actual);
	if (result != DW_OK) {
		return out;
	}
	for (size_t i = 0; i < actual; i++) {
		Dictionary entry;
		entry["id"] = String::utf8(locations[i].id, static_cast<int>(strnlen(locations[i].id, DW_MAX_LOCATION_ID_LEN)));
		entry["name"] = String::utf8(locations[i].name, static_cast<int>(strnlen(locations[i].name, DW_MAX_LOCATION_NAME_LEN)));
		entry["police"] = locations[i].police;
		out.push_back(entry);
	}
	return out;
}

Array DopeWarsWorld::rules_drugs() {
	Array out;
	size_t required = 0;
	dw_rules_drugs_copy(nullptr, 0, &required);
	std::vector<dw_drug_view> drugs(required);
	size_t actual = 0;
	dw_result result = dw_rules_drugs_copy(drugs.data(), drugs.size(), &actual);
	if (result != DW_OK) {
		return out;
	}
	for (size_t i = 0; i < actual; i++) {
		Dictionary entry;
		entry["id"] = String::utf8(drugs[i].id, static_cast<int>(strnlen(drugs[i].id, DW_MAX_DRUG_ID_LEN)));
		entry["name"] = String::utf8(drugs[i].name, static_cast<int>(strnlen(drugs[i].name, DW_MAX_DRUG_NAME_LEN)));
		entry["min_price"] = drugs[i].min_price;
		entry["max_price"] = drugs[i].max_price;
		entry["cheap"] = drugs[i].cheap;
		entry["expensive"] = drugs[i].expensive;
		out.push_back(entry);
	}
	return out;
}

int DopeWarsWorld::rules_default_num_days() {
	return static_cast<int>(dw_rules_default_num_days());
}

int DopeWarsWorld::rules_default_start_cash() {
	return dw_rules_default_start_cash();
}

int64_t DopeWarsWorld::rules_default_start_debt() {
	return dw_rules_default_start_debt();
}

int DopeWarsWorld::rules_default_start_health() {
	return dw_rules_default_start_health();
}

int DopeWarsWorld::rules_default_start_coat_capacity() {
	return dw_rules_default_start_coat_capacity();
}

int DopeWarsWorld::rules_default_start_location_index() {
	return dw_rules_default_start_location_index();
}

int DopeWarsWorld::rules_gun_damage() {
	return static_cast<int>(dw_rules_gun_damage());
}

int DopeWarsWorld::rules_gun_space() {
	return static_cast<int>(dw_rules_gun_space());
}

int DopeWarsWorld::rules_player_armor() {
	return static_cast<int>(dw_rules_player_armor());
}

int DopeWarsWorld::rules_debt_interest_bp() {
	return static_cast<int>(dw_rules_debt_interest_bp());
}

int DopeWarsWorld::rules_bank_interest_bp() {
	return static_cast<int>(dw_rules_bank_interest_bp());
}

int DopeWarsWorld::rules_bank_purchase_fee_bp() {
	return static_cast<int>(dw_rules_bank_purchase_fee_bp());
}

int DopeWarsWorld::rules_cheap_divide() {
	return static_cast<int>(dw_rules_cheap_divide());
}

int DopeWarsWorld::rules_expensive_multiply() {
	return static_cast<int>(dw_rules_expensive_multiply());
}

int64_t DopeWarsWorld::rules_locations_len() {
	return static_cast<int64_t>(dw_rules_locations_len());
}

int64_t DopeWarsWorld::rules_drugs_len() {
	return static_cast<int64_t>(dw_rules_drugs_len());
}

int64_t DopeWarsWorld::world_size() {
	return static_cast<int64_t>(dw_world_size());
}

int64_t DopeWarsWorld::world_align() {
	return static_cast<int64_t>(dw_world_align());
}

} // namespace godot
