extends RefCounted
## Minimal assertion base for headless tests. A test file extends this script and
## defines methods named `test_*`; tests/test_runner.gd creates a fresh instance
## for every test method and calls before_each(), the test, then after_each().

var _failures: PackedStringArray = PackedStringArray()
## Set to true in a test that deliberately triggers engine errors (push_error etc.);
## otherwise any engine/script error logged during the test fails it.
var allow_engine_errors: bool = false


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func get_failures() -> PackedStringArray:
	return _failures


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_record("expected true, got false", message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_record("expected false, got true", message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not _values_equal(actual, expected):
		_record("expected <%s>, got <%s>" % [_describe(expected), _describe(actual)], message)


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if _values_equal(actual, unexpected):
		_record("expected anything but <%s>" % _describe(unexpected), message)


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		_record("expected null, got <%s>" % _describe(value), message)


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_record("expected non-null value", message)


func _record(reason: String, message: String) -> void:
	_failures.append(reason if message.is_empty() else "%s: %s" % [message, reason])


## `==` in GDScript errors on mismatched types (e.g. String vs int), so types are
## compared first; int and float are treated as comparable numbers.
static func _values_equal(a: Variant, b: Variant) -> bool:
	var type_a: int = typeof(a)
	var type_b: int = typeof(b)
	if type_a != type_b:
		var numeric: Array[int] = [TYPE_INT, TYPE_FLOAT]
		if not (type_a in numeric and type_b in numeric):
			return false
	return a == b


## Like str(), but quotes strings so "1" and 1 read differently in failures.
static func _describe(value: Variant) -> String:
	if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
		return "\"%s\"" % value
	return str(value)
