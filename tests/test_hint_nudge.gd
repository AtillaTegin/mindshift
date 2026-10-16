extends "res://tests/test_case.gd"
## HintNudgeWatcher (economy/UX addendum, section 3): the shared FocusRing
## breathes around the Hint button after IDLE_SECONDS without a tap, or after
## MISTAKES_IN_A_ROW refused moves (plus a one-time toast).

const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const SAVE_PATH: String = "res://.test_saves/test_hint_nudge_save.json"

var _board: GameBoard
var _save: SaveSystem


func before_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save = SaveSystem.new(SAVE_PATH)
	_save.coins = 10


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _open(tier: String, index: int, tutorials: bool = false) -> void:
	_board = BOARD_SCENE.instantiate()
	_board.level_path = Difficulty.level_path(tier, index)
	_board.save_system = _save
	_board.background_hints = false
	_board.tutorials_enabled = tutorials
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)


func _nudge() -> HintNudgeWatcher:
	return _board.hints.nudge


func _ring_on_hint_button() -> bool:
	var ring: FocusRing = _board.coaching.ring
	return ring.visible and ring.get_target().is_equal_approx(_board.get_hint_button_rect())


func _illegal_move() -> Move:
	var session: GameSession = _board.session
	for from_peg: int in session.state.get_peg_count():
		for to_peg: int in session.state.get_peg_count():
			var move: Move = Move.new(from_peg, to_peg)
			if from_peg != to_peg and not session.state.pegs[from_peg].is_empty() \
					and not session.rules.is_move_legal(session.state, move):
				return move
	return null


func _try_illegal() -> void:
	var move: Move = _illegal_move()
	if _board.session.selected_peg != move.from_peg:
		_board.on_peg_pressed(move.from_peg)
	_board.on_peg_pressed(move.to_peg)


func test_idle_player_gets_a_breathing_ring_on_hint() -> void:
	_open("easy", 3)
	var nudge: HintNudgeWatcher = _nudge()
	nudge.advance(HintNudgeWatcher.IDLE_SECONDS - 0.5)
	assert_false(_board.coaching.ring.visible, "not yet")
	nudge.advance(0.6)
	assert_true(_ring_on_hint_button(), "ring around the Hint button")
	assert_eq(nudge.reason, "idle")
	assert_false(_board.coaching.toast.visible, "idle nudge has no text")
	assert_false(_board.coaching.scrim.is_shown(), "nothing else: no scrim")
	assert_false(_board.coaching.pointer.is_playing(), "no finger")
	assert_true(_board.coaching.ring._breath != null and _board.coaching.ring._breath.is_running(), "breathing")


func test_any_tap_removes_the_idle_ring_at_once() -> void:
	_open("easy", 3)
	var nudge: HintNudgeWatcher = _nudge()
	nudge.advance(HintNudgeWatcher.IDLE_SECONDS)
	assert_true(_ring_on_hint_button())
	var move: Move = _board.session.level.solution_path[0]
	_board.on_peg_pressed(move.from_peg)
	assert_false(_board.coaching.ring.visible, "picking up a disk dismisses it")
	assert_eq(nudge.idle_seconds, 0.0, "and restarts the count")
	_board.on_peg_pressed(move.to_peg)
	nudge.advance(HintNudgeWatcher.IDLE_SECONDS - 1.0)
	assert_false(_board.coaching.ring.visible, "a move restarts the count too")
	nudge.advance(1.0)
	assert_true(_ring_on_hint_button())
	_board.request_undo()
	assert_false(_board.coaching.ring.visible, "undo dismisses it")


func test_two_mistakes_in_a_row_show_ring_and_one_toast() -> void:
	_open("easy", 4)  # its start allows a wrong move (easy 3 starts as one tower)
	var nudge: HintNudgeWatcher = _nudge()
	_try_illegal()
	assert_eq(nudge.mistakes_in_a_row, 1)
	assert_false(_board.coaching.ring.visible, "one mistake is fine")
	_try_illegal()
	assert_eq(nudge.mistakes_in_a_row, 2)
	assert_true(_ring_on_hint_button())
	assert_eq(nudge.reason, "mistakes")
	assert_true(_board.coaching.toast.visible)
	assert_eq(_board.coaching.toast.get_text(), tr(HintNudgeWatcher.MISTAKE_TEXT))
	_board.coaching.toast.hide_now()
	_try_illegal()
	assert_true(_ring_on_hint_button(), "more mistakes keep pointing at Hint")
	assert_false(_board.coaching.toast.visible, "the toast is shown only once per level")


func test_a_legal_move_resets_the_mistake_count() -> void:
	_open("easy", 4)
	var nudge: HintNudgeWatcher = _nudge()
	_try_illegal()
	_board.on_peg_pressed(_board.session.selected_peg)  # put the disk back
	var move: Move = _board.session.level.solution_path[0]
	_board.on_peg_pressed(move.from_peg)
	_board.on_peg_pressed(move.to_peg)
	assert_eq(nudge.mistakes_in_a_row, 0)
	_try_illegal()
	assert_false(_board.coaching.ring.visible, "not two in a row")


func test_hint_takes_the_ring_over() -> void:
	_open("easy", 3)
	_nudge().advance(HintNudgeWatcher.IDLE_SECONDS)
	assert_true(_ring_on_hint_button())
	_board.request_hint()
	var move: Move = _board.hints.hint_move
	assert_not_null(move)
	assert_false(_nudge().is_showing())
	var disk_rect: Rect2 = _board.get_disk_rect(_board.session.state.get_top_disk(move.from_peg))
	assert_true(_board.coaching.ring.get_target().is_equal_approx(disk_rect), "the same ring now shows the hint")
	_nudge().advance(HintNudgeWatcher.IDLE_SECONDS * 2.0)
	assert_true(_board.coaching.ring.get_target().is_equal_approx(disk_rect), "no nudge while a hint is shown")


func test_no_nudge_in_tutorial_without_coins_or_after_solving() -> void:
	_open("easy", 1, true)
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.GUIDED)
	var step_target: Rect2 = _board.coaching.ring.get_target()
	_nudge().advance(HintNudgeWatcher.IDLE_SECONDS * 2.0)
	assert_false(_nudge().is_showing(), "guided tutorial")
	assert_true(_board.coaching.ring.get_target().is_equal_approx(step_target), "tutorial keeps its ring")
	_board.start_level(LevelCatalog.load_level("easy", 2))
	assert_eq(_board.tutorial.mode, TutorialDirector.Mode.FREE)
	_nudge().advance(HintNudgeWatcher.IDLE_SECONDS * 2.0)
	_try_illegal()
	_try_illegal()
	assert_false(_nudge().is_showing(), "free tutorial")

	_board.start_level(LevelCatalog.load_level("easy", 3))
	_save.coins = 0
	_nudge().advance(HintNudgeWatcher.IDLE_SECONDS * 2.0)
	assert_false(_nudge().is_showing(), "pointing at a hint the player cannot buy would only frustrate")

	_save.coins = 10
	for move: Move in _board.session.level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_true(_board.session.is_solved())
	_nudge().advance(HintNudgeWatcher.IDLE_SECONDS * 2.0)
	assert_false(_nudge().is_showing(), "solved")
