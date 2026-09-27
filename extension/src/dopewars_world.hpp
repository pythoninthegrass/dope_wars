#pragma once

// extension/src/dopewars_world.hpp — GDExtension shim.
//
// TASK-001.03 brought up one forwarded method (abi_version) to prove the
// Godot -> C++ -> C ABI -> Mojo path links at all. TASK-001.05 widens it to
// cover the whole *currently exported* ABI surface, because a single
// void->uint32 hop proves nothing about the parts of the bridge that do fail:
// signed vs unsigned 32-bit, the 64-bit money types, and size_t. Each of those
// can truncate or re-sign silently while abi_version() still returns 1.
//
// Boundary (docs/layer-boundaries.md): this class forwards 1:1 and holds no
// state. It computes no rules and caches nothing from the core.

#include <godot_cpp/classes/ref_counted.hpp>

#include "dopewars.h"

namespace godot {

class DopeWarsWorld : public RefCounted {
	GDCLASS(DopeWarsWorld, RefCounted)

protected:
	static void _bind_methods();

public:
	DopeWarsWorld() = default;
	~DopeWarsWorld() override = default;

	// --- ABI identity ------------------------------------------------------

	// Forwards to dw_abi_version().
	uint32_t abi_version() const;

	// --- RULES constants: the pointer-free ABI surface ---------------------
	//
	// Named without the dw_rules_ prefix: in GDScript these read as properties
	// of a rules object, and the prefix carries no meaning once the class name
	// already says where they come from. The mapping is mechanical and
	// documented in the .cpp so a reviewer can check it against the header one
	// column at a time.

	uint32_t rules_default_num_days() const;
	int32_t rules_default_start_cash() const;
	int64_t rules_default_start_debt() const;
	int32_t rules_default_start_health() const;
	int32_t rules_default_start_coat_capacity() const;
	int32_t rules_default_start_location_index() const;
	uint32_t rules_gun_damage() const;
	uint32_t rules_gun_space() const;
	uint32_t rules_player_armor() const;
	uint32_t rules_debt_interest_bp() const;
	uint32_t rules_bank_interest_bp() const;
	uint32_t rules_bank_purchase_fee_bp() const;
	uint32_t rules_cheap_divide() const;
	uint32_t rules_expensive_multiply() const;
	uint32_t rules_locations_len() const;
	uint32_t rules_drugs_len() const;

	// size_t on purpose: Godot binds int64_t as `int`, and GDScript integers are
	// 64-bit signed, so a size_t here arrives intact on every platform this
	// project builds for. Documented because it is the one place the shim's C++
	// signature and the GDScript-side `int` typing need a note.
	uint64_t world_align() const;
	uint64_t world_dump_len() const;
};

} // namespace godot
