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
##
## A rule that also depends on which disk moved last (PuzzleState.last_moved_disk)
## returns true from uses_last_move() and overrides is_disk_move_allowed_after();
## the Solver then keeps that disk in its search state. No rule is ever named
## in the Solver.


## Translation key of the text shown when this rule refuses a move (addendum
## 2.2). Each rule sets its own, so new rules explain themselves without UI
## changes; add the key to locale/az.po.
var violation_message: String = "RULE_ILLEGAL_MOVE"


## Identifier used in level JSON, e.g. `"rules": ["classic_hanoi"]`.
func get_id() -> String:
	return ""


## Translation key of why this rule refuses `move` (a rule that can refuse for
## more than one reason names the one that applies); violation_message by default.
func get_violation_message(_state: PuzzleState, _move: Move) -> String:
	return violation_message


## A rule that judges moves by disk colour gets the level's disk colours here
## (Level.disk_colors: the colour of disk id i at i - 1); others ignore them.
func bind_disk_colours(_colours: Array[String]) -> void:
	pass


## How many disks `move` carries from the top of its source (the others go
## along in the order they stand). 1 for most rules; a rule that moves a group
## returns more. RuleSet uses the largest any rule asks for.
func disks_moved(_state: PuzzleState, _move: Move) -> int:
	return 1


## How many top disks of `stack` are picked up together (and shown lifted):
## the most a move from it could carry. 1 for most rules.
func disks_picked_up(_stack: Array) -> int:
	return 1


## Takes this rule's settings from the level JSON `"rule_params": { "<id>": {...} }`
## (an empty Dictionary when the level gives none). Returns "" when they are
## fine, otherwise what is wrong. Rules without settings accept only {}.
func configure(params: Dictionary) -> String:
	return "" if params.is_empty() else "rule \"%s\" takes no parameters" % get_id()


## The settings to write back to the level JSON ({} for none).
func get_params() -> Dictionary:
	return {}


## Whether `disk` may be picked up now, `last_disk` having moved last (0: none).
## A rule that holds a disk back returns false here (the UI then refuses the
## tap) and also in its move check (so every search sees the same rule).
func is_disk_movable(_disk: int, _last_disk: int) -> bool:
	return true


## Whether the top disk of `move.from_peg` may be placed on `move.to_peg`.
## RuleSet only calls this for structurally valid moves: both peg indices are in
## range, they differ, and the source peg is not empty.
func is_move_allowed(state: PuzzleState, move: Move) -> bool:
	return is_disk_move_allowed_after(state.get_top_disk(move.from_peg), move.from_peg, move.to_peg,
			state.get_top_disk(move.to_peg), state.last_moved_disk)


## Whether a whole position satisfies this rule. Used to validate level start
## and goal states; RuleSet has already checked the structure.
func is_state_valid(_state: PuzzleState) -> bool:
	return true


## The move decision from local facts only: `disk` moves from `from_peg` to
## `to_peg`, whose top disk is `target_top` (-1 when empty).
func is_disk_move_allowed(_disk: int, _from_peg: int, _to_peg: int, _target_top: int) -> bool:
	return true


## is_disk_move_allowed() knowing that `last_disk` moved last (0: none yet).
## Only rules with uses_last_move() need to override it.
func is_disk_move_allowed_after(disk: int, from_peg: int, to_peg: int, target_top: int, _last_disk: int) -> bool:
	return is_disk_move_allowed(disk, from_peg, to_peg, target_top)


## True if this rule looks at the disk that moved last.
func uses_last_move() -> bool:
	return false


## True if is_disk_move_allowed_after() fully decides this rule's moves. Rules that
## override is_move_allowed() to look at more of the position must return false.
func supports_disk_move_check() -> bool:
	return false


## True if this rule keeps every peg strictly decreasing from bottom to top
## (as long as the start position is). The Solver then describes a position
## just by which peg each disk is on.
func keeps_stacks_sorted() -> bool:
	return false
