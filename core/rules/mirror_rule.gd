class_name MirrorRule
extends RuleBase
## "Güzgü Hanoi" / "Güzgü Qoşa Məbəd" (new mechanics specification v1, section
## 8, base version): two independent boards on one screen, the first half of
## the pegs and the second. A disk never leaves its own board; each board
## follows the other rules on its own, the level is done when both reach their
## goals, and the moves of both count together. The Solver solves each board
## on its own (peg_groups). The second board's disks have the higher ids, so
## the classic rule keeps working on both. Level JSON:
##   "rules": ["classic_hanoi", "mirror"]

const ID: String = "mirror"


func _init() -> void:
	violation_message = "RULE_MIRROR"


func get_id() -> String:
	return ID


func is_move_allowed_with(_disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	var half: int = facts.peg_count() / 2
	return (from_peg < half) == (to_peg < half)


## An even number of pegs (two equal boards).
func is_state_valid(state: PuzzleState) -> bool:
	return state.pegs.size() % 2 == 0


func peg_groups(peg_count: int) -> Array[Array]:
	var half: int = peg_count / 2
	var groups: Array[Array] = [range(half), range(half, peg_count)]
	return groups


func needs_facts() -> bool:
	return true
