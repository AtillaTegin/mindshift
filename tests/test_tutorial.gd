extends "res://tests/test_case.gd"
## TutorialDirector (addendum 6B-3 / 6B-4).
## 6B-3 acceptance: when easy_001 opens for the first time the player can tap
## only the shown disk, then only the shown peg, and "Əla!" appears after each
## step. 6B-4: easy_002 allows free taps and a refused move shows the rule text.

const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const SAVE_PATH: String = "user://test_tutorial_save.json"

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


func _open(tier: String, index: int) -> void:
	_board = BOARD_SCENE.instantiate()
	_board.level_path = Difficulty.level_path(tier, index)
	_board.save_system = _save
	_board.background_hints = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)


func _button(unique_name: String) -> Button:
	return _board.get_node("%" + unique_name) as Button


func test_level_1_lets_only_the_shown_disk_then_peg_be_tapped() -> void:
	_open("easy", 1)
	var tutorial: TutorialDirector = _board.tutorial
	var coaching: CoachingLayer = _board.coaching
	var session: GameSession = _board.session
	var path: Array[Move] = session.level.solution_path
	assert_eq(tutorial.mode, TutorialDirector.Mode.GUIDED)
	assert_true(_button("HintButton").disabled and _button("UndoButton").disabled and _button("RestartButton").disabled,
			"hint, undo and restart are off during the guided steps")
	for k: int in path.size():
		var move: Move = path[k]
		assert_true(tutorial.step_move.equals(move), "step %d comes from solution_path" % k)
		assert_eq(_board.restricted_peg, move.from_peg)
		var disk_rect: Rect2 = _board.get_disk_rect(session.state.get_top_disk(move.from_peg))
		assert_true(coaching.ring.get_target().is_equal_approx(disk_rect), "step %d: ring on the disk" % k)
		# Every other peg ignores taps.
		for peg: int in session.state.get_peg_count():
			if peg != move.from_peg:
				_board.on_peg_pressed(peg)
				assert_eq(session.selected_peg, -1, "step %d: peg %d refused" % [k, peg])
		_board.on_peg_pressed(move.from_peg)
		assert_eq(session.selected_peg, move.from_peg, "step %d: shown disk picked up" % k)
		assert_eq(_board.restricted_peg, move.to_peg)
		assert_true(coaching.ring.get_target().is_equal_approx(_board.get_peg_rect(move.to_peg)), "step %d: ring on the target" % k)
		assert_true(coaching.pointer.is_playing(), "step %d: ghost finger" % k)
		var gesture: Array[Vector2] = coaching.pointer.get_gesture()
		assert_true(_board.get_peg_rect(move.to_peg).has_point(gesture[1]), "step %d: finger goes to the target" % k)
		for peg: int in session.state.get_peg_count():
			if peg != move.to_peg:
				_board.on_peg_pressed(peg)
				assert_eq(session.move_count, k, "step %d: tap on peg %d refused" % [k, peg])
				assert_eq(session.selected_peg, move.from_peg, "step %d: still holding the disk" % k)
		_board.on_peg_pressed(move.to_peg)
		assert_eq(session.move_count, k + 1)
		assert_true(coaching.toast.visible, "step %d: toast" % k)
		assert_eq(coaching.toast.get_text(), tr(TutorialDirector.STEP_DONE_TEXT))
	assert_true(session.is_solved())
	assert_eq(tutorial.mode, TutorialDirector.Mode.OFF)
	assert_eq(_board.restricted_peg, -1, "all pegs free again")
	assert_false(coaching.scrim.is_shown())
	assert_false(coaching.ring.visible)
	assert_eq(_board.last_result["stars"], 3)


func test_level_1_tutorial_only_until_completed() -> void:
	_save.record_completion(1001, 3, 3, 10.0)
	_open("easy", 1)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF)
	assert_eq(_board.restricted_peg, -1)
	assert_false(_board.coaching.ring.visible)
	assert_false(_button("HintButton").disabled)


func test_level_1_tutorial_restarts_when_reopened_before_finishing() -> void:
	_open("easy", 1)
	var first: Move = _board.session.level.solution_path[0]
	_board.on_peg_pressed(first.from_peg)
	_board.on_peg_pressed(first.to_peg)
	_board.start_level(LevelCatalog.load_level("easy", 1))
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.GUIDED)
	assert_true(_board.tutorial.step_move.equals(first), "back to the first step")


func test_level_2_is_free_play_with_a_welcome_toast() -> void:
	_open("easy", 2)
	var tutorial: TutorialDirector = _board.tutorial
	assert_eq(tutorial.mode, TutorialDirector.Mode.FREE)
	assert_eq(_board.restricted_peg, -1, "no restricted input")
	assert_true(_board.coaching.toast.visible)
	assert_eq(_board.coaching.toast.get_text(), tr(TutorialDirector.TRY_YOURSELF_TEXT))
	assert_false(_board.coaching.ring.visible, "no ring")
	assert_false(_board.coaching.pointer.is_playing(), "no ghost finger")
	assert_false(_button("HintButton").disabled)
	assert_false(_button("RestartButton").disabled)
	# Any peg with a disk can be picked up, not just the optimal one.
	var session: GameSession = _board.session
	for peg: int in session.state.get_peg_count():
		if session.state.pegs[peg].is_empty():
			continue
		_board.on_peg_pressed(peg)
		assert_eq(session.selected_peg, peg, "peg %d can be picked" % peg)
		_board.on_peg_pressed(peg)


func test_level_2_wrong_move_shows_the_rule_text() -> void:
	_open("easy", 2)
	var session: GameSession = _board.session
	var illegal: Move = _first_illegal_move(session)
	assert_not_null(illegal)
	_board.on_peg_pressed(illegal.from_peg)
	_board.on_peg_pressed(illegal.to_peg)
	var target: PegView = _board.get_node("%PegLayer").get_child(illegal.to_peg)
	assert_true(target.flash_amount > 0.9, "the red flash stays")
	assert_eq(session.move_count, 0)
	assert_true(_board.coaching.toast.visible)
	assert_eq(_board.coaching.toast.get_text(), tr(ClassicHanoiRule.new().violation_message),
			"the rule's own message, not a hard-coded one")


func test_level_2_after_completion_has_no_tutorial() -> void:
	_save.record_completion(1002, 2, 4, 9.0)
	_open("easy", 2)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF)
	var illegal: Move = _first_illegal_move(_board.session)
	_board.on_peg_pressed(illegal.from_peg)
	_board.on_peg_pressed(illegal.to_peg)
	assert_false(_board.coaching.toast.visible, "no coaching text outside the tutorial")


static func _first_illegal_move(session: GameSession) -> Move:
	for from_peg: int in session.state.get_peg_count():
		for to_peg: int in session.state.get_peg_count():
			var move: Move = Move.new(from_peg, to_peg)
			if from_peg != to_peg and not session.state.pegs[from_peg].is_empty() \
					and not session.rules.is_move_legal(session.state, move):
				return move
	return null


func test_other_levels_have_no_tutorial() -> void:
	_open("easy", 3)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF)
	assert_eq(_board.restricted_peg, -1)
	assert_false(_board.coaching.toast.visible)
	_board.start_level(LevelCatalog.load_level("hard", 1))
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.OFF)
