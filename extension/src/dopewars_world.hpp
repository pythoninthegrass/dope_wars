#pragma once

// extension/src/dopewars_world.hpp — stub GDExtension class for
// TASK-001.03. Exposes exactly one method: abi_version(), forwarding to
// the Mojo core's dw_abi_version(). No game logic yet.

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

	// Forwards to dw_abi_version() from include/dopewars.h. Real ABI
	// surface (dw_world_init, dw_buy, etc.) lands in TASK-001.04.
	uint32_t abi_version() const;
};

} // namespace godot
