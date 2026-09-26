// extension/src/dopewars_world.cpp — GDExtension shim implementation.
//
// 1:1 forwarding from Godot methods to the C ABI declared in
// include/dopewars.h, which this file reaches through dopewars_world.hpp.
//
// There is deliberately no `extern "C"` redeclaration of any dw_* symbol here
// (an earlier TASK-001.03 bring-up stub had one). A hand-written prototype in
// the shim is the exact drift the export-surface gate (tools/check_abi_exports.py)
// exists to catch: it lets the shim keep compiling against a signature the
// library no longer exports, so the mismatch moves to link time or, worse, to a
// silent mis-cast. Compiling this file against the header means the header is
// the only place a signature exists.
//
// No game logic, no state, no caching. See docs/layer-boundaries.md.

#include "dopewars_world.hpp"

#include <godot_cpp/core/class_db.hpp>

#include <functional>
#include <type_traits>

namespace godot {

// The forwarding table. Each row binds a GDScript-visible name to the ABI
// function of the same meaning, so the whole bridge surface is reviewable as a
// list against include/dopewars.h rather than as 19 separate function bodies.
//
// Column 3 is the C return type; the C++ method's return type must match it
// exactly (see the static asserts below, which make that structural rather than
// a matter of care).
#define DW_FORWARD(gd_name, abi_fn, c_ret) \
	c_ret DopeWarsWorld::gd_name() const { return abi_fn(); }

	DW_FORWARD(abi_version, dw_abi_version, uint32_t)

	DW_FORWARD(rules_default_num_days, dw_rules_default_num_days, uint32_t)
	DW_FORWARD(rules_default_start_cash, dw_rules_default_start_cash, int32_t)
	DW_FORWARD(rules_default_start_debt, dw_rules_default_start_debt, int64_t)
	DW_FORWARD(rules_default_start_health, dw_rules_default_start_health, int32_t)
	DW_FORWARD(rules_default_start_coat_capacity, dw_rules_default_start_coat_capacity, int32_t)
	DW_FORWARD(rules_default_start_location_index, dw_rules_default_start_location_index, int32_t)
	DW_FORWARD(rules_gun_damage, dw_rules_gun_damage, uint32_t)
	DW_FORWARD(rules_gun_space, dw_rules_gun_space, uint32_t)
	DW_FORWARD(rules_player_armor, dw_rules_player_armor, uint32_t)
	DW_FORWARD(rules_debt_interest_bp, dw_rules_debt_interest_bp, uint32_t)
	DW_FORWARD(rules_bank_interest_bp, dw_rules_bank_interest_bp, uint32_t)
	DW_FORWARD(rules_bank_purchase_fee_bp, dw_rules_bank_purchase_fee_bp, uint32_t)
	DW_FORWARD(rules_cheap_divide, dw_rules_cheap_divide, uint32_t)
	DW_FORWARD(rules_expensive_multiply, dw_rules_expensive_multiply, uint32_t)
	DW_FORWARD(rules_locations_len, dw_rules_locations_len, uint32_t)
	DW_FORWARD(rules_drugs_len, dw_rules_drugs_len, uint32_t)

	// size_t -> uint64_t is the one widening in the table. It is safe in both
	// directions for these two values (an alignment and a dump length, both far
	// below 2^31) and is what lets GDScript's 64-bit int hold them without a
	// cast on the caller side.
	DW_FORWARD(world_align, dw_world_align, size_t)
	DW_FORWARD(world_dump_len, dw_world_dump_len, size_t)

#undef DW_FORWARD

