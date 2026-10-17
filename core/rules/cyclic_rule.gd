class_name CyclicRule
extends RuleBase
## "Dövrəvi Hanoi" (new mechanics specification v1, section 5): the pegs stand
## in a circle, numbered clockwise, and a disk only moves clockwise to the very
## next peg (from peg i to i + 1, from the last to peg 0). On top of the other
## rules. The board draws the pegs around a circle. Level JSON:
##   "rules": ["classic_hanoi", "cyclic"]
##
## World 3-4 sub-elements (MindShift_Dunya3-4_Alt_Elementler_v1.md, section 3),
## optional settings:
##   "back": peg              "Əks qüllə": from this peg a disk may also go
##                            back, counterclockwise
##   "skip": peg              "Qısa yol": from this peg a disk may skip the
##                            next peg (still clockwise)
##   "center": peg            "Mərkəz": a peg in the middle of the circle that
##                            holds one disk and is linked both ways to every
##                            other peg (the circle's pegs are the others, in
##                            order)
##   "eight": [[...], [...]]  "Səkkiz": two circles that share one peg, each a
##                            list of pegs in its own direction of travel; a
##                            disk moves to the next peg of a circle it is on

const ID: String = "cyclic"

var back: int = -1
var skip: int = -1
var center: int = -1
var eight: Array[Array] = []
## The centre cut off from the circle ("center_closed": true): only for
## measuring what the centre does (LevelForge.settings_without).
var center_closed: bool = false


func _init() -> void:
	violation_message = "RULE_CYCLIC"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes optional \"back\": peg, \"skip\": peg, \"center\": peg, \"eight\": [[pegs], [pegs]]" % ID
	for key: String in params:
		if not key in ["back", "skip", "center", "eight", "center_closed"]:
			return problem
	var closed: Variant = params.get("center_closed", false)
	if typeof(closed) != TYPE_BOOL:
		return problem
	center_closed = closed
	for key: String in ["back", "skip", "center"]:
		var value: Variant = params.get(key, -1)
		if typeof(value) != TYPE_INT or value < -1:
			return problem
	back = params.get("back", -1)
	skip = params.get("skip", -1)
	center = params.get("center", -1)
	var loops: Variant = params.get("eight", [])
	if typeof(loops) != TYPE_ARRAY or not ((loops as Array).is_empty() or (loops as Array).size() == 2):
		return problem
	for loop: Variant in loops:
		if typeof(loop) != TYPE_ARRAY or (loop as Array).size() < 2 \
				or not (loop as Array).all(func(p: Variant) -> bool: return typeof(p) == TYPE_INT and p >= 0):
			return problem
	eight.assign(loops)
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	for key: String in ["back", "skip", "center"]:
		var value: int = back if key == "back" else skip if key == "skip" else center
		if value >= 0:
			params[key] = value
	if not eight.is_empty():
		params["eight"] = eight.duplicate(true)
	if center_closed:
		params["center_closed"] = true
	return params


## The dial may turn; a mirror image would run the other way round. Its
## sub-elements tie it to one place.
func peg_symmetry() -> String:
	return PEGS_CIRCLE if get_params().is_empty() else PEGS_FIXED


## A move round the dial comes back only the long way round.
func moves_one_way() -> bool:
	return true


## The peg after `peg` clockwise on a circle of `peg_count` pegs (the centre is
## not on it).
func next_of(peg: int, peg_count: int) -> int:
	var after: int = (peg + 1) % peg_count
	return (after + 1) % peg_count if after == center else after


func previous_of(peg: int, peg_count: int) -> int:
	var before: int = (peg - 1 + peg_count) % peg_count
	return (before - 1 + peg_count) % peg_count if before == center else before


## Whether a disk may go from `from_peg` to `to_peg` (where it fits).
func reaches(from_peg: int, to_peg: int, peg_count: int) -> bool:
	if not eight.is_empty():
		for loop: Array in eight:
			var at: int = loop.find(from_peg)
			if at != -1 and loop[(at + 1) % loop.size()] == to_peg:
				return true
		return false
	if from_peg == center or to_peg == center:
		return center >= 0 and not center_closed
	if to_peg == next_of(from_peg, peg_count):
		return true
	if from_peg == back and to_peg == previous_of(from_peg, peg_count):
		return true
	return from_peg == skip and to_peg == next_of(next_of(from_peg, peg_count), peg_count)


func is_move_allowed_with(_disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	if to_peg == center and facts.counts[center] > 0:
		return false
	return reaches(from_peg, to_peg, facts.peg_count())


func needs_facts() -> bool:
	return true


## The centre holds one disk at most.
func is_state_valid(state: PuzzleState) -> bool:
	return center < 0 or (center < state.get_peg_count() and state.pegs[center].size() <= 1)


func get_violation_message(state: PuzzleState, move: Move) -> String:
	if move.to_peg == center and reaches(move.from_peg, move.to_peg, state.get_peg_count()):
		return "RULE_CENTER_FULL"
	return violation_message
