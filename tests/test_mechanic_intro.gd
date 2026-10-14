extends "res://tests/test_case.gd"
## Level structure v4, section 2: the first level of every mechanic on the main
## path opens with the level-1 way of guiding: the mechanic's own words, its
## first moves shown with the ghost finger (only the shown peg reacts), then
## free play where a refused move says which rule it broke.

const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const SAVE_PATH: String = "res://.test_saves/test_mechanic_intro_save.json"
const MAIN: String = LevelCatalog.MAIN

var _board: GameBoard
var _save: SaveSystem


func before_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save = SaveSystem.new(SAVE_PATH)


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _open(position: int) -> void:
	if _board == null:
		_board = BOARD_SCENE.instantiate()
		_board.save_system = _save
		_board.background_hints = false
		_board.level_path = ""
		(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.start_level(LevelCatalog.load_at(MAIN, position))
	(_board.get_node("%Board") as Control).size = Vector2(672.0, 700.0)


## Taps a peg until the tap does more than open a karakuri box.
func _tap(peg: int) -> void:
	while _board.session.is_covered(peg):
		_board.on_peg_pressed(peg)
	_board.on_peg_pressed(peg)


func test_every_mechanic_is_introduced_on_its_first_level() -> void:
	for mechanic: String in TutorialDirector.INTRO_TEXTS:
		var first: int = LevelCatalog.first_main_position(mechanic)
		assert_true(first > 0, "%s is on the road" % mechanic)
		_open(first)
		var tutorial: TutorialDirector = _board.tutorial
		var session: GameSession = _board.session
		assert_eq(tutorial.mode, TutorialDirector.Mode.GUIDED, mechanic)
		assert_eq(tutorial.intro_mechanic, mechanic)
		assert_eq(_board.coaching.toast.get_text(), tr(TutorialDirector.INTRO_TEXTS[mechanic]), "%s explains itself" % mechanic)
		var path: Array[Move] = session.level.solution_path
		for k: int in TutorialDirector.INTRO_STEPS:
			assert_eq(tutorial.mode, TutorialDirector.Mode.GUIDED, "%s step %d" % [mechanic, k])
			assert_true(tutorial.step_move.equals(path[k]), "%s step %d comes from the solution" % [mechanic, k])
			assert_eq(_board.restricted_peg, path[k].from_peg, "only the shown peg reacts")
			assert_true(_board.coaching.pointer.visible, "the ghost finger shows the move")
			_tap(path[k].from_peg)
			assert_eq(_board.restricted_peg, path[k].to_peg)
			_tap(path[k].to_peg)
			assert_eq(session.move_count, k + 1, "%s step %d made" % [mechanic, k])
		assert_eq(tutorial.mode, TutorialDirector.Mode.FREE, "%s: then free play" % mechanic)
		assert_eq(_board.restricted_peg, -1)
		assert_true(_board.coaching.toast.get_text().contains(tr(TutorialDirector.TRY_YOURSELF_TEXT)))


func test_only_the_first_level_of_a_mechanic_and_only_until_completed() -> void:
	var first: int = LevelCatalog.first_main_position("adjacent_pegs")
	var second: int = 0
	for position: int in range(first + 1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == "adjacent_pegs":
			second = position
			break
	_open(second)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF, "the second caravan level plays on its own")
	_open(10)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF, "no introduction on a classic level")
	_save.record_completion(LevelCatalog.level_id_at(MAIN, first), 2, 99, 9.0)
	_open(first)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF, "once completed it is not shown again")


func test_free_play_after_the_guide_names_the_broken_rule() -> void:
	var first: int = LevelCatalog.first_main_position("adjacent_pegs")
	_open(first)
	var session: GameSession = _board.session
	for k: int in TutorialDirector.INTRO_STEPS:
		_tap(session.level.solution_path[k].from_peg)
		_tap(session.level.solution_path[k].to_peg)
	# A jump over a stop: from an end peg to the far end.
	var last: int = session.state.get_peg_count() - 1
	var from: int = 0 if not session.state.pegs[0].is_empty() else last
	var to: int = last if from == 0 else 0
	_board.on_peg_pressed(from)
	_board.on_peg_pressed(to)
	assert_eq(_board.coaching.toast.get_text(), tr("RULE_ADJACENT_PEGS"))


func test_restart_runs_the_introduction_again() -> void:
	var first: int = LevelCatalog.first_main_position(ColorSwapRule.ID)
	_open(first)
	var move: Move = _board.session.level.solution_path[0]
	_tap(move.from_peg)
	_tap(move.to_peg)
	_board.restart()
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.GUIDED)
	assert_true(_board.tutorial.step_move.equals(move), "back to the first step")