	// The header's declarations are the contract for what the ABI returns, and
	// the class declares its own return types. If the two ever disagree — a
	// dw_rules_* changing from int32_t to uint32_t, say — the macro above would
	// still compile by implicitly converting, and the shim would silently
	// re-sign the value on the way to GDScript. Asserting the types are
	// identical turns that into a compile error at the point of drift.
	static_assert(std::is_same_v<decltype(dw_abi_version()), uint32_t>);
	static_assert(std::is_same_v<decltype(dw_rules_default_start_debt()), int64_t>);
	static_assert(std::is_same_v<decltype(dw_rules_default_start_cash()), int32_t>);
	static_assert(std::is_same_v<decltype(dw_rules_locations_len()), uint32_t>);
	static_assert(std::is_same_v<decltype(dw_world_align()), size_t>);
	static_assert(std::is_same_v<decltype(dw_world_dump_len()), size_t>);

	// And the shim's own methods must agree with the header, which is what makes
	// the forwarding table's third column checked rather than decorative.
	static_assert(std::is_same_v<decltype(std::declval<const DopeWarsWorld &>().rules_default_start_debt()), int64_t>);
	static_assert(std::is_same_v<decltype(std::declval<const DopeWarsWorld &>().world_align()), uint64_t>);

	void DopeWarsWorld::_bind_methods() {
		// Method names are bound verbatim so the GDScript-side name is the same
		// string a reviewer greps for in the header (minus the dw_rules_ prefix).
		ClassDB::bind_method(D_METHOD("abi_version"), &DopeWarsWorld::abi_version);

		ClassDB::bind_method(D_METHOD("rules_default_num_days"), &DopeWarsWorld::rules_default_num_days);
		ClassDB::bind_method(D_METHOD("rules_default_start_cash"), &DopeWarsWorld::rules_default_start_cash);
		ClassDB::bind_method(D_METHOD("rules_default_start_debt"), &DopeWarsWorld::rules_default_start_debt);
		ClassDB::bind_method(D_METHOD("rules_default_start_health"), &DopeWarsWorld::rules_default_start_health);
		ClassDB::bind_method(
			D_METHOD("rules_default_start_coat_capacity"), &DopeWarsWorld::rules_default_start_coat_capacity
		);
		ClassDB::bind_method(
			D_METHOD("rules_default_start_location_index"), &DopeWarsWorld::rules_default_start_location_index
		);
		ClassDB::bind_method(D_METHOD("rules_gun_damage"), &DopeWarsWorld::rules_gun_damage);
		ClassDB::bind_method(D_METHOD("rules_gun_space"), &DopeWarsWorld::rules_gun_space);
		ClassDB::bind_method(D_METHOD("rules_player_armor"), &DopeWarsWorld::rules_player_armor);
		ClassDB::bind_method(D_METHOD("rules_debt_interest_bp"), &DopeWarsWorld::rules_debt_interest_bp);
		ClassDB::bind_method(D_METHOD("rules_bank_interest_bp"), &DopeWarsWorld::rules_bank_interest_bp);
		ClassDB::bind_method(
			D_METHOD("rules_bank_purchase_fee_bp"), &DopeWarsWorld::rules_bank_purchase_fee_bp
		);
		ClassDB::bind_method(D_METHOD("rules_cheap_divide"), &DopeWarsWorld::rules_cheap_divide);
		ClassDB::bind_method(D_METHOD("rules_expensive_multiply"), &DopeWarsWorld::rules_expensive_multiply);
		ClassDB::bind_method(D_METHOD("rules_locations_len"), &DopeWarsWorld::rules_locations_len);
		ClassDB::bind_method(D_METHOD("rules_drugs_len"), &DopeWarsWorld::rules_drugs_len);

		ClassDB::bind_method(D_METHOD("world_align"), &DopeWarsWorld::world_align);
		ClassDB::bind_method(D_METHOD("world_dump_len"), &DopeWarsWorld::world_dump_len);

		// BIND_CONSTANT (not BIND_ENUM_CONSTANT): DW_ABI_VERSION is a #define,
		// not an enum member. Exposed so GDScript asserts against the header's
		// value rather than a GDScript-side copy that could drift.
		BIND_CONSTANT(DW_ABI_VERSION);
	}

} // namespace godot
