class_name CyclicRule
extends RuleBase
## "Dövrəvi Hanoi" (new mechanics specification v1, section 5): the pegs stand
## in a circle, numbered clockwise, and a disk only moves clockwise to the very
## next peg (from peg i to i + 1, from the last to peg 0). On top of the other
## rules. The board draws the pegs around a circle. Level JSON:
##   "rules": ["classic_hanoi", "cyclic"]

const ID: String = "cyclic"


func _init() -> void:
	violation_message = "RULE_CYCLIC"


func get_id() -> String:
	return ID


## The dial may turn; a mirror image would run the other way round.
func peg_symmetry() -> String:
	return PEGS_CIRCLE


func is_move_allowed_with(_disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return to_peg == (from_peg + 1) % facts.peg_count()


func needs_facts() -> bool:
	return true
