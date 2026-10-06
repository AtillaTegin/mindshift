class_name RuleBase
extends RefCounted
## Base class for puzzle rules. Each mechanic (classic Hanoi ordering, later
## e.g. "only even disks on this peg") is one RuleBase subclass. RuleSet combines
## the active rules; the Solver only talks to RuleSet and RuleBase, so adding a
## rule never touches the Solver.
##
## A rule that only needs the moving disk, the two pegs and the target's top
## disk should override is_disk_move_allowed() and return true from
## supports_disk_move_check(); is_move_allowed() then uses it automatically and
## the Solver can take its fast path. Rules that need more of the position
## override is_move_allowed() instead.


## Identifier used in level JSON, e.g. `"rules": ["classic_hanoi"]`.
func get_id() -> String:
	return ""


## Whether the top disk of `move.from_peg` may be placed on `move.to_peg`.
## RuleSet only calls this for structurally valid moves: both peg indices are in
## range, they differ, and the source peg is not empty.
func is_move_allowed(state: PuzzleState, move: Move) -> bool:
	return is_disk_move_allowed(state.get_top_disk(move.from_peg), move.from_peg, move.to_peg,
			state.get_top_disk(move.to_peg))


## Whether a whole position satisfies this rule. Used to validate level start
## and goal states; RuleSet has already checked the structure.
func is_state_valid(_state: PuzzleState) -> bool:
	return true


## The move decision from local facts only: `disk` moves from `from_peg` to
## `to_peg`, whose top disk is `target_top` (-1 when empty).
func is_disk_move_allowed(_disk: int, _from_peg: int, _to_peg: int, _target_top: int) -> bool:
	return true


## True if is_disk_move_allowed() fully decides this rule's moves. Rules that
## override is_move_allowed() to look at more of the position must return false.
func supports_disk_move_check() -> bool:
	return false


## True if this rule keeps every peg strictly decreasing from bottom to top
## (as long as the start position is). The Solver then describes a position
## just by which peg each disk is on.
func keeps_stacks_sorted() -> bool:
	return false
