class_name GameSession
extends RefCounted
## Play state of one level: current position, move count, selected peg, move
## history and elapsed time. Pure logic without nodes, shared by the board UI
## and the tests.

enum TapResult { SELECTED, DESELECTED, MOVED, ILLEGAL, IGNORED }

var level: Level
var rules: RuleSet
var state: PuzzleState
var move_count: int = 0
## Peg whose top disk is picked up, or -1.
var selected_peg: int = -1
var history: Array[Move] = []
var elapsed_seconds: float = 0.0


func _init(p_level: Level) -> void:
	level = p_level
	rules = level.get_rule_set()
	restart()


func restart() -> void:
	state = level.start.duplicate_state()
	move_count = 0
	selected_peg = -1
	history.clear()
	elapsed_seconds = 0.0


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
	state = next
	move_count += 1
	history.append(move)
	selected_peg = -1
	return true


## Counts play time until the level is solved.
func add_time(delta: float) -> void:
	if not is_solved():
		elapsed_seconds += delta
