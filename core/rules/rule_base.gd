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
## the Solver then keeps that disk in its search state.
##
## A rule that judges by more of the position (how many disks a peg holds, the
## sum of their sizes, where a disk is) returns true from needs_facts() and
## overrides is_move_allowed_with(), which gets a MoveFacts. A rule that must
## remember something beyond the position (a lock that opened, the pegs a disk
## visited) returns true from uses_memory() and keeps it in PuzzleState.memory
## through start_memory() and memory_after(). Two linked disks that only move
## together are named by partner_of(); peg groups that never exchange disks by
## peg_groups(). The Solver handles all of these generically and never names a
## rule.


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


## is_disk_movable() knowing the whole MoveFacts (a rule with memory, e.g. a
## lock that has not opened yet). Defaults to is_disk_movable().
func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	return is_disk_movable(disk, facts.last_disk)


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


## The move decision knowing the MoveFacts of the position the move starts
## from. Only rules with needs_facts() or uses_memory() need to override it.
func is_move_allowed_with(disk: int, from_peg: int, to_peg: int, target_top: int, facts: MoveFacts) -> bool:
	return is_disk_move_allowed_after(disk, from_peg, to_peg, target_top, facts.last_disk)


## True if this rule looks at the disk that moved last.
func uses_last_move() -> bool:
	return false


## True if is_move_allowed_with() needs the MoveFacts beyond the last disk.
func needs_facts() -> bool:
	return false


## True if this rule keeps a memory in PuzzleState.memory. At most one rule
## of a RuleSet may (RuleSet.from_ids checks it).
func uses_memory() -> bool:
	return false


## How many different memory values there can be on a board of this size (the
## memory runs from 0 to this minus one).
func memory_states(_peg_count: int, _disk_count: int) -> int:
	return 1


## The memory a level starts with in position `state`.
func start_memory(_state: PuzzleState) -> int:
	return 0


## The memory after `disk` moved from `from_peg` to `to_peg`, `facts` being
## those of the position before the move.
func memory_after(facts: MoveFacts, _disk: int, _from_peg: int, _to_peg: int) -> int:
	return facts.memory


## The disk linked to `disk` (they only ever move together, as one compound
## move), or 0 for a free disk.
func partner_of(_disk: int) -> int:
	return 0


## Groups of pegs that never exchange disks (each group a separate board); the
## Solver then solves every group on its own. Empty for one board.
func peg_groups(_peg_count: int) -> Array[Array]:
	return [] as Array[Array]


## A move that follows the player's `move` by itself (Güzgü's echo on the
## other board), or null. RuleSet applies it right after `move` on the
## position `after` when it is possible there (a top disk onto an empty peg
## or a larger one); otherwise nothing follows. The Solver then searches
## generically.
func echo_of(_after: PuzzleState, _move: Move) -> Move:
	return null


## True for a rule whose moves echo (echo_of).
func echoes() -> bool:
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
