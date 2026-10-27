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


## Taps a peg until the tap does more than open a karakuri box (a sealed box
## never opens on a tap).
func _tap(peg: int) -> void:
	while _board.session.is_covered(peg) and not _board.session.is_sealed(peg):
		_board.on_peg_pressed(peg)
	_board.on_peg_pressed(peg)


## Every introduction on the built road, by main position: each mode with
## INTRO_TEXTS, each combination (chapter plan section 3.4) and each
## sub-element (chapter waves v1).
func _intros_on_road() -> Dictionary:
	var found: Dictionary = {}
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		var lesson: String = LevelCatalog.lesson_at(MAIN, position)
		if lesson == Level.CLASSIC:
			continue
		var intro: String = TutorialDirector.intro_lesson(LevelCatalog.load_at(MAIN, position))
		if not intro.is_empty():
			found[intro] = position
	return found


func test_every_mechanic_is_introduced_on_its_first_level() -> void:
	var intros: Dictionary = _intros_on_road()
	for lesson: String in ["peg_capacity", "covered_pegs", "foundation", "peg_capacity+covered_pegs",
			"peg_capacity+foundation", "covered_pegs+foundation", "variant:narrow", "variant:arch", "variant:full_hidden",
			"variant:glass", "variant:empty_box", "variant:sealed", "variant:key_disk", "variant:middle_lock",
			"variant:chain_lock"]:
		assert_true(intros.has(lesson), "world 1-2 introduces %s" % lesson)
	for mechanic: String in intros:
		_open(intros[mechanic])
		var tutorial: TutorialDirector = _board.tutorial
		var session: GameSession = _board.session
		assert_eq(tutorial.mode, TutorialDirector.Mode.GUIDED, mechanic)
		assert_eq(tutorial.intro_mechanic, mechanic)
		var words: String = TutorialDirector.intro_text(session.level)
		if TutorialDirector.INTRO_TEXTS.has(mechanic):
			assert_eq(words, tr(TutorialDirector.INTRO_TEXTS[mechanic]))
		elif mechanic.begins_with(TutorialDirector.VARIANT_PREFIX):
			assert_eq(words, tr("INTRO_VARIANT") % [ModeTexts.variant_name(mechanic.trim_prefix(TutorialDirector.VARIANT_PREFIX)),
					ModeTexts.variant_rule(mechanic.trim_prefix(TutorialDirector.VARIANT_PREFIX))])
		else:
			assert_eq(words, tr("INTRO_COMBO") % [ModeTexts.name_of(session.level), ModeTexts.rule_of(session.level)])
		assert_eq(_board.coaching.toast.get_text(), words, "%s explains itself" % mechanic)
		var path: Array[Move] = session.level.solution_path
		for k: int in TutorialDirector.INTRO_STEPS:
			assert_eq(tutorial.mode, TutorialDirector.Mode.GUIDED, "%s step %d" % [mechanic, k])
			assert_true(tutorial.step_move.equals(path[k]), "%s step %d comes from the solution" % [mechanic, k])
			assert_eq(_board.restricted_peg, path[k].from_peg, "only the shown peg reacts")
			assert_true(_board.coaching.pointer.visible, "the ghost finger shows the move")
			if path[k].from_peg == path[k].to_peg:
				# The stone's own move: its button, no peg taps.
				_board.request_special_move()
				assert_eq(session.move_count, k + 1, "%s step %d made" % [mechanic, k])
				continue
			_tap(path[k].from_peg)
			assert_eq(_board.restricted_peg, path[k].to_peg)
			_tap(path[k].to_peg)
			if path[k].is_compound():
				# A chained pair: the partner's target is shown next.
				assert_eq(_board.restricted_peg, path[k].to_peg_2, "%s step %d: the partner's peg" % [mechanic, k])
				_tap(path[k].to_peg_2)
			assert_eq(session.move_count, k + 1, "%s step %d made" % [mechanic, k])
		assert_eq(tutorial.mode, TutorialDirector.Mode.FREE, "%s: then free play" % mechanic)
		assert_eq(_board.restricted_peg, -1)
		assert_true(_board.coaching.toast.get_text().contains(tr(TutorialDirector.TRY_YOURSELF_TEXT)))


func test_only_the_first_level_of_a_mechanic_and_only_until_completed() -> void:
	var first: int = LevelCatalog.first_main_position(FoundationRule.ID)
	var second: int = 0
	for position: int in range(first + 1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.lesson_at(MAIN, position) == FoundationRule.ID:
			second = position
			break
	_open(second)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF, "the second foundation level plays on its own")
	_open(10)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF, "no introduction on a classic level")
	_save.record_completion(LevelCatalog.level_id_at(MAIN, first), 2, 99, 9.0)
	_open(first)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF, "once completed it is not shown again")


func test_free_play_after_the_guide_names_the_broken_rule() -> void:
	var first: int = LevelCatalog.first_main_position(PegCapacityRule.ID)
	_open(first)
	var session: GameSession = _board.session
	for k: int in TutorialDirector.INTRO_STEPS:
		_tap(session.level.solution_path[k].from_peg)
		_tap(session.level.solution_path[k].to_peg)
	# A move the rules refuse: a full peg first, else larger onto smaller.
	var refused: Move = null
	var message: String = ""
	for from: int in session.state.get_peg_count():
		for to: int in session.state.get_peg_count():
			var move: Move = Move.new(from, to)
			if from == to or session.state.pegs[from].is_empty() or session.rules.is_move_legal(session.state, move):
				continue
			var why: String = session.rules.get_violation_message(session.state, move)
			if refused == null or why == "RULE_PEG_FULL":
				refused = move
				message = why
	assert_not_null(refused)
	_board.on_peg_pressed(refused.from_peg)
	_board.on_peg_pressed(refused.to_peg)
	assert_eq(_board.coaching.toast.get_text(), tr(message))


func test_restart_runs_the_introduction_again() -> void:
	var first: int = LevelCatalog.first_main_position(FoundationRule.ID)
	_open(first)
	var move: Move = _board.session.level.solution_path[0]
	_tap(move.from_peg)
	_tap(move.to_peg)
	_board.restart()
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.GUIDED)
	assert_true(_board.tutorial.step_move.equals(move), "back to the first step")
