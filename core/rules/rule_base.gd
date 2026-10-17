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


## Translation key of why `disk` may not be picked up now (this rule holds it
## back); violation_message by default.
func pick_up_message(_disk: int, _facts: MoveFacts) -> String:
	return violation_message


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


## Every disk linked with `disk` (it included, smallest first) when the rules
## remember `memory`; [] for a free disk. They only ever move together, as one
## compound move. By default the pair of partner_of().
func group_of_with(disk: int, _memory: int) -> Array[int]:
	var partner: int = partner_of(disk)
	var group: Array[int] = []
	if partner != 0:
		group.assign([mini(disk, partner), maxi(disk, partner)])
	return group


## True when group_of_with() depends on the memory (a chain that breaks): the
## Solver then searches generically.
func groups_change() -> bool:
	return false


## True when the two disks of a linked pair may land on one peg, the larger
## first and the smaller on it ("Qırılan zəncir").
func allows_shared_target() -> bool:
	return false


## Whether a compound move may put its disks on `targets` (one peg per disk, in
## the move's order) together ("Rezin zəncir": two neighbouring pegs).
func compound_allowed(_targets: Array[int]) -> bool:
	return true


## The memory after the compound move of `disks` (each from `froms[i]` to
## `tos[i]`), `facts` being those before it; by default each disk in turn.
func compound_memory_after(facts: MoveFacts, disks: Array[int], froms: Array[int], tos: Array[int]) -> int:
	var before: int = facts.memory
	var memory: int = before
	for i: int in disks.size():
		facts.memory = memory
		memory = memory_after(facts, disks[i], froms[i], tos[i])
	facts.memory = before
	return memory


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


## Moves of a rule's own piece rather than a disk (the island's movable weight
## stone), written Move.new(peg, peg): legal now with `facts`. Such a move
## changes only the memory (special_memory_after); the Solver then searches
## generically.
func special_moves(_facts: MoveFacts) -> Array[Move]:
	return [] as Array[Move]


## True for a rule that has special moves at all.
func has_special_moves() -> bool:
	return false


## The memory after the special `move` (from special_moves()).
func special_memory_after(facts: MoveFacts, _move: Move) -> int:
	return facts.memory


## Whether the special move's button shows with `facts` (it may still be
## refused now, like a disk move): the stone not yet carried, the pass not yet
## spent.
func special_open(_facts: MoveFacts) -> bool:
	return false


## The translation key of the special move's button.
func special_label() -> String:
	return "STONE_MOVE"


## Peg orders that keep a puzzle under this rule the same puzzle (the
## similarity check, PuzzleIdentity): any order (pegs are only places), a row
## read either way, the turns of a dial, pairs kept together, or only the
## board's own order.
const PEGS_ANY: String = "any"
const PEGS_LINE: String = "line"
const PEGS_CIRCLE: String = "circle"
const PEGS_PAIRS: String = "pairs"
const PEGS_FIXED: String = "fixed"


## Which peg orders keep this rule's puzzles the same (PEGS_*).
func peg_symmetry() -> String:
	return PEGS_ANY


## What this rule's settings say about peg `peg_index` (a capacity, a seal, a
## key place), compared when pegs are reordered; null when nothing.
func peg_mark(_peg_index: int) -> Variant:
	return null


## This rule's settings without anything that names a peg (peg_mark() has it).
func params_without_pegs() -> Dictionary:
	return get_params()


## Relabelings of `disks` that keep a puzzle the same (the exchange's two
## colours swapped), each a map disk -> disk; none by default.
func disk_swaps(_disks: Array) -> Array[Dictionary]:
	return [] as Array[Dictionary]


## True for a rule that sets the level's goal itself: a condition on the
## position (the crowned disk on its gate, each peg's height or sum), not one
## position (ICRA World 5-9, section 2). At most one per RuleSet. The level's
## goal is then one position that meets it (where its stored solution ends);
## the Solver searches one way until a position meets the condition.
func defines_goal() -> bool:
	return false


## Whether the position `facts` describes meets this rule's goal condition
## (only asked of a rule whose defines_goal() is true).
func is_goal_with(_facts: MoveFacts) -> bool:
	return true


## True for a rule that only says what the goal is: it sets the goal itself
## (defines_goal) or marks the pegs of an exact goal (the king's odd and even
## towers), and limits no move. Such a rule is the puzzle's aim, so it need
## not make the solution longer (LevelForge.matters).
func only_aims() -> bool:
	return defines_goal()


## True for a rule under which a move may leave the goal out of reach for good
## (a move that cannot be taken back, e.g. a disk lifted off the other colour).
## Only then the board checks each new position (DeadEndWatcher) and offers a
## free way back from a dead end (Mod Kataloqu v1.1, D.3: nobody loses).
func can_dead_end() -> bool:
	return false


## True for a rule whose moves are not taken back by the opposite move (the
## dial goes round one way): alone it never dead-ends, but beside another rule
## that limits moves (a full peg on the way round) it can (RuleSet.can_dead_end,
## measured 2026-10-17 on capacity with the dial).
func moves_one_way() -> bool:
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
