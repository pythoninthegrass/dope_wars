// extension/src/dopewars_world.cpp — stub implementation (TASK-001.03).

#include "dopewars_world.hpp"

#include <godot_cpp/core/class_db.hpp>

// TASK-001.03 stub-stage bring-up symbol. Not part of the frozen ABI in
// include/dopewars.h (C consumers read DW_ABI_VERSION as a #define).
// Declared here so the shim can prove end-to-end Mojo -> C -> C++ ->
// GDScript wiring works. The declaration will move into
// include/dopewars.h if we decide to keep it, or it will be deleted
// once TASK-001.04 lands a richer ABI surface to bring-up-test against.
extern "C" uint32_t dw_abi_version(void);

namespace godot {

void DopeWarsWorld::_bind_methods() {
	ClassDB::bind_method(D_METHOD("abi_version"), &DopeWarsWorld::abi_version);

	// BIND_CONSTANT (not BIND_ENUM_CONSTANT): DW_ABI_VERSION is a #define,
	// not an enum member.
	BIND_CONSTANT(DW_ABI_VERSION);
}

uint32_t DopeWarsWorld::abi_version() const {
	return dw_abi_version();
}

} // namespace godot
