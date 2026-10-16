class_name AdjacentPegsRule
extends RuleBase
## "Karvan Yolu" (caravan road addendum, section 1; Hanoi variant C, linear
## adjacency): the pegs stand in a line like caravan stops, and a disk may only
## move to a neighbouring peg (from peg i to i - 1 or i + 1), never jump over
## one. On top of the other rules. Level JSON:
##   "rules": ["classic_hanoi", "adjacent_pegs"]
## This is the fixed, linear case of the linked-pegs idea (no relinking); it
## judges a move from the two pegs alone, so the Solver keeps its fast path.

const ID: String = "adjacent_pegs"


func _init() -> void:
	violation_message = "RULE_ADJACENT_PEGS"


func get_id() -> String:
	return ID


## The road reads the same from either end.
func peg_symmetry() -> String:
	return PEGS_LINE


func is_disk_move_allowed(_disk: int, from_peg: int, to_peg: int, _target_top: int) -> bool:
	return absi(from_peg - to_peg) == 1


func supports_disk_move_check() -> bool:
	return true
