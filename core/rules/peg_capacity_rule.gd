class_name PegCapacityRule
extends RuleBase
## "Qeyri-Bərabər Tutum" (new mechanics specification v1, section 4): every peg
## holds at most its own number of disks, a fixed setting of the level; a full
## peg takes no more. On top of the other rules. The board draws each rod as
## tall as its capacity. Level JSON:
##   "rules": ["classic_hanoi", "peg_capacity"],
##   "rule_params": {"peg_capacity": {"capacities": [5, 2, 4]}}

const ID: String = "peg_capacity"

var capacities: Array[int] = []


func _init() -> void:
	violation_message = "RULE_PEG_FULL"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("capacities")
	if params.size() != 1 or typeof(value) != TYPE_ARRAY or (value as Array).is_empty() \
			or not (value as Array).all(func(c: Variant) -> bool: return typeof(c) == TYPE_INT and c >= 1):
		return "rule \"%s\" needs {\"capacities\": [one count of at least 1 per peg]}" % ID
	capacities.assign(value)
	return ""


func get_params() -> Dictionary:
	return {"capacities": capacities.duplicate()}


func is_move_allowed_with(_disk: int, _from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return to_peg < capacities.size() and facts.counts[to_peg] < capacities[to_peg]


## One capacity per peg, and no peg over its own.
func is_state_valid(state: PuzzleState) -> bool:
	if state.pegs.size() != capacities.size():
		return false
	for peg_index: int in state.pegs.size():
		if state.pegs[peg_index].size() > capacities[peg_index]:
			return false
	return true


func needs_facts() -> bool:
	return true
