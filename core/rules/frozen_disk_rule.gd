class_name FrozenDiskRule
extends RuleBase
## Frozen disk (bonus mechanics addendum 1): the disk of the configured size
## never moves. Smaller disks may still be put on top of it, as far as the
## other rules allow. Level JSON:
##   "rules": ["classic_hanoi", "frozen_disk"],
##   "rule_params": { "frozen_disk": { "disk_size": 3 } }
## Only removes moves, so it combines with the classic rule and the Solver's
## fast path without any Solver change.

const ID: String = "frozen_disk"

var disk_size: int = 0


func _init() -> void:
	violation_message = "RULE_FROZEN_DISK"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("disk_size")
	# Level JSON numbers arrive as floats.
	var is_whole: bool = typeof(value) == TYPE_INT \
			or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value))
	if params.size() != 1 or not is_whole or int(value) < 1:
		return "rule \"%s\" needs {\"disk_size\": positive integer}" % ID
	disk_size = int(value)
	return ""


func get_params() -> Dictionary:
	return {"disk_size": disk_size}


func is_disk_movable(disk: int) -> bool:
	return disk != disk_size


func is_disk_move_allowed(disk: int, _from_peg: int, _to_peg: int, _target_top: int) -> bool:
	return is_disk_movable(disk)


func supports_disk_move_check() -> bool:
	return true


## The frozen disk must exist in the position.
func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		if peg.has(disk_size):
			return true
	return false
