class_name ClassicHanoiRule
extends RuleBase
## Classic Tower of Hanoi: a disk may only go onto an empty peg or onto a
## strictly larger disk.

const ID: String = "classic_hanoi"


func get_id() -> String:
	return ID


func is_move_allowed(state: PuzzleState, move: Move) -> bool:
	var target_top: int = state.get_top_disk(move.to_peg)
	return target_top == -1 or state.get_top_disk(move.from_peg) < target_top


## Every peg must be strictly decreasing from bottom to top.
func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for i: int in range(1, peg.size()):
			if int(peg[i]) >= int(peg[i - 1]):
				return false
	return true
