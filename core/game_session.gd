class_name GameSession
extends RefCounted
## Play state of one level: current position, move count, selected peg, move
## history, undo and hints, elapsed time. Pure logic without nodes, shared by
## the board UI and the tests.

## BLOCKED: the top disk of the tapped peg may not be picked up right now.
## OPENED: the tap opened a closed karakuri box (nothing else happened).
enum TapResult { SELECTED, DESELECTED, MOVED, ILLEGAL, IGNORED, BLOCKED, OPENED }

## Search budget for hints off the stored solution path. The packed solver
## stays far below it for every shipped level size.
const HINT_MAX_STATES: int = 2000000

var level: Level
var rules: RuleSet
var state: PuzzleState
## Moves on the board right now: an undo takes its move back off the count.
var move_count: int = 0
## Peg whose top disk is picked up, or -1.
var selected_peg: int = -1
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

## Opened box peg -> how many disks at its bottom are still hidden.
var _hidden: Dictionary[int, int] = {}
## Positions before each move in `history`, for undo.
var _previous_states: Array[PuzzleState] = []
## RuleSet.search_key of each position along level.solution_path -> index of the
## next move (the key includes the last moved disk when a rule depends on it).
var _path_index: Dictionary[String, int] = {}


func _init(p_level: Level) -> void:
	level = p_level
	rules = level.get_rule_set()
	var position: PuzzleState = level.start
	for i: int in level.solution_path.size():
		_path_index[rules.search_key(position)] = i
		position = rules.apply_move(position, level.solution_path[i])
		if position == null:
			break
	restart()


func restart() -> void:
	state = level.start.duplicate_state()
	move_count = 0
	selected_peg = -1
	history.clear()
	_previous_states.clear()
	undo_count = 0
	elapsed_seconds = 0.0
	clock_started = false
	covered_pegs = level.covered_pegs.duplicate()
	_hidden.clear()


func is_solved() -> bool:
	return rules.is_goal_state(state, level.goal)


## Top disk of the selected peg, or -1 when nothing is selected.
func get_selected_disk() -> int:
	return state.get_top_disk(selected_peg) if selected_peg != -1 else -1


## A tap on a peg. With nothing selected it picks up that peg's top disk; a
## second tap on the same peg puts it back; a tap on another peg moves it there.
## An illegal target keeps the selection so the player can pick another peg.
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
		return TapResult.SELECTED
	if peg_index == selected_peg:
		selected_peg = -1
		return TapResult.DESELECTED
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
	# A move by code (hint, tests) through a closed box opens it first.
	open_box(move.from_peg)
	open_box(move.to_peg)
	_previous_states.append(state)
	state = next
	move_count += 1
	history.append(move)
	selected_peg = -1
	clock_started = true
	_reveal_tops()
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
## closed box.
func open_box(peg_index: int) -> bool:
	if not is_covered(peg_index):
		return false
	covered_pegs.erase(peg_index)
	_hidden[peg_index] = maxi(state.pegs[peg_index].size() - 1, 0)
	return true


## A hidden disk that has become the top of its box shows.
func _reveal_tops() -> void:
	for peg_index: int in _hidden:
		if _hidden[peg_index] > 0 and state.pegs[peg_index].size() <= _hidden[peg_index]:
			_hidden[peg_index] = maxi(state.pegs[peg_index].size() - 1, 0)


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
	selected_peg = -1
	_reveal_tops()
	return true


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
	return {"move": solve_hint(state.duplicate_state(), level.goal, rules), "from_path": false}


## The next move of the stored solution if the current position lies on it,
## otherwise null. Instant: no search.
func get_path_hint() -> Move:
	var key: String = rules.search_key(state)
	return level.solution_path[_path_index[key]] if _path_index.has(key) else null


## First move of a shortest solution from `from_state`, or null. Touches only
## its arguments, so it can run on a worker thread.
static func solve_hint(from_state: PuzzleState, goal: PuzzleState, rule_set: RuleSet) -> Move:
	var result: Dictionary = Solver.solve(from_state, goal, rule_set, HINT_MAX_STATES)
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
