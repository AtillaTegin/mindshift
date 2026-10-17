class_name GameSession
extends RefCounted
## Play state of one level: current position, move count, selected peg, move
## history, undo and hints, elapsed time. Pure logic without nodes, shared by
## the board UI and the tests.

## BLOCKED: the top disk of the tapped peg may not be picked up right now.
## OPENED: the tap opened a closed karakuri box (nothing else happened).
## TARGETED: the first target of a linked pair was chosen; the partner's next.
enum TapResult { SELECTED, DESELECTED, MOVED, ILLEGAL, IGNORED, BLOCKED, OPENED, TARGETED }

## Search budget for hints off the stored solution path. The packed solver
## stays far below it for every shipped level size.
const HINT_MAX_STATES: int = 2000000
## Search budget of the dead-end check (DeadEndWatcher). A dead end is proved
## when the search runs dry without reaching the goal; the dead regions of the
## mixed exchange hold ~10 positions (measured 2026-10-16), so a search still
## going at this size counts as alive, and the check stays quick on any board.
const DEAD_END_MAX_STATES: int = 20000

var level: Level
var rules: RuleSet
var state: PuzzleState
## Moves on the board right now: an undo takes its move back off the count.
var move_count: int = 0
## Peg whose top disk is picked up, or -1.
var selected_peg: int = -1
## Linked disks (RuleBase.group_of_with): the targets already chosen, in the
## order of get_selected_disks(), while the others' are still to come.
var pending_targets: Array[int] = []
## The first chosen target of a linked group, or -1.
var pending_target: int:
	get:
		return pending_targets[0] if not pending_targets.is_empty() else -1
var history: Array[Move] = []
var undo_count: int = 0
## Play time of this attempt. The clock starts with the first move (thinking
## before it is free) and stops when the level is solved.
var elapsed_seconds: float = 0.0
var clock_started: bool = false
## Karakuri boxes (cultural integration addendum, section 2): the level's
## covered pegs start as closed boxes that hide their whole stack, even how many
## disks it holds. The first tap on a box opens its top layer: only the top disk
## shows. Whenever a box's top disk leaves, the disk under it shows. Disks put
## onto a box stay visible. Nothing comes back on undo; restart closes every box
## again. Presentation only: rules, Solver and stars never see it. Never saved.
## Closed boxes:
var covered_pegs: Array[int] = []

## Chapter waves v1: a sealed box (SealedBoxRule) never opens on a tap, only
## once the smallest disk is put on its lid; a "reclosing" level's boxes close
## again after RECLOSE_AFTER moves that leave them alone (the karakuri
## island's sub-element).
const RECLOSE_AFTER: int = 3

## Opened box peg -> how many disks at its bottom are still hidden.
var _hidden: Dictionary[int, int] = {}
## Opened box peg -> move count when a move last used it (reclosing levels).
var _touched: Dictionary[int, int] = {}
var _sealed_rule: SealedBoxRule
## Güzgü's echo (RuleBase.echo_of): the move the last move made happen on the
## other board, or null; `echo_blocked` when the last move should have echoed
## but could not.
var last_echo: Move
var echo_blocked: bool = false
## Positions before each move in `history`, for undo.
var _previous_states: Array[PuzzleState] = []
## _path_key of each position along level.solution_path -> index of the next
## move (the key includes the last moved disk when a rule depends on it).
var _path_index: Dictionary[String, int] = {}


func _init(p_level: Level) -> void:
	level = p_level
	rules = level.get_rule_set()
	for rule: RuleBase in rules.active_rules:
		if rule is SealedBoxRule:
			_sealed_rule = rule
	var position: PuzzleState = level.start
	for i: int in level.solution_path.size():
		_path_index[_path_key(position)] = i
		position = rules.apply_move(position, level.solution_path[i])
		if position == null:
			break
	restart()


func restart() -> void:
	state = level.start.duplicate_state()
	move_count = 0
	selected_peg = -1
	pending_targets.clear()
	history.clear()
	_previous_states.clear()
	undo_count = 0
	elapsed_seconds = 0.0
	clock_started = false
	covered_pegs = level.covered_pegs.duplicate()
	_hidden.clear()
	_touched.clear()
	last_echo = null
	echo_blocked = false


func is_solved() -> bool:
	return level.is_goal_met(state, rules)


## Top disk of the selected peg, or -1 when nothing is selected.
func get_selected_disk() -> int:
	return state.get_top_disk(selected_peg) if selected_peg != -1 else -1


## Every disk picked up with the selected peg: its top disk and, for a linked
## disk (RuleBase.group_of_with), the others of its group, smallest first;
## empty when nothing is selected.
func get_selected_disks() -> Array[int]:
	var disks: Array[int] = []
	if selected_peg == -1:
		return disks
	disks.append(get_selected_disk())
	for member: int in rules.group_of(disks[0], state):
		if member != disks[0]:
			disks.append(member)
	return disks


