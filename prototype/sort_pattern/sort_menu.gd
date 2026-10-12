extends Control
## Entry screen of the colour-order prototype: the rules, the move limit (it
## can be changed for testing; the level file starts it at the shortest
## solution + 2) and a start button. The limit choice lasts until the game
## closes and is never saved.

const BOARD_SCENE: String = "res://prototype/sort_pattern/sort_board.tscn"
## The limit can go this far above the shortest solution.
const MAX_SLACK: int = 20

var puzzle: SortPuzzle

@onready var _limit_label: Label = %LimitLabel
@onready var _minus: Button = %MinusButton
@onready var _plus: Button = %PlusButton
@onready var _play: Button = %PlayButton


func _ready() -> void:
	%TitleLabel.text = SortTexts.text("MENU_TITLE")
	%NoteLabel.text = SortTexts.text("MENU_NOTE")
	%RulesLabel.text = SortTexts.text("MENU_RULES")
	_play.text = SortTexts.text("MENU_PLAY")
	%BackButton.text = SortTexts.text("MENU_BACK_TO_GAME")
	_minus.text = "−"
	_plus.text = "+"
	_minus.pressed.connect(change_limit.bind(-1))
	_plus.pressed.connect(change_limit.bind(1))
	_play.pressed.connect(play)
	%BackButton.pressed.connect(_back_to_game)
	var errors: Array[String] = []
	puzzle = SortPuzzle.load_file(SortPuzzle.LEVEL_PATH, errors)
	if puzzle == null:
		%ShortestLabel.text = SortTexts.text("LOAD_ERROR") % "; ".join(errors)
		_play.disabled = true
		_minus.disabled = true
		_plus.disabled = true
		return
	%ShortestLabel.text = SortTexts.text("MENU_SHORTEST") % puzzle.min_moves
	_update_limit()


## The limit the board will use: the menu's choice, else the level's own.
func current_limit() -> int:
	return SortSession.limit_override if SortSession.limit_override > 0 else puzzle.move_limit


func change_limit(step: int) -> void:
	var limit: int = clampi(current_limit() + step, puzzle.min_moves, puzzle.min_moves + MAX_SLACK)
	SortSession.limit_override = 0 if limit == puzzle.move_limit else limit
	_update_limit()


func play() -> void:
	_go(BOARD_SCENE)


func _update_limit() -> void:
	var limit: int = current_limit()
	_limit_label.text = SortTexts.text("MENU_LIMIT") % limit
	_minus.disabled = limit <= puzzle.min_moves
	_plus.disabled = limit >= puzzle.min_moves + MAX_SLACK


func _back_to_game() -> void:
	var app: Node = get_node_or_null("/root/App")
	if app != null:
		app.show_main_menu()


func _go(scene_path: String) -> void:
	var transition: Node = get_node_or_null("/root/ScreenTransition")
	if transition != null:
		transition.change_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)
