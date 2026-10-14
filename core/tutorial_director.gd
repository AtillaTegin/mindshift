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
## - The first level of each mechanic on the main path (level structure v4,
##   section 2): the mechanic's own words first (INTRO_TEXTS, kept on screen
##   for INTRO_SECONDS), then its first INTRO_STEPS moves guided like level 1,
##   then FREE as on level 2. Karakuri boxes need no extra step: the first
##   moves use a box, and a tap on the shown box opens it. The great exchange's
##   two kinds are two lessons (Level.lesson()): each one's first level.
## - Other levels: off. A tutorial only runs until its level was completed once.

enum Mode { OFF, GUIDED, FREE }

const GUIDED_LEVEL_ID: int = 1001
const FREE_LEVEL_ID: int = 1002
## Translation keys of the toasts.
const STEP_DONE_TEXT: String = "TUTORIAL_STEP_DONE"
const TRY_YOURSELF_TEXT: String = "TUTORIAL_TRY_YOURSELF"
## Level.lesson() -> what is new about it.
const INTRO_TEXTS: Dictionary = {
	"covered_pegs": "INTRO_COVERED_PEGS",
	"alternation": "INTRO_ALTERNATION",
	"adjacent_pegs": "INTRO_ADJACENT_PEGS",
	"color_swap": "INTRO_COLOR_SWAP",
	"color_swap_mixed": "INTRO_COLOR_SWAP_MIXED",
	"combination": "INTRO_COMBINATION",
}
const INTRO_STEPS: int = 3
const INTRO_SECONDS: float = 5.0

var enabled: bool = true
var mode: Mode = Mode.OFF
## The move the guided tutorial is showing, or null.
var step_move: Move
## The mechanic being introduced ("" outside an introduction).
var intro_mechanic: String = ""
var _intro_steps_left: int = 0

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
	intro_mechanic = ""
	_intro_steps_left = 0
	var level: Level = _board.session.level
	_last_move_count = _board.session.move_count
	if not enabled or _save.is_completed(level.id):
		return
	if level.id == GUIDED_LEVEL_ID:
		mode = Mode.GUIDED
		_show_next_step()
	elif level.id == FREE_LEVEL_ID:
		mode = Mode.FREE
		_coaching.toast.show_message(tr(TRY_YOURSELF_TEXT))
	elif is_mechanic_intro(level):
		intro_mechanic = level.lesson()
		_intro_steps_left = INTRO_STEPS
		mode = Mode.GUIDED
		# At the top: the words stay readable while the ghost finger works below.
		_coaching.toast.show_message(tr(INTRO_TEXTS[intro_mechanic]), INTRO_SECONDS, true)
		_show_next_step()


## Whether `level` is the first level of its lesson on the main path.
static func is_mechanic_intro(level: Level) -> bool:
	var lesson: String = level.lesson()
	if not INTRO_TEXTS.has(lesson):
		return false
	var place: Dictionary = LevelCatalog.place_of(level.id)
	return place.get("track", "") == LevelCatalog.MAIN and place["position"] == LevelCatalog.first_main_position(lesson)


func _on_position_changed() -> void:
	var moves: int = _board.session.move_count
	if mode == Mode.GUIDED and moves > _last_move_count:
		_last_move_count = moves
		if intro_mechanic.is_empty():
			_coaching.toast.show_message(tr(STEP_DONE_TEXT))
			_show_next_step()
		else:
			# An introduction keeps its words on screen while it guides, then
			# hands over: "well done, now on your own".
			_intro_steps_left -= 1
			if _intro_steps_left > 0:
				_show_next_step()
			else:
				_stop()
				mode = Mode.FREE
				_coaching.toast.show_message("%s %s" % [tr(STEP_DONE_TEXT), tr(TRY_YOURSELF_TEXT)])
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
