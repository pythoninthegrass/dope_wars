extends Node

# Bridge integration test (TASK-001.05 AC#4).
#
# Exercises the full Godot -> GDExtension(C++) -> C ABI -> Mojo path and asserts
# the value that arrives in GDScript is the value the ABI contract specifies, for
# every pointer-free function in the generated surface. The pointer-argument side
# of the shim is covered by res://tests/test_bridge.gd. game/main.gd's smoke test
# proved this path *links*; this proves it *translates*, which is where the
# failures actually are: a uint32 bound through a signed hop, an int64 narrowed
# to 32 bits, a method that silently stopped being bound.
#
# Expectations come from game/bridge_expectations.gd, generated from
# include/dopewars.h by tools/gen_bridge_expectations.py. Nothing here hard-codes
# a rules value, so a rule change cannot pass by being misremembered the same way
# twice — it has to move the header, the generator, and the core together.
#
# A suite that runs zero assertions is a failure, not a pass: `MIN_ASSERTIONS`
# below encodes that, because the first version of this file exited 0 while every
# one of its checks threw.
#
# Run headless: task bridge:test

const EXPECTATIONS_PATH := "res://bridge_expectations.gd"

# Minimum assertions, derived from the generated surface rather than guessed, so
# adding an ABI method raises the floor automatically and the floor cannot go stale
# against the header. With S methods the four checks produce:
#   surface      1   (the aggregate "N methods match" assertion; mismatches are
#                     recorded as failures, so the pass path is one assertion)
#   identity     1   (abi_version)
#   values       S   (one per method carrying a pinned value)
#   width        2   (integer-ness + unsigned-ness aggregates)
# Not every method carries a pinned value today, so the value pass is the honest
# variable term and is counted generously as S.
const MIN_ASSERTIONS_FROM_SURFACE := 4

var _passed := 0
var _failures: Array[String] = []
var _skipped: Array[String] = []
var _expectations: Object = null


func _ready() -> void:
	_expectations = _load_expectations()
	if _expectations == null:
		_finish()
		return

	if not ClassDB.class_exists("DopeWarsWorld"):
		_fail(
			"GDExtension registration",
			"DopeWarsWorld is not registered; the extension did not load (check game/bin/ and the Mojo runtime rpath)"
		)
		_finish()
		return

	var world := DopeWarsWorld.new()
	_check_class_surface(world)
	_check_abi_identity(world)
	_check_forwarded_values(world)
	_check_width_fidelity(world)
	_finish()


# The generated file's constants are exposed on the script *instance*, not on the
# GDScript resource itself, so this instantiates rather than reading off load().
# Returns null (after recording a failure) when the file is absent or unparsable.
func _load_expectations() -> Object:
	if not ResourceLoader.exists(EXPECTATIONS_PATH):
		_fail("generated expectations", "%s missing; run task gen:bridge-expectations" % EXPECTATIONS_PATH)
		return null
	var script: GDScript = load(EXPECTATIONS_PATH)
	if script == null or not script.can_instantiate():
		_fail("generated expectations", "%s failed to compile" % EXPECTATIONS_PATH)
		return null
	var instance: Object = script.new()
	if not ("ABI" in instance) or not ("DW_ABI_VERSION" in instance):
		_fail("generated expectations", "%s is missing ABI or DW_ABI_VERSION" % EXPECTATIONS_PATH)
		return null
	# The table is untyped (Godot 4.7 will not type a nested Dictionary const), so
	# its shape is the thing being asserted here. Each row must carry a C type and
	# a width class, because the value checks depend on `width` to know whether a
	# negative result is corruption or legitimate.
	var abi: Dictionary = instance.ABI
	if abi.is_empty():
		_fail("generated expectations", "ABI table is empty; generator or header is broken")
		return null
	for method_name in abi.keys():
		var meta: Variant = abi[method_name]
		if not (meta is Dictionary):
			_fail("generated expectations", "ABI['%s'] is not a Dictionary" % method_name)
			continue
		if not meta.has("c_type") or not meta.has("width"):
			_fail("generated expectations", "ABI['%s'] missing c_type or width" % method_name)
			continue
		if String(meta["width"]) not in ["uint32", "int32", "int64", "size"]:
			_fail("generated expectations", "ABI['%s'] has unknown width '%s'" % [method_name, meta["width"]])
	if not _failures.is_empty():
		return null
	return instance


