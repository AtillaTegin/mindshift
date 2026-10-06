class_name Move
extends RefCounted
## One move: take the top disk of `from_peg` and place it on `to_peg`.

var from_peg: int
var to_peg: int


func _init(p_from_peg: int = -1, p_to_peg: int = -1) -> void:
	from_peg = p_from_peg
	to_peg = p_to_peg


## Builds a Move from the `[from, to]` pair used by `solution_path` in level JSON.
## JSON numbers arrive as floats, so they are converted to int.
## Returns null if `pair` is not two integral numbers.
static func from_array(pair: Variant) -> Move:
	if typeof(pair) != TYPE_ARRAY or pair.size() != 2:
		return null
	for value: Variant in pair:
		if not _is_integral(value):
			return null
	return Move.new(int(pair[0]), int(pair[1]))


## `[from, to]` pair for level JSON.
func to_array() -> Array:
	return [from_peg, to_peg]


func equals(other: Move) -> bool:
	return other != null and from_peg == other.from_peg and to_peg == other.to_peg


func _to_string() -> String:
	return "Move(%d -> %d)" % [from_peg, to_peg]


static func _is_integral(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value) and value == floorf(value)
	return false