## The pegs of get_selected_disks(), in its order.
func get_selected_pegs() -> Array[int]:
	var pegs: Array[int] = []
	for disk: int in get_selected_disks():
		for peg_index: int in state.get_peg_count():
			if state.get_top_disk(peg_index) == disk:
				pegs.append(peg_index)
	return pegs


## The peg of the partner of the selected linked disk (the next one of its
## group), or -1.
func get_partner_peg() -> int:
	var pegs: Array[int] = get_selected_pegs()
	return pegs[1] if pegs.size() > 1 else -1


## A tap on a peg. With nothing selected it picks up that peg's top disk; a
## second tap on the same peg puts it back; a tap on another peg moves it there.
## An illegal target keeps the selection so the player can pick another peg.
## A linked disk lifts the others of its group too: each next tap names one
## disk's target (TARGETED), the tapped disk's first, and once the last one
## has its target the compound move is tried.
func tap_peg(peg_index: int) -> TapResult:
	if is_solved() or peg_index < 0 or peg_index >= state.get_peg_count():
		return TapResult.IGNORED
	if open_box(peg_index):
		return TapResult.OPENED
	if selected_peg == -1:
		if state.pegs[peg_index].is_empty():
			return TapResult.IGNORED
		if not rules.can_pick_up(state, peg_index):
			return TapResult.BLOCKED
		selected_peg = peg_index
		pending_targets.clear()
		return TapResult.SELECTED
	if peg_index == selected_peg and pending_targets.is_empty():
		selected_peg = -1
		return TapResult.DESELECTED
	var pegs: Array[int] = get_selected_pegs()
	if pegs.size() > 1:
		if pending_targets.size() < pegs.size() - 1:
			pending_targets.append(peg_index)
			return TapResult.TARGETED
		var targets: Array[int] = pending_targets.duplicate()
		targets.append(peg_index)
		pending_targets.clear()
		if try_move(Move.of_parts(pegs, targets)):
			return TapResult.MOVED
		return TapResult.ILLEGAL
	if try_move(Move.new(selected_peg, peg_index)):
		return TapResult.MOVED
	return TapResult.ILLEGAL


## Applies `move` if it is legal; returns whether it was.
func try_move(move: Move) -> bool:
	if is_solved():
		return false
	var next: PuzzleState = rules.apply_move(state, move)
	if next == null:
		return false
	last_echo = rules.echo_for(state, move) if rules.has_echo() else null
	echo_blocked = rules.has_echo() and last_echo == null
	# A move by code (hint, tests) through a closed box opens it first.
	open_box(move.from_peg)
	open_box(move.to_peg)
	_previous_states.append(state)
	state = next
	move_count += 1
	history.append(move)
	selected_peg = -1
	pending_targets.clear()
	clock_started = true
	# The smallest disk on a sealed lid breaks the seal: the box opens.
	open_box(move.to_peg)
	_reveal_tops()
	_reclose(move)
	return true


## Whether `peg_index` is a closed box.
func is_covered(peg_index: int) -> bool:
	return covered_pegs.has(peg_index)


## Disks of `peg_index` the player cannot see: its whole stack while the box is
## closed, then the ones still hidden at its bottom; 0 for an ordinary peg.
func hidden_count(peg_index: int) -> int:
	if is_covered(peg_index):
		return state.pegs[peg_index].size()
	return _hidden.get(peg_index, 0)


## Opens the closed box on `peg_index`: its top disk shows. False if it was no
## closed box, or a sealed one.
func open_box(peg_index: int) -> bool:
	if not is_covered(peg_index) or is_sealed(peg_index):
		return false
	covered_pegs.erase(peg_index)
	_hidden[peg_index] = maxi(state.pegs[peg_index].size() - 1, 0)
	_touched[peg_index] = move_count
	return true


## Whether `peg_index` is a box still under its seal (SealedBoxRule).
func is_sealed(peg_index: int) -> bool:
	return _sealed_rule != null and _sealed_rule.is_sealed(rules.memory_of(state), peg_index)


## A reclosing level: each opened box that `move` left alone for
## RECLOSE_AFTER moves closes again, hiding its whole stack once more.
func _reclose(move: Move) -> void:
	if not level.variants.has("reclosing"):
		return
	for peg_index: int in level.covered_pegs:
		if is_covered(peg_index):
			continue
		if peg_index in [move.from_peg, move.to_peg, move.from_peg_2, move.to_peg_2]:
			_touched[peg_index] = move_count
		elif move_count - _touched.get(peg_index, move_count) >= RECLOSE_AFTER and not state.pegs[peg_index].is_empty():
			covered_pegs.append(peg_index)
			_hidden.erase(peg_index)


## A hidden disk that has become the top of its box shows.
func _reveal_tops() -> void:
	for peg_index: int in _hidden:
		if _hidden[peg_index] > 0 and state.pegs[peg_index].size() <= _hidden[peg_index]:
			_hidden[peg_index] = maxi(state.pegs[peg_index].size() - 1, 0)


