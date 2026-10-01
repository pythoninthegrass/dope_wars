#pragma once

// extension/src/dopewars_world.hpp — the GDExtension shim over
// include/dopewars.h (TASK-001.05).
//
// Every method here forwards to exactly one dw_* call; no simulation logic is
// reimplemented. core/src/ (via core/src/abi.mojo) remains the only place game
// rules live. Structured results come back as Dictionaries so GDScript never
// sees a raw ABI struct.
//
// Modeled on ~/git/jumpnbump/extension/src/jumpnbump_world.hpp.

#include <cstdint>
#include <vector>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

#include "dopewars.h"

namespace godot {

class DopeWarsWorld : public RefCounted {
	GDCLASS(DopeWarsWorld, RefCounted)

protected:
	static void _bind_methods();

public:
	DopeWarsWorld() = default;
	~DopeWarsWorld() override = default;

	// Lifecycle
	int init(int rng_seed, int num_days = 0, int start_cash = -1);
	int reset();
	// True once a world has been written into `world_`, by either init or
	// load. Not "storage has been allocated": a failed init leaves allocated
	// storage holding no world, and every other method must still refuse.
	bool is_ready() const { return ready_; }

	// The linked core's DW_ABI_VERSION, for a binding to assert at runtime.
	uint32_t abi_version() const;

	// Size/alignment of the opaque dw_world, straight from the linked core.
	static int64_t world_size();
	static int64_t world_align();

	// Live-state queries
	Dictionary state_get();
	Dictionary coat_used();
	Array prices_copy();
	Array prev_prices_copy();
	Array inventory_copy();
	Dictionary find_drug_index(const String &id);
	Dictionary find_location_index(const String &id);

	// Turn actions
	int generate_prices();
	Array price_events_drain();
	int buy(int drug_index, int qty);
	int sell(int drug_index, int qty);
	int travel(int dest_location_index);
	Dictionary finances(int action, int64_t amount);

	// Arrival / dealer events
	Dictionary roll_arrival_event();
	Dictionary roll_dealer_visit();
	Dictionary roll_coat_dealer_offer();
	Dictionary accept_coat_offer(int price);
	Dictionary roll_gun_dealer_offer();
	Dictionary accept_gun_offer(int price, int name_index);

	// Chase / combat
	Dictionary should_start_chase();
	Dictionary start_chase();
	Dictionary get_fight_ratings();
	Dictionary run_from_chase(int deputies, bool is_aggressor);
	Dictionary fight(int deputies);
	Dictionary apply_damage(int amount);

	// Endgame
	Dictionary finish();
	Dictionary insert_highscore(const Array &scores, const Dictionary &entry);

	// Serialization
	int world_dump_len();
	Dictionary world_dump();
	int world_load(const PackedByteArray &bytes);

	// Rules
	Array rules_locations();
	Array rules_drugs();
	static int rules_default_num_days();
	static int rules_default_start_cash();
	static int64_t rules_default_start_debt();
	static int rules_default_start_health();
	static int rules_default_start_coat_capacity();
	static int rules_default_start_location_index();
	static int rules_gun_damage();
	static int rules_player_armor();
	static int rules_debt_interest_bp();
	static int rules_bank_interest_bp();
	static int rules_cheap_divide();
	static int rules_expensive_multiply();
	static int64_t rules_locations_len();
	static int64_t rules_drugs_len();

private:
	// Allocates the over-allocated backing store and points `world_` at the
	// aligned dw_world inside it, without initializing a world. Idempotent.
	// dw_world_load writes a world wholesale, so it needs storage to write
	// into but no prior dw_world_init -- that is the "a fresh process resumes
	// a save" path, which is the whole point of a save file.
	void ensure_storage();

	// storage_ is over-allocated by dw_world_align() - 1 bytes so an aligned
	// dw_world* can be carved out of it manually; std::vector's own default
	// alignment is not guaranteed to satisfy whatever dw_world_align() reports.
	std::vector<uint8_t> storage_;
	dw_world *world_ = nullptr;
	bool ready_ = false;
};

} // namespace godot
