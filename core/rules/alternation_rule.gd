class_name AlternationRule
extends RuleBase
## The Nine Rings alternation (cultural integration addendum, section 1, in the
## user's variant D of 2026-10-12): on top of the other rules, disk 1 (the
## smallest) may always move; right after disk 1 any disk may move; after any
## other disk only disk 1 or a disk one size away from it (±1) may. At a level
## start nothing has moved yet, so only disk 1 may go. Refused moves are just
## blocked, never punished. Level JSON:
##   "rules": ["classic_hanoi", "alternation"]
## The literal rule of the addendum (no "anything after disk 1") lets only
## disks 1-3 ever move on 3-4 pegs (measured 2026-10-11), hence variant D.
## It looks at PuzzleState.last_moved_disk (uses_last_move), so the Solver keeps
## the last moved disk in its search state; the Solver still never names it.

const ID: String = "alternation"


func _init() -> void:
	violation_message = "RULE_ALTERNATION"


func get_id() -> String:
	return ID


func is_disk_movable(disk: int, last_disk: int) -> bool:
	return disk == 1 or last_disk == 1 or absi(disk - last_disk) == 1


func is_disk_move_allowed_after(disk: int, _from_peg: int, _to_peg: int, _target_top: int, last_disk: int) -> bool:
	return is_disk_movable(disk, last_disk)


## Without the last move this rule cannot judge a move; the Solver and RuleSet
## always go through is_disk_move_allowed_after().
func is_disk_move_allowed(_disk: int, _from_peg: int, _to_peg: int, _target_top: int) -> bool:
	return true


func uses_last_move() -> bool:
	return true


func supports_disk_move_check() -> bool:
	return true
