class_name CombinationRule
extends RuleBase
## "Birləşmə Tapmacası" (combination puzzle, level structure v4, section 4):
## the disks are all of one size, so any disk may go onto any other; the only
## limit is a peg's capacity (Water Sort style, user decision 2026-10-13). The
## goal is a colour arrangement (Level.color_goal, ColorGoal), searched by
## CombinationSolver; the size-based Solver is never used for these levels.
## The level's disk ids stay 1..N and only name the disks; their colours are
## Level.disk_colors. Level JSON:
##   "rules": ["combination"], "rule_params": {"combination": {"capacity": 3}}

const ID: String = "combination"
const MAX_CAPACITY: int = 10

var capacity: int = 0


func _init() -> void:
	violation_message = "RULE_PEG_FULL"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("capacity")
	if params.size() != 1 or typeof(value) != TYPE_INT or value < 1 or value > MAX_CAPACITY:
		return "rule \"%s\" needs {\"capacity\": 1..%d}" % [ID, MAX_CAPACITY]
	capacity = value
	return ""


func get_params() -> Dictionary:
	return {"capacity": capacity}


func is_move_allowed(state: PuzzleState, move: Move) -> bool:
	return state.pegs[move.to_peg].size() < capacity


func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		if peg.size() > capacity:
			return false
	return true
