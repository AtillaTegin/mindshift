class_name GameSession
extends RefCounted
## Play state of one level: current position, move count, selected peg, move
## history, undo and hints, elapsed time. Pure logic without nodes, shared by
## the board UI and the tests.

enum TapResult { SELECTED, DESELECTED, MOVED, ILLEGAL, IGNORED }

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

## Positions before each move in `history`, for undo.
var _previous_states: Array[PuzzleState] = []
## hash_key of each position along level.solution_path -> index of the next move.
var _path_index: Dictionary[String, int] = {}


func _init(p_level: Level) -> void:
	level = p_level
	rules = level.get_rule_set()
	var position: PuzzleState = level.start
	for i: int in level.solution_path.size():
		_path_index[position.hash_key()] = i
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
	if selected_peg == -1:
		if state.pegs[peg_index].is_empty():
			return TapResult.IGNORED
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
	_previous_states.append(state)
	state = next
	move_count += 1
	history.append(move)
	selected_peg = -1
	clock_started = true
	return true


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
	var key: String = state.hash_key()
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
