class_name BalanceRule
extends RuleBase
## "Tərəzi Hanoi" / "Qədim Tərəzi" (new mechanics specification v1, section 1):
## the pegs come in pairs (0-1, 2-3, ...), the two pans of a scale. In every
## position the sums of the disk sizes on the two pegs of a pair differ by at
## most `tolerance` (user decision 2026-10-15: start, goal and every position
## after a move); a move that would tip a pair further is refused. On top of
## the other rules; boards of 4 or 6 pegs. Level JSON:
##   "rules": ["classic_hanoi", "balance"], "rule_params": {"balance": {"tolerance": 4}}

const ID: String = "balance"

var tolerance: int = 0


func _init() -> void:
	violation_message = "RULE_BALANCE"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("tolerance")
	if params.size() != 1 or typeof(value) != TYPE_INT or value < 0:
		return "rule \"%s\" needs {\"tolerance\": a whole number of at least 0}" % ID
	tolerance = value
	return ""


func get_params() -> Dictionary:
	return {"tolerance": tolerance}


## The pair partner of `peg` (0 <-> 1, 2 <-> 3, ...).
static func pan_of(peg: int) -> int:
	return peg + 1 if peg % 2 == 0 else peg - 1


## The two pairs the move touches stay within the tolerance afterwards.
func is_move_allowed_with(disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	var sums: PackedInt32Array = facts.sums
	var from_pan: int = pan_of(from_peg)
	var to_pan: int = pan_of(to_peg)
	var from_after: int = sums[from_peg] - disk
	var to_after: int = sums[to_peg] + disk
	var from_pan_after: int = sums[from_pan] + (disk if from_pan == to_peg else 0)
	var to_pan_after: int = sums[to_pan] - (disk if to_pan == from_peg else 0)
	return absi(from_after - from_pan_after) <= tolerance and absi(to_after - to_pan_after) <= tolerance


## An even number of pegs and every pair within the tolerance.
func is_state_valid(state: PuzzleState) -> bool:
	if state.pegs.size() % 2 != 0:
		return false
	for peg: int in range(0, state.pegs.size(), 2):
		if absi(sum_of(state.pegs[peg]) - sum_of(state.pegs[peg + 1])) > tolerance:
			return false
	return true


static func sum_of(stack: Array) -> int:
	var total: int = 0
	for disk: int in stack:
		total += disk
	return total


func needs_facts() -> bool:
	return true
