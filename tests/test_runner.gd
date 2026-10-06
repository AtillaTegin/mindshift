extends SceneTree
## Headless test runner. From the project folder:
##   godot --headless --path . --import          (once, builds the class cache)
##   godot --headless --path . --script res://tests/test_runner.gd
##   godot --headless --path . --script res://tests/test_runner.gd -- --filter=solver
## Runs every res://tests/test_*.gd file, calling each `test_*` method on a fresh
## instance. Exits with code 0 only when every test passed, 1 otherwise.

const TESTS_DIR: String = "res://tests"
const TEST_CASE: GDScript = preload("res://tests/test_case.gd")
const NOT_TEST_FILES: Array[String] = ["test_runner.gd", "test_case.gd"]


## Counts engine and script errors so a test that crashes mid-way (which aborts
## the GDScript function silently from the caller's point of view) still fails.
class ErrorCounter extends Logger:
	var _errors: int = 0
	var _script_errors: int = 0
	var _mutex: Mutex = Mutex.new()

	func _log_error(_function: String, _file: String, _line: int, _code: String,
			_rationale: String, _editor_notify: bool, error_type: int,
			_script_backtraces: Array[ScriptBacktrace]) -> void:
		_mutex.lock()
		_errors += 1
		if error_type == ERROR_TYPE_SCRIPT:
			_script_errors += 1
		_mutex.unlock()

	func get_errors() -> int:
		_mutex.lock()
		var value: int = _errors
		_mutex.unlock()
		return value

	func get_script_errors() -> int:
		_mutex.lock()
		var value: int = _script_errors
		_mutex.unlock()
		return value


func _initialize() -> void:
	# Only a completed _run_all() can return true. If the runner itself hits a
	# script error, the aborted call yields false and the run still fails.
	quit(0 if _run_all() else 1)


func _run_all() -> bool:
	var filter: String = _parse_filter(OS.get_cmdline_user_args())
	var error_counter: ErrorCounter = ErrorCounter.new()
	OS.add_logger(error_counter)

	var passed: int = 0
	var failed: int = 0
	var started_ms: int = Time.get_ticks_msec()
	for file_name: String in _find_test_files(filter):
		print("== %s" % file_name)
		var script: GDScript = load("%s/%s" % [TESTS_DIR, file_name]) as GDScript
		var problem: String = _check_test_script(script)
		if not problem.is_empty():
			print("  FAIL %s" % problem)
			failed += 1
			continue
		for info: Dictionary in _find_test_methods(script):
			var method_name: String = info["name"]
			if _required_arg_count(info) > 0:
				print("  FAIL %s: test methods must not take arguments" % method_name)
				failed += 1
				continue
			var errors_before: int = error_counter.get_errors()
			var script_errors_before: int = error_counter.get_script_errors()
			var test_started_ms: int = Time.get_ticks_msec()
			var case: RefCounted = script.new()
			case.call("before_each")
			var returned: Variant = case.call(method_name)
			case.call("after_each")
			var elapsed_ms: int = Time.get_ticks_msec() - test_started_ms
			var failures: PackedStringArray = case.call("get_failures")
			if _is_coroutine_state(returned):
				failures.append("test used await; this runner only supports synchronous tests")
			var new_errors: int = error_counter.get_errors() - errors_before
			var new_script_errors: int = error_counter.get_script_errors() - script_errors_before
			if new_script_errors > 0:
				failures.append("%d script error(s) during the test (see output above)" % new_script_errors)
			elif new_errors > 0 and not case.get("allow_engine_errors"):
				failures.append("%d engine error(s) logged during the test (see output above)" % new_errors)
			if failures.is_empty():
				passed += 1
				print("  PASS %s (%d ms)" % [method_name, elapsed_ms])
			else:
				failed += 1
				print("  FAIL %s (%d ms)" % [method_name, elapsed_ms])
				for failure: String in failures:
					print("       - %s" % failure)

	OS.remove_logger(error_counter)
	var total_ms: int = Time.get_ticks_msec() - started_ms
	print("")
	print("%d passed, %d failed (%d ms)" % [passed, failed, total_ms])
	if passed + failed == 0:
		print("No tests found.")
		return false
	return failed == 0


## Why `script` cannot be run as a test file, or "" if it can.
func _check_test_script(script: GDScript) -> String:
	if script == null or not script.can_instantiate():
		return "could not load the script"
	var base: Script = script
	while base != null and base != TEST_CASE:
		base = base.get_base_script()
	if base == null:
		return "test files must extend \"res://tests/test_case.gd\""
	for info: Dictionary in script.get_script_method_list():
		if info["name"] == "_init" and _required_arg_count(info) > 0:
			return "_init() of a test file must not require arguments"
	return ""


func _parse_filter(user_args: PackedStringArray) -> String:
	for arg: String in user_args:
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""


func _find_test_files(filter: String) -> Array[String]:
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(TESTS_DIR):
		if not file_name.begins_with("test_") or not file_name.ends_with(".gd"):
			continue
		if file_name in NOT_TEST_FILES:
			continue
		if not filter.is_empty() and not file_name.contains(filter):
			continue
		files.append(file_name)
	files.sort()
	return files


## Method info dictionaries of the `test_*` methods, in declaration order.
func _find_test_methods(script: GDScript) -> Array[Dictionary]:
	var methods: Array[Dictionary] = []
	var names: Array[String] = []
	for info: Dictionary in script.get_script_method_list():
		var method_name: String = info["name"]
		if method_name.begins_with("test_") and not method_name in names:
			names.append(method_name)
			methods.append(info)
	return methods


static func _required_arg_count(info: Dictionary) -> int:
	return info["args"].size() - info["default_args"].size()


## A test that hits `await` returns a GDScriptFunctionState immediately.
static func _is_coroutine_state(value: Variant) -> bool:
	return typeof(value) == TYPE_OBJECT and is_instance_valid(value) \
			and (value as Object).get_class() == "GDScriptFunctionState"