## The position before the last move, or null at the start.
func previous_state() -> PuzzleState:
	return _previous_states[-1] if not _previous_states.is_empty() else null


func can_undo() -> bool:
	return not history.is_empty() and not is_solved()


## Takes back the last move (position and move count). Returns false if there
## is nothing to undo or the level is already solved.
func undo() -> bool:
	if not can_undo():
		return false
	state = _previous_states.pop_back()
	history.pop_back()
	move_count -= 1
	undo_count += 1
	last_echo = null
	echo_blocked = false
	selected_peg = -1
	pending_targets.clear()
	_reveal_tops()
	return true


## The position after the first `moves` moves of the history (0: the start).
func position_after(moves: int) -> PuzzleState:
	return state if moves >= history.size() else _previous_states[moves]


## The dead-end rule's free way back: takes moves back until `moves` are left.
## Not an undo (nothing counted, nothing paid). False if there is nothing to
## take back or the level is solved.
func rewind_to(moves: int) -> bool:
	if moves < 0 or moves >= history.size() or is_solved():
		return false
	state = _previous_states[moves]
	_previous_states.resize(moves)
	history.resize(moves)
	move_count = moves
	last_echo = null
	echo_blocked = false
	selected_peg = -1
	pending_targets.clear()
	_reveal_tops()
	return true


## Whether `from_state` is a dead end of `level`: the goal is out of reach for
## good. Proved only when the search runs dry (DEAD_END_MAX_STATES); a search
## that stops at its budget counts as alive. Only reads its arguments (worker
## thread safe).
static func is_dead_end(level: Level, from_state: PuzzleState, rule_set: RuleSet) -> bool:
	var result: Dictionary = Solver.solve(from_state, level.goal, rule_set, DEAD_END_MAX_STATES)
	return not result["solvable"] and not result["limit_reached"]


## The index of the first dead end in `line`, positions one move apart in play
## order, or -1. Once a position is a dead end every later one is too, so the
## last is checked first and the first one found by halving.
static func first_dead_end(level: Level, line: Array[PuzzleState], rule_set: RuleSet) -> int:
	if line.is_empty() or not is_dead_end(level, line[-1], rule_set):
		return -1
	var low: int = 0
	var high: int = line.size() - 1
	while low < high:
		var middle: int = (low + high) / 2
		if is_dead_end(level, line[middle], rule_set):
			high = middle
		else:
			low = middle + 1
	return high


## Spec 4.7: the next move of a shortest solution from the current position.
## On the stored solution path the answer is read from it; off the path the
## Solver is run from here. Returns { move: Move or null, from_path: bool };
## move is null when solved or when no solution is found.
func get_hint() -> Dictionary:
	if is_solved():
		return {"move": null, "from_path": false}
	var on_path: Move = get_path_hint()
	if on_path != null:
		return {"move": on_path, "from_path": true}
	return {"move": solve_hint(level, state.duplicate_state(), rules), "from_path": false}


## The next move of the stored solution if the current position lies on it,
## otherwise null. Instant: no search.
func get_path_hint() -> Move:
	var key: String = _path_key(state)
	return level.solution_path[_path_index[key]] if _path_index.has(key) else null


## A hint when the search finds none: off the stored path, the last move taken
## back, which leads to a position on the path in the end (the start is on
## it). Only where that move is legal and really restores the position before,
## memory included: a disk lifted off another colour or one that may not
## return to a peg cannot always go back (then undo() helps). Null on the path,
## with nothing moved, or when the last move cannot be reversed.
func return_to_path_move() -> Move:
	if history.is_empty() or _path_index.has(_path_key(state)):
		return null
	var last: Move = history[-1]
	var back: Move = Move.of_parts(last.tos(), last.froms())
	var before: PuzzleState = rules.apply_move(state, back)
	return back if before != null and _path_key(before) == _path_key(_previous_states[-1]) else null


## What makes two positions the same for the stored solution: the search key
## (the last moved disk and the memory included where a rule needs them).
func _path_key(position: PuzzleState) -> String:
	return rules.search_key(position)


## First move of a shortest solution of `level` from `from_state`, or null.
## Null also when no solution is left (a dead end of a level whose moves cannot
## all be taken back); then return_to_path_move() or an undo helps. Only reads
## its arguments, so it can run on a worker thread.
static func solve_hint(level: Level, from_state: PuzzleState, rule_set: RuleSet) -> Move:
	var result: Dictionary = Solver.solve(from_state, level.goal, rule_set, HINT_MAX_STATES)
	return result["path"][0] if result["solvable"] and not result["path"].is_empty() else null


## Stopwatch text, e.g. "01:07" (whole seconds, rounded down; minutes keep
## counting past 59).
static func format_clock(seconds: float) -> String:
	var whole: int = maxi(floori(seconds), 0)
	return "%02d:%02d" % [whole / 60, whole % 60]


## Counts play time from the first move until the level is solved.
func add_time(delta: float) -> void:
	if clock_started and not is_solved():
		elapsed_seconds += delta
