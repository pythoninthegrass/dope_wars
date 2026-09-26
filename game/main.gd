# game/main.gd - TASK-001.03 smoke test.
#
# On _ready() the scene instantiates the GDExtension-provided
# DopeWarsWorld class, calls its abi_version() method, verifies the
# returned value matches the expected DW_ABI_VERSION constant, and
# quits with exit code 0 on success or 1 on any mismatch. This is the
# artifact `task check` runs to prove the whole Mojo -> C -> C++ ->
# GDScript pipeline works end-to-end.
extends Node


func _ready() -> void:
	var world := DopeWarsWorld.new()
	var version: int = world.abi_version()
	var expected: int = DopeWarsWorld.DW_ABI_VERSION

	if version != expected:
		push_error("dw_abi_version() returned %d, expected %d" % [version, expected])
		get_tree().quit(1)
		return

	print("dopewars smoke test OK: dw_abi_version() == %d" % version)
	get_tree().quit(0)
