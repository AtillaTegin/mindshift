class_name StripesRule
extends RuleBase
## "İkirəngli Hanoi" / "Zolaqlı Qüllə" (new mechanics specification v1, section
## 6): odd sizes are one colour, even sizes the other, and two disks of one
## colour never touch (no disk on another of the same parity). On top of the
## other rules, so every stack shows alternating stripes. Level JSON:
##   "rules": ["classic_hanoi", "stripes"]

const ID: String = "stripes"


func _init() -> void:
	violation_message = "RULE_STRIPES"


func get_id() -> String:
	return ID


func is_disk_move_allowed(disk: int, _from_peg: int, _to_peg: int, target_top: int) -> bool:
	return target_top == -1 or disk % 2 != target_top % 2


## Every stack alternates its colours.
func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for i: int in range(1, peg.size()):
			if int(peg[i]) % 2 == int(peg[i - 1]) % 2:
				return false
	return true


func supports_disk_move_check() -> bool:
	return true
