class_name TutorialDirector
extends Node
## Coaching on the first two levels (addendum 2.2). The steps are not written
## by hand: they come from the level's own solution_path, read with the same
## GameSession.get_path_hint() the hint uses, and they are drawn with the same
## MoveCoach on the shared coaching overlay.
##
## - Level 1 (easy_001), GUIDED: each move is shown, first the disk, then (once
##   picked up) the target peg with a ghost finger. Only the shown peg reacts
##   to taps. "Əla!" after every move.
## - Level 2 (easy_002), FREE: any peg can be tapped. One "try it yourself"
##   toast at the start; a refused move shows the broken rule's own message.
## - Other levels: off. A tutorial only runs until its level was completed once.

enum Mode { OFF, GUIDED, FREE }

const GUIDED_LEVEL_ID: int = 1001
const FREE_LEVEL_ID: int = 1002
const STEP_DONE_TEXT: String = "Əla!"
const TRY_YOURSELF_TEXT: String = "İndi özün sına!"

var enabled: bool = true
var mode: Mode = Mode.OFF
## The move the guided tutorial is showing, or null.
var step_move: Move

var _board: GameBoard
var _coaching: CoachingLayer
var _save: SaveSystem
var _last_move_count: int = 0


func setup(board: GameBoard, coaching: CoachingLayer, save: SaveSystem) -> void:
	_board = board
	_coaching = coaching
	_save = save
	board.level_started.connect(_on_level_started)
	board.position_changed.connect(_on_position_changed)
	board.selection_changed.connect(_on_selection_changed)
	board.illegal_move.connect(_on_illegal_move)
	board.layout_changed.connect(_on_layout_changed)


func _on_level_started() -> void:
	_stop()
	var level: Level = _board.session.level
	_last_move_count = _board.session.move_count
	if not enabled or _save.is_completed(level.id):
		return
	if level.id == GUIDED_LEVEL_ID:
		mode = Mode.GUIDED
		_show_next_step()
	elif level.id == FREE_LEVEL_ID:
		mode = Mode.FREE
		_coaching.toast.show_message(TRY_YOURSELF_TEXT)


func _on_position_changed() -> void:
	var moves: int = _board.session.move_count
	if mode == Mode.GUIDED and moves > _last_move_count:
		_coaching.toast.show_message(STEP_DONE_TEXT)
		_last_move_count = moves
		_show_next_step()
	_last_move_count = moves


func _on_selection_changed(peg_index: int) -> void:
	if mode == Mode.GUIDED and step_move != null and peg_index == step_move.from_peg:
		MoveCoach.present(_coaching, _board, step_move, true)
		_board.restricted_peg = step_move.to_peg


func _on_illegal_move(_move: Move, message: String) -> void:
	if mode == Mode.FREE and not message.is_empty():
		_coaching.toast.show_message(message)


func _on_layout_changed() -> void:
	if mode == Mode.GUIDED and step_move != null:
		MoveCoach.present(_coaching, _board, step_move, _board.session.selected_peg == step_move.from_peg)


func _show_next_step() -> void:
	var session: GameSession = _board.session
	step_move = null if session.is_solved() else session.get_path_hint()
	if step_move == null:
		_stop()
		return
	MoveCoach.present(_coaching, _board, step_move, false)
	_board.restricted_peg = step_move.from_peg


## Ends any running tutorial: overlay off, all pegs tappable again.
func _stop() -> void:
	mode = Mode.OFF
	step_move = null
	_coaching.clear()
	_board.restricted_peg = -1
