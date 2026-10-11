class_name PuzzleState
extends RefCounted
## A puzzle position: N pegs, each holding disk sizes ordered bottom -> top.
## The top disk of a peg is the last element of its array. Disk sizes are
## positive integers (-1 is reserved as the "empty peg" value).

var pegs: Array[Array] = []
## The disk whose move led to this position (0: none, e.g. a level start).
## Rules may look at it (RuleBase.uses_last_move); it is not part of the
## position itself, so equals() and hash_key() ignore it.
var last_moved_disk: int = 0


## `p_pegs` is deep-copied, so the caller's arrays are never shared.
func _init(p_pegs: Array = []) -> void:
	for peg: Array in p_pegs:
		var copy: Array = []
		for disk: Variant in peg:
			copy.append(int(disk))
		pegs.append(copy)


## Builds a state from level JSON data such as `[[5, 3, 1], [4], [2], []]`.
## JSON numbers arrive as floats, so they are converted to int.
## Returns null if `data` is not an array of arrays of integral numbers.
static func from_array(data: Variant) -> PuzzleState:
	if typeof(data) != TYPE_ARRAY:
		return null
	var state: PuzzleState = PuzzleState.new()
	for peg: Variant in data:
		if typeof(peg) != TYPE_ARRAY:
			return null
		var copy: Array = []
		for disk: Variant in peg:
			if not _is_integral(disk):
				return null
			copy.append(int(disk))
		state.pegs.append(copy)
	return state


## Deep copy as plain nested arrays, for level JSON.
func to_array() -> Array:
	var result: Array = []
	for peg: Array in pegs:
		result.append(peg.duplicate())
	return result


func duplicate_state() -> PuzzleState:
	var copy: PuzzleState = PuzzleState.new()
	for peg: Array in pegs:
		copy.pegs.append(peg.duplicate())
	copy.last_moved_disk = last_moved_disk
	return copy


## Unique key for this position, e.g. `"0:3,2,1|1:|2:"`.
## Equal states always give the same key and different states never collide:
## peg and disk separators cannot appear inside an integer.
func hash_key() -> String:
	var parts: PackedStringArray = PackedStringArray()
	for i: int in pegs.size():
		parts.append(str(i) + ":" + ",".join(PackedStringArray(pegs[i])))
	return "|".join(parts)


func equals(other: PuzzleState) -> bool:
	if other == null or other.pegs.size() != pegs.size():
		return false
	for i: int in pegs.size():
		var mine: Array = pegs[i]
		var theirs: Array = other.pegs[i]
		if mine.size() != theirs.size():
			return false
		for j: int in mine.size():
			if int(mine[j]) != int(theirs[j]):
				return false
	return true


## Size of the top disk on `peg_index`; -1 if the peg is empty or does not exist.
func get_top_disk(peg_index: int) -> int:
	if peg_index < 0 or peg_index >= pegs.size():
		return -1
	var peg: Array = pegs[peg_index]
	if peg.is_empty():
		return -1
	return int(peg.back())


func get_peg_count() -> int:
	return pegs.size()


func get_disk_count() -> int:
	var total: int = 0
	for peg: Array in pegs:
		total += peg.size()
	return total


func _to_string() -> String:
	return "PuzzleState(%s)" % hash_key()


static func _is_integral(value: Variant) -> bool:
	match typeof(value):
		TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value) and value == floorf(value)
	return false