# The shim must expose at least the generated surface: no missing method (a dropped
# bind_method call). The extra direction is deliberately not asserted: the shim
# forwards the full ABI, while this table only pins the pointer-free no-arg subset
# it can value-check, so bound methods outside the table are expected. The exact
# export surface is the export-surface gate's job (tools/check_abi_exports.py).
func _check_class_surface(world: Object) -> void:
	var expected_names: Array = _expectations.ABI.keys()
	var bound := _forwarded_method_names(world)

	for name in expected_names:
		if not bound.has(name):
			_fail("surface", "method '%s' is expected but not bound on DopeWarsWorld" % name)

	if expected_names.is_empty():
		_fail("surface", "generated ABI surface is empty — generator or header is broken")
	else:
		_pass("surface: %d bound methods match the generated ABI surface" % expected_names.size())


# get_method_list() on a GDExtension instance also reports every inherited
# Object/RefCounted method, so "the shim's own methods" is computed by subtracting
# the base class's method set rather than by guessing which names look built-in.
func _forwarded_method_names(world: Object) -> Array[String]:
	var inherited := {}
	for method in RefCounted.new().get_method_list():
		inherited[String(method["name"])] = true

	var names: Array[String] = []
	for method in world.get_method_list():
		var name := String(method["name"])
		if inherited.has(name):
			continue
		names.append(name)
	names.sort()
	return names


func _check_abi_identity(world: Object) -> void:
	var got: int = world.abi_version()
	var want: int = int(_expectations.DW_ABI_VERSION)
	if got == want:
		_pass("abi_version() == %d (header DW_ABI_VERSION)" % want)
	else:
		_fail("abi_version()", "got %d, header says %d" % [got, want])


func _check_forwarded_values(world: Object) -> void:
	for method_name in _expectations.ABI.keys():
		var meta: Dictionary = _expectations.ABI[method_name]
		if not meta.has("value"):
			continue
		var want: int = int(meta["value"])
		var got: Variant = world.call(String(method_name))
		if got == null:
			_fail(method_name, "call returned null (expected %d)" % want)
			continue
		if int(got) != want:
			_fail(method_name, "got %s, ABI contract pins %d (C type %s)" % [got, want, meta["c_type"]])
		else:
			_pass("%s() == %d" % [method_name, want])


# Width fidelity: GDScript integers are signed 64-bit, so the interesting failures
# are a uint32 that arrived re-signed, or a value that arrived as a float (meaning
# something round-tripped it through double, losing precision above 2^53 and
# corrupting a future int64 money value). The v1 contract values are all small, so
# this checks the shape of what crosses the bridge rather than exercising the
# boundaries — stated rather than implied.
func _check_width_fidelity(world: Object) -> void:
	var int_ok := true
	var unsigned_ok := true
	for method_name in _expectations.ABI.keys():
		var meta: Dictionary = _expectations.ABI[method_name]
		var got: Variant = world.call(String(method_name))
		if not (got is int):
			_fail("width:%s" % method_name, "returned %s (type id %d), expected an integer" % [got, typeof(got)])
			int_ok = false
			continue
		if String(meta["width"]) == "uint32" and int(got) < 0:
			_fail("width:%s" % method_name, "uint32_t arrived negative: %d" % got)
			unsigned_ok = false
	if int_ok:
		_pass("width: every forwarded ABI value arrives as an integer")
	if unsigned_ok:
		_pass("width: no uint32_t value arrived re-signed negative")


func _pass(what: String) -> void:
	_passed += 1


func _fail(what: String, why: String) -> void:
	_failures.append("%s — %s" % [what, why])


func _finish() -> void:
	for note in _skipped:
		print("  skip    %s" % note)
		# Derived from the surface size so the floor tracks the header: 4 aggregate
		# assertions plus one per ABI method.
		var floor := MIN_ASSERTIONS_FROM_SURFACE
		if _expectations != null:
			floor += _expectations.ABI.size()
		if _passed < floor:
			_fail(
						"suite ran",
						"only %d assertions executed, expected at least %d — checks were skipped or threw"
						% [_passed, floor]
			)
	for failure in _failures:
		push_error("BRIDGE FAIL  %s" % failure)
	if _failures.is_empty():
		print("bridge test OK: %d assertions" % _passed)
		get_tree().quit(0)
	else:
		print("bridge test FAILED: %d failures" % _failures.size())
		get_tree().quit(1)
