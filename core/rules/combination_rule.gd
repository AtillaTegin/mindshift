class_name CombinationRule
extends RuleBase
## "Birləşmə Tapmacası" (combination puzzle, level structure v4, section 4) with
## Water Sort's rule (auto-group addendum, section 2, user decision
## 2026-10-13): the disks are all of one size; a disk goes only onto an empty
## peg or onto a disk of its own colour, and never above a peg's capacity. A
## move carries the whole same-colour run at the top of its peg, as much of it
## as the target has room for (the upper part; the rest stays), and counts as
## one move. The goal is a colour arrangement (Level.color_goal, ColorGoal),
## searched by CombinationSolver; the size-based Solver is never used for these
## levels. The level's disk ids stay 1..N and only name the disks; their
## colours are Level.disk_colors, handed over by bind_disk_colours(). Level JSON:
##   "rules": ["combination"], "rule_params": {"combination": {"capacity": 3}}

const ID: String = "combination"
const MAX_CAPACITY: int = 10
const FULL_MESSAGE: String = "RULE_PEG_FULL"
const COLOUR_MESSAGE: String = "RULE_SAME_COLOUR"

var capacity: int = 0
## Colour of disk id i at i - 1.
var _colours: Array[String] = []


func _init() -> void:
	violation_message = FULL_MESSAGE


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


func bind_disk_colours(colours: Array[String]) -> void:
	_colours = colours.duplicate()


func is_move_allowed(state: PuzzleState, move: Move) -> bool:
	var target: Array = state.pegs[move.to_peg]
	if target.size() >= capacity:
		return false
	return target.is_empty() or colour_of(target[-1]) == colour_of(state.pegs[move.from_peg][-1])


func get_violation_message(state: PuzzleState, move: Move) -> String:
	return FULL_MESSAGE if state.pegs[move.to_peg].size() >= capacity else COLOUR_MESSAGE


## The top run of the source, as much of it as the target has room for.
func disks_moved(state: PuzzleState, move: Move) -> int:
	return mini(top_run(state.pegs[move.from_peg]), capacity - state.pegs[move.to_peg].size())


## A tap picks up the whole top run (auto-group addendum, section 2).
func disks_picked_up(stack: Array) -> int:
	return top_run(stack)


## How many disks of one colour stand together at the top of `stack`.
func top_run(stack: Array) -> int:
	var run: int = 0
	while run < stack.size() and colour_of(stack[stack.size() - 1 - run]) == colour_of(stack[-1]):
		run += 1
	return run


## The colour of disk `disk` ("" when the level gave none).
func colour_of(disk: int) -> String:
	return _colours[disk - 1] if disk >= 1 and disk <= _colours.size() else ""


func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		if peg.size() > capacity:
			return false
	return true
