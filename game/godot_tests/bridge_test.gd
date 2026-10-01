extends Node

# Bridge integration test (TASK-001.05 AC#4, reworked for TASK-001.06 to drive
# SimWorld rather than DopeWarsWorld).
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
# against the header. With P methods carrying a pinned value the four checks produce:
#   surface      1   (the aggregate "N methods match" assertion; mismatches are
#                     recorded as failures, so the pass path is one assertion)
#   identity     1   (abi_version)
#   values       P   (one per method carrying a pinned value)
#   width        2   (integer-ness + unsigned-ness aggregates)
# P is not the row count: abi_version, world_size, world_align and world_dump_len
# are checked by kind rather than against a pinned constant, so counting them as
# value assertions sets a floor the pass path can never reach. That mistake was
# latent until TASK-001.06 un-nested this check out of the skip loop, where it
# had never been running.
const MIN_ASSERTIONS_FROM_SURFACE := 4

var _passed := 0
var _failures: Array[String] = []
var _skipped: Array[String] = []
var _expectations: Object = null
var _per_case := {}
var _current_case := "harness"
var _reconciled := false
var _frames := 0

# Backstop for a synchronous error in _ready before _finish: it aborts _ready
# and the scene would otherwise spin without ever quitting. A healthy run
# reaches _finish on the first frame, well under this many frames later.
const WATCHDOG_FRAMES := 600


func _ready() -> void:
	_expectations = _load_expectations()
	if _expectations == null:
		_finish()
		return

	if not ClassDB.class_exists("DopeWarsWorld"):
		_fail(
			"GDExtension registration",
			"the extension class is not registered; the extension did not load (check game/bin/ and the Mojo runtime rpath)"
		)
		_finish()
		return

	# SimWorld, not DopeWarsWorld: tools/validate_game_boundary.py forbids
	# naming the GDExtension class outside game/simulation/, and going through
	# the wrapper is the path the game actually takes.
	var world := SimWorld.new()
	_case("class_surface")
	_check_class_surface(world)
	_case("abi_identity")
	_check_abi_identity(world)
	_case("forwarded_values")
	_check_forwarded_values(world)
	_case("width_fidelity")
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


# SimWorld must expose at least the generated surface: no missing method (a
# dropped forward). The extra direction is deliberately not asserted: the wrapper
# forwards the full ABI, while this table only pins the pointer-free no-arg subset
# it can value-check, so methods outside the table are expected. The exact
# export surface is the export-surface gate's job (tools/check_abi_exports.py).
func _check_class_surface(world: Object) -> void:
	var expected_names: Array = _expectations.ABI.keys()
	var bound := _forwarded_method_names(world)

	for name in expected_names:
		if not bound.has(name):
			_fail("surface", "method '%s' is expected but not forwarded by SimWorld" % name)

	if expected_names.is_empty():
		_fail("surface", "generated ABI surface is empty — generator or header is broken")
	else:
		_pass("surface: %d bound methods match the generated ABI surface" % expected_names.size())


# get_method_list() on a GDScript instance also reports every inherited
# Object/RefCounted method, so "the wrapper's own methods" is computed by
# subtracting the base class's method set rather than by guessing which names
# look built-in.
#
# This is also why SimWorld re-exports the dw_rules_* accessors as instance
# methods even though DopeWarsWorld binds them statically: a GDScript
# `static func` never shows up in get_method_list(), so 14 of the ABI's methods
# would be permanently invisible to this check.
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


## Marks a case as started; its assertions (passes and failures alike -- both
## are checks that ran) accumulate until the next _case, so a case that throws,
## returns early, or never runs ends up short of its floor in _finish.
func _case(name: String) -> void:
	_current_case = name
	_per_case[name] = 0


func _pass(what: String) -> void:
	_per_case[_current_case] = int(_per_case.get(_current_case, 0)) + 1
	_passed += 1


func _fail(what: String, why: String) -> void:
	_per_case[_current_case] = int(_per_case.get(_current_case, 0)) + 1
	_failures.append("%s — %s" % [what, why])


# Fires only when a synchronous _ready error skipped _finish and the scene would
# otherwise never quit; a healthy run reconciles on the first frame.
func _process(_delta: float) -> void:
	if not _reconciled:
		_frames += 1
		if _frames >= WATCHDOG_FRAMES:
			_finish()


func _finish() -> void:
	if _reconciled:
		return
	_reconciled = true
	for note in _skipped:
		print("  skip    %s" % note)
	# Per-case floors, derived from the generated surface like the whole-suite
	# floor below: forwarded_values carries one assertion per value row, the
	# other three are single aggregate checks. A case that dies mid-function ends
	# up short of its floor and is named here rather than surfacing as a bare
	# script error.
	var value_rows := 0
	if _expectations != null:
		for meta: Dictionary in _expectations.ABI.values():
			if meta.has("value"):
				value_rows += 1
	var expected := {
		"class_surface": 1,
		"abi_identity": 1,
		"forwarded_values": value_rows,
		"width_fidelity": 2,
	}
	for name: String in expected:
		var want: int = expected[name]
		var ran: int = int(_per_case.get(name, 0))
		if ran < want:
			var why := "never ran" if not _per_case.has(name) else "died mid-function"
			_failures.append("case %s — %s (ran %d assertions, expected %d)" % [name, why, ran, want])
	# Derived from the value-carrying rows so the floor tracks the header: 4
	# aggregate assertions plus one per pinned value. This check used to sit
	# inside the skip loop above, over a list nothing ever appended to, so the
	# anti-false-pass guard never ran at all.
	var floor := MIN_ASSERTIONS_FROM_SURFACE + value_rows
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
