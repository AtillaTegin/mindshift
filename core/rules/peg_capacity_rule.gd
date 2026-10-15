class_name PegCapacityRule
extends RuleBase
## "Qeyri-Bərabər Tutum" (new mechanics specification v1, section 4): every peg
## holds at most its own number of disks, a fixed setting of the level; a full
## peg takes no more. On top of the other rules. The board draws each rod as
## tall as its capacity. Level JSON:
##   "rules": ["classic_hanoi", "peg_capacity"],
##   "rule_params": {"peg_capacity": {"capacities": [5, 2, 4]}}
##
## Chapter waves v1 (section 3.3) add two size filters per peg, 0 meaning none:
## - "arches": a stone arch over the peg lets only disks of size <= N through
##   ("Tağ");
## - "holes": a hole in the peg's base lets smaller disks fall through, so an
##   empty peg takes only disks of size >= N; once one covers the hole, smaller
##   ones rest on it ("Deşikli qüllə", the island's).
## "Dar keçid" is just a capacity of 1.
##   "rule_params": {"peg_capacity": {"capacities": [5, 1, 4], "arches": [0, 0, 3], "holes": [0, 0, 0]}}

const ID: String = "peg_capacity"

var capacities: Array[int] = []
## Per peg, the largest disk an arch lets through (0: no arch).
var arches: Array[int] = []
## Per peg, the smallest disk an empty peg holds (0: no hole).
var holes: Array[int] = []


func _init() -> void:
	violation_message = "RULE_PEG_FULL"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"capacities\": [one count of at least 1 per peg]} and optional \"arches\"/\"holes\" (one size per peg, 0 for none)" % ID
	var value: Variant = params.get("capacities")
	if typeof(value) != TYPE_ARRAY or (value as Array).is_empty() \
			or not (value as Array).all(func(c: Variant) -> bool: return typeof(c) == TYPE_INT and c >= 1):
		return problem
	capacities.assign(value)
	for key: String in params:
		if not key in ["capacities", "arches", "holes"]:
			return problem
	for key: String in ["arches", "holes"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(n: Variant) -> bool: return typeof(n) == TYPE_INT and n >= 0) \
				or (not (list as Array).is_empty() and (list as Array).size() != capacities.size()):
			return problem
	arches.assign(params.get("arches", []))
	holes.assign(params.get("holes", []))
	if arches.is_empty():
		arches.resize(capacities.size())
		arches.fill(0)
	if holes.is_empty():
		holes.resize(capacities.size())
		holes.fill(0)
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"capacities": capacities.duplicate()}
	if arches.any(func(n: int) -> bool: return n > 0):
		params["arches"] = arches.duplicate()
	if holes.any(func(n: int) -> bool: return n > 0):
		params["holes"] = holes.duplicate()
	return params


func is_move_allowed_with(disk: int, _from_peg: int, to_peg: int, target_top: int, facts: MoveFacts) -> bool:
	if to_peg >= capacities.size() or facts.counts[to_peg] >= capacities[to_peg]:
		return false
	if arches[to_peg] > 0 and disk > arches[to_peg]:
		return false
	return holes[to_peg] == 0 or target_top != -1 or disk >= holes[to_peg]


## Which of the peg's limits refuses the move: full, the arch or the hole.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	var disk: int = state.get_top_disk(move.from_peg)
	var to: int = move.to_peg
	if to < arches.size() and arches[to] > 0 and disk > arches[to]:
		return "RULE_ARCH"
	if to < holes.size() and holes[to] > 0 and state.pegs[to].is_empty() and disk < holes[to]:
		return "RULE_HOLE"
	return violation_message


## One capacity per peg, no peg over its own, nothing wider than its arch, and
## nothing smaller than its hole at its bottom.
func is_state_valid(state: PuzzleState) -> bool:
	if state.pegs.size() != capacities.size():
		return false
	for peg_index: int in state.pegs.size():
		var stack: Array = state.pegs[peg_index]
		if stack.size() > capacities[peg_index]:
			return false
		if arches[peg_index] > 0 and stack.any(func(disk: int) -> bool: return disk > arches[peg_index]):
			return false
		if holes[peg_index] > 0 and not stack.is_empty() and int(stack[0]) < holes[peg_index]:
			return false
	return true


func needs_facts() -> bool:
	return true
