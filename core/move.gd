class_name Move
extends RefCounted
## One move: take the top disk of `from_peg` and place it on `to_peg`. A
## compound move (linked disks, RuleBase.group_of_with) also takes the top
## disk of `from_peg_2` to `to_peg_2` (and of `from_peg_3` to `to_peg_3` for a
## chain of three) at the same time; it counts as one move.

var from_peg: int
var to_peg: int
## The second disk of a compound move; -1 for an ordinary move.
var from_peg_2: int = -1
var to_peg_2: int = -1
## The third disk of a chain of three ("Uzun zəncir"); -1 otherwise.
var from_peg_3: int = -1
var to_peg_3: int = -1


func _init(p_from_peg: int = -1, p_to_peg: int = -1, p_from_peg_2: int = -1, p_to_peg_2: int = -1,
		p_from_peg_3: int = -1, p_to_peg_3: int = -1) -> void:
	from_peg = p_from_peg
	to_peg = p_to_peg
	from_peg_2 = p_from_peg_2
	to_peg_2 = p_to_peg_2
	from_peg_3 = p_from_peg_3
	to_peg_3 = p_to_peg_3


## A move of the disks on `froms` to `tos` (one, two or three of each).
static func of_parts(froms: Array, tos: Array) -> Move:
	var move: Move = Move.new(froms[0], tos[0])
	if froms.size() > 1:
		move.from_peg_2 = froms[1]
		move.to_peg_2 = tos[1]
	if froms.size() > 2:
		move.from_peg_3 = froms[2]
		move.to_peg_3 = tos[2]
	return move


## Builds a Move from the `[from, to]` pair (or `[from, to, from_2, to_2]` for
## a compound move, six for a chain of three) used by `solution_path` in level
## JSON. JSON numbers arrive as floats, so they are converted to int. Returns
## null for anything else.
static func from_array(pair: Variant) -> Move:
	if typeof(pair) != TYPE_ARRAY or not pair.size() in [2, 4, 6]:
		return null
	for value: Variant in pair:
		if not _is_integral(value):
			return null
	var froms: Array = []
	var tos: Array = []
	for i: int in range(0, pair.size(), 2):
		froms.append(int(pair[i]))
		tos.append(int(pair[i + 1]))
	return of_parts(froms, tos)


## `[from, to]` (or the pegs of every disk of a compound move) for level JSON.
func to_array() -> Array:
	var values: Array = []
	for part: Array in parts():
		values.append_array(part)
	return values


func is_compound() -> bool:
	return from_peg_2 >= 0


## [from, to] of each disk the move takes, in its order.
func parts() -> Array:
	var found: Array = [[from_peg, to_peg]]
	if from_peg_2 >= 0:
		found.append([from_peg_2, to_peg_2])
	if from_peg_3 >= 0:
		found.append([from_peg_3, to_peg_3])
	return found


func froms() -> Array[int]:
	var pegs: Array[int] = []
	for part: Array in parts():
		pegs.append(part[0])
	return pegs


func tos() -> Array[int]:
	var pegs: Array[int] = []
	for part: Array in parts():
		pegs.append(part[1])
	return pegs


func equals(other: Move) -> bool:
	return other != null and from_peg == other.from_peg and to_peg == other.to_peg \
			and from_peg_2 == other.from_peg_2 and to_peg_2 == other.to_peg_2 \
			and from_peg_3 == other.from_peg_3 and to_peg_3 == other.to_peg_3


func _to_string() -> String:
	var steps: PackedStringArray = PackedStringArray()
	for part: Array in parts():
		steps.append("%d -> %d" % [part[0], part[1]])
	return "Move(%s)" % ", ".join(steps)


static func _is_integral(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value) and value == floorf(value)
	return false
