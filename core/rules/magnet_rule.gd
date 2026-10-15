class_name MagnetRule
extends RuleBase
## "Maqnit Hanoi" (new mechanics specification v1, section 7): every disk has
## two faces, red and blue, and turns over each time it moves. A disk may only
## be put on another if the two faces that touch differ (opposite poles). All
## disks start red side up. Which face is up is the rule's memory: bit d - 1
## set means disk d shows blue. The goal is the position only (any faces).
## Placing X on Y: X's face down after the turn is the face X showed before
## the move, so X may go on Y when X and Y show different faces now. On top of
## the other rules. Level JSON:
##   "rules": ["classic_hanoi", "magnet"]
## The memory doubles the positions for every disk (p^n * 2^n), so its levels
## wait for the performance report (specification v1, section 7).

const ID: String = "magnet"


func _init() -> void:
	violation_message = "RULE_MAGNET"


func get_id() -> String:
	return ID


func is_move_allowed_with(disk: int, _from_peg: int, _to_peg: int, target_top: int, facts: MoveFacts) -> bool:
	return target_top == -1 or blue_up(facts.memory, disk) != blue_up(facts.memory, target_top)


func uses_memory() -> bool:
	return true


func memory_states(_peg_count: int, disk_count: int) -> int:
	return 1 << disk_count


func memory_after(facts: MoveFacts, disk: int, _from_peg: int, _to_peg: int) -> int:
	return facts.memory ^ (1 << (disk - 1))


## Whether `disk` shows its blue face in `memory`.
static func blue_up(memory: int, disk: int) -> bool:
	return (memory >> (disk - 1)) & 1 == 1
