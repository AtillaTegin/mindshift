class_name ClassicHanoiRule
extends RuleBase
## Classic Tower of Hanoi: a disk may only go onto an empty peg or onto a
## strictly larger disk.

const ID: String = "classic_hanoi"


func _init() -> void:
	violation_message = "RULE_CLASSIC_HANOI"


func get_id() -> String:
	return ID


func is_disk_move_allowed(disk: int, _from_peg: int, _to_peg: int, target_top: int) -> bool:
	return target_top == -1 or disk < target_top


func supports_disk_move_check() -> bool:
	return true


func keeps_stacks_sorted() -> bool:
	return true


## Every peg must be strictly decreasing from bottom to top.
func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for i: int in range(1, peg.size()):
			if int(peg[i]) >= int(peg[i - 1]):
				return false
	return true
