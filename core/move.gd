class_name Move
extends RefCounted
## One move: take the top disk of `from_peg` and place it on `to_peg`. A
## compound move (two linked disks, RuleBase.partner_of) also takes the top
## disk of `from_peg_2` to `to_peg_2` at the same time; it counts as one move.

var from_peg: int
var to_peg: int
## The second disk of a compound move; -1 for an ordinary move.
var from_peg_2: int = -1
var to_peg_2: int = -1


func _init(p_from_peg: int = -1, p_to_peg: int = -1, p_from_peg_2: int = -1, p_to_peg_2: int = -1) -> void:
	from_peg = p_from_peg
	to_peg = p_to_peg
	from_peg_2 = p_from_peg_2
	to_peg_2 = p_to_peg_2


## Builds a Move from the `[from, to]` pair (or `[from, to, from_2, to_2]` for
## a compound move) used by `solution_path` in level JSON. JSON numbers arrive
## as floats, so they are converted to int. Returns null for anything else.
static func from_array(pair: Variant) -> Move:
	if typeof(pair) != TYPE_ARRAY or (pair.size() != 2 and pair.size() != 4):
		return null
	for value: Variant in pair:
		if not _is_integral(value):
			return null
	if pair.size() == 4:
		return Move.new(int(pair[0]), int(pair[1]), int(pair[2]), int(pair[3]))
	return Move.new(int(pair[0]), int(pair[1]))


## `[from, to]` (or the four pegs of a compound move) for level JSON.
func to_array() -> Array:
	return [from_peg, to_peg, from_peg_2, to_peg_2] if is_compound() else [from_peg, to_peg]


func is_compound() -> bool:
	return from_peg_2 >= 0


func equals(other: Move) -> bool:
	return other != null and from_peg == other.from_peg and to_peg == other.to_peg \
			and from_peg_2 == other.from_peg_2 and to_peg_2 == other.to_peg_2


func _to_string() -> String:
	if is_compound():
		return "Move(%d -> %d, %d -> %d)" % [from_peg, to_peg, from_peg_2, to_peg_2]
	return "Move(%d -> %d)" % [from_peg, to_peg]


static func _is_integral(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value) and value == floorf(value)
	return false
