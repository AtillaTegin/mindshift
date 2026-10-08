extends "res://tests/test_case.gd"
## The game board scene, driven through its tap handler. Day 4 acceptance: an
## Easy level can be played start to finish and the move count is right.

const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const EASY_LEVEL: String = "res://data/levels/easy/easy_001.json"
## Never the player's real save.
const SAVE_PATH: String = "user://test_game_board_save.json"

var _board: Control
var _save: SaveSystem
var _completed: Array = []


func before_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save = SaveSystem.new(SAVE_PATH)
	_board = BOARD_SCENE.instantiate()
	_board.level_path = EASY_LEVEL
	_board.save_system = _save
	_board.background_hints = false
	_board.tutorials_enabled = false  # covered by test_tutorial.gd
	_board.animate_transitions = false
	_board.level_completed.connect(func(level: Level, moves: int, seconds: float) -> void:
		_completed.append([level.id, moves, seconds]))
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)


func after_each() -> void:
	_board.get_parent().remove_child(_board)
	_board.free()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _play(moves: Array[Move]) -> void:
	for move: Move in moves:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)


func _label(unique_name: String) -> String:
	return (_board.get_node("%" + unique_name) as Label).text


func test_loads_level_and_builds_views() -> void:
	var session: GameSession = _board.session
	assert_not_null(session)
	assert_eq(session.level.id, 1001)
	var peg_layer: Node = _board.get_node("%PegLayer")
	var disk_layer: Node = _board.get_node("%DiskLayer")
	assert_eq(peg_layer.get_child_count(), session.state.get_peg_count())
	assert_eq(disk_layer.get_child_count(), session.state.get_disk_count())
	assert_eq(_label("MovesLabel"), "Gediş: 0")
	assert_eq(_label("MinLabel"), "Minimum: %d" % session.level.min_moves)
	assert_eq(_label("LevelLabel"), "Asan · 1")
	assert_false(_board.get_popup().visible)
	assert_true((_board.get_node("%GoalPreview") as BoardPreview).position_state.equals(session.level.goal))


func test_easy_level_plays_start_to_finish() -> void:
	var session: GameSession = _board.session
	var path: Array[Move] = session.level.solution_path
	for i: int in path.size():
		_board.on_peg_pressed(path[i].from_peg)
		_board.on_peg_pressed(path[i].to_peg)
		assert_eq(_label("MovesLabel"), "Gediş: %d" % (i + 1))
	assert_true(session.is_solved())
	assert_true(_label("StatusLabel").begins_with("Həll olundu!"), _label("StatusLabel"))
	assert_eq(_completed.size(), 1, "level_completed emitted once")
	assert_eq(_completed[0][0], 1001)
	assert_eq(_completed[0][1], path.size())


func test_stopwatch_runs_from_first_move_until_solved() -> void:
	# Economy/UX addendum, section 2: a count-up clock next to the move counter.
	var path: Array[Move] = _board.session.level.solution_path
	assert_eq(_label("TimeLabel"), "00:00")
	assert_eq(_board.get_node("%TimeLabel").get_index(), _board.get_node("%MovesLabel").get_index() + 1,
			"right next to the move counter")
	_board._process(4.0)
	assert_eq(_label("TimeLabel"), "00:00", "waits for the first move")
	_play([path[0]])
	_board._process(65.4)
	assert_eq(_label("TimeLabel"), "01:05")
	_play(path.slice(1))
	assert_true(_board.session.is_solved())
	_board._process(30.0)
	assert_eq(_label("TimeLabel"), "01:05", "stopped when solved")
	assert_eq((_board.get_popup().get_node("%TimeLabel") as Label).text, "Vaxt: 01:05", "popup shows the same time")
	assert_eq(_save.get_record(1001)["best_time_seconds"], 65)
	_board.restart()
	assert_eq(_label("TimeLabel"), "00:00", "restart resets the clock")


func test_illegal_move_flashes_target_and_does_not_count() -> void:
	var session: GameSession = _board.session
	# Find a peg pair whose move is illegal in the start position.
	var illegal: Move = null
	for from_peg: int in session.state.get_peg_count():
		for to_peg: int in session.state.get_peg_count():
			var move: Move = Move.new(from_peg, to_peg)
			if from_peg != to_peg and not session.state.pegs[from_peg].is_empty() \
					and not session.rules.is_move_legal(session.state, move):
				illegal = move
	assert_not_null(illegal, "level has an illegal move to try")
	_board.on_peg_pressed(illegal.from_peg)
	_board.on_peg_pressed(illegal.to_peg)
	var target: PegView = _board.get_node("%PegLayer").get_child(illegal.to_peg)
	assert_true(target.flash_amount > 0.9, "target peg flashes red")
	assert_eq(_label("MovesLabel"), "Gediş: 0")
	assert_eq(session.selected_peg, illegal.from_peg)


func test_selected_disk_is_lifted_and_marked() -> void:
	var session: GameSession = _board.session
	var from_peg: int = -1
	for peg_index: int in session.state.get_peg_count():
		if not session.state.pegs[peg_index].is_empty():
			from_peg = peg_index
			break
	var disk_size: int = session.state.get_top_disk(from_peg)
	var disk_layer: Node = _board.get_node("%DiskLayer")
	var view: DiskView = null
	for child: Node in disk_layer.get_children():
		if (child as DiskView).disk_size == disk_size:
			view = child
	var resting_y: float = view.position.y
	_board.on_peg_pressed(from_peg)
	assert_true(view.selected)
	assert_true((_board.get_node("%PegLayer").get_child(from_peg) as PegView).highlighted)
	_board.on_peg_pressed(from_peg)
	assert_false(view.selected, "second tap puts it back")


func test_restart_resets_counter_and_position() -> void:
	var session: GameSession = _board.session
	var first: Move = session.level.solution_path[0]
	_board.on_peg_pressed(first.from_peg)
	_board.on_peg_pressed(first.to_peg)
	assert_eq(_label("MovesLabel"), "Gediş: 1")
	_board.restart()
	assert_eq(_label("MovesLabel"), "Gediş: 0")
	assert_true(session.state.equals(session.level.start))


func test_optimal_solution_gives_three_stars_saves_and_shows_popup() -> void:
	var level: Level = _board.session.level
	_play(level.solution_path)
	assert_eq(_board.last_result["stars"], 3)
	assert_true(_board.last_result["improved"])
	var popup: LevelCompletePopup = _board.get_popup()
	assert_true(popup.visible)
	assert_eq(popup.get_star_count(), 3)
	assert_eq((popup.get_node("%MovesLabel") as Label).text, "Gediş: %d / min %d" % [level.min_moves, level.min_moves])
	assert_false((popup.get_node("%NextButton") as Button).disabled)
	var reopened: SaveSystem = SaveSystem.new(SAVE_PATH)
	assert_true(reopened.load_save(), "written at once")
	assert_eq(reopened.get_record(level.id)["stars"], 3)
	assert_eq(reopened.get_record(level.id)["best_moves"], level.min_moves)


func test_detour_gives_fewer_stars() -> void:
	var level: Level = _board.session.level
	# Two wasted moves: the first move and its reverse.
	var first: Move = level.solution_path[0]
	var moves: Array[Move] = [first, Move.new(first.to_peg, first.from_peg)]
	moves.append_array(level.solution_path)
	_play(moves)
	var expected: int = level.stars_for_moves(level.min_moves + 2)
	assert_true(expected < 3)
	assert_eq(_board.last_result["stars"], expected)
	assert_eq(_save.get_stars(level.id), expected)


func test_next_and_replay_buttons() -> void:
	_play(_board.session.level.solution_path)
	var popup: LevelCompletePopup = _board.get_popup()
	(popup.get_node("%ReplayButton") as Button).pressed.emit()
	assert_false(popup.visible)
	assert_eq(_board.session.move_count, 0)
	assert_eq(_board.session.level.id, 1001)
	_play(_board.session.level.solution_path)
	(popup.get_node("%NextButton") as Button).pressed.emit()
	assert_eq(_board.session.level.id, 1002, "next level loaded in place")
	assert_eq(_label("LevelLabel"), "Asan · 2")
	assert_false(popup.visible)


## Lays out the screen now (containers normally do it on the next frame), so
## the board geometry used by the coaching overlay is real.
func _lay_out() -> void:
	_board.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)


func test_hint_shows_scrim_ring_and_pointer_and_costs_coins() -> void:
	_lay_out()
	_save.coins = EconomySystem.hint_cost_for_tier("easy") + 1
	var level: Level = _board.session.level
	var move: Move = level.solution_path[0]
	_board.request_hint()
	var hints: HintController = _board.hints
	var coaching: CoachingLayer = _board.coaching
	assert_true(hints.hint_move.equals(move))
	assert_eq(_save.coins, 1)
	assert_eq(_label("CoinLabel"), "1")
	assert_eq(_board.session.move_count, 0, "a hint never moves a disk")
	var disk_rect: Rect2 = _board.get_disk_rect(_board.session.state.get_top_disk(move.from_peg))
	var source_rect: Rect2 = _board.get_peg_rect(move.from_peg)
	var target_rect: Rect2 = _board.get_peg_rect(move.to_peg)
	assert_true(disk_rect.has_area() and target_rect.has_area(), "board is laid out")
	assert_true(coaching.scrim.is_shown(), "scrim")
	assert_true(coaching.scrim.hole.encloses(source_rect) and coaching.scrim.hole.encloses(target_rect), "both pegs stay lit")
	assert_true(coaching.ring.visible and coaching.ring.get_target().is_equal_approx(disk_rect), "ring on the disk")
	assert_true(coaching.pointer.is_playing(), "ghost finger")
	var gesture: Array[Vector2] = coaching.pointer.get_gesture()
	assert_true(disk_rect.has_point(gesture[0]), "finger starts on the disk")
	assert_true(target_rect.has_point(gesture[1]), "finger ends on the target peg")
	_board.request_hint()
	assert_eq(_save.coins, 1, "asking again in the same position is free")
	_board.on_peg_pressed(move.from_peg)
	assert_true(coaching.ring.get_target().is_equal_approx(target_rect), "ring moves to the target once the disk is picked up")
	_board.on_peg_pressed(move.to_peg)
	assert_null(hints.hint_move, "hint cleared after the move")
	assert_false(coaching.scrim.is_shown())
	assert_false(coaching.ring.visible)
	assert_false(coaching.pointer.is_playing())


func test_hint_off_the_path_uses_the_solver() -> void:
	_save.coins = 8
	var level: Level = _board.session.level
	var first: Move = level.solution_path[0]
	# A legal move that leaves the stored solution.
	var detour: Move = null
	for move: Move in _board.session.rules.get_legal_moves(_board.session.state):
		if not move.equals(first):
			detour = move
	_play([detour])
	assert_null(_board.session.get_path_hint(), "off the path")
	var remaining: int = Solver.solve(_board.session.state, level.goal, _board.session.rules)["min_moves"]
	_board.request_hint()
	assert_not_null(_board.hints.hint_move)
	assert_eq(_save.coins, 8 - EconomySystem.hint_cost_for_tier("easy"))
	assert_true(_board.coaching.ring.visible)
	var after: PuzzleState = _board.session.rules.apply_move(_board.session.state, _board.hints.hint_move)
	assert_eq(Solver.solve(after, level.goal, _board.session.rules)["min_moves"], remaining - 1, "hint is optimal")


func test_hint_without_coins_shows_a_message() -> void:
	_save.coins = 0
	_board.request_hint()
	assert_null(_board.hints.hint_move)
	assert_false(_board.coaching.scrim.is_shown())
	assert_eq(_label("StatusLabel"), "Hint üçün coin çatmır")
	assert_eq(_save.coins, 0)


func test_undo_is_free_three_times_then_costs() -> void:
	_save.coins = 1
	var first: Move = _board.session.level.solution_path[0]
	var back: Move = Move.new(first.to_peg, first.from_peg)
	for i: int in EconomySystem.FREE_UNDOS_PER_DAY:
		_play([first])
		_board.request_undo()
		assert_eq(_board.session.move_count, 0)
	assert_eq(_save.coins, 1, "free undos")
	assert_eq((_board.get_node("%UndoButton") as Button).text, "Geri · 1 coin")
	_play([first])
	_board.request_undo()
	assert_eq(_save.coins, 0, "fourth undo paid")
	assert_eq(_board.session.move_count, 0)
	_play([first])
	_board.request_undo()
	assert_eq(_board.session.move_count, 1, "no coins, no undo")
	assert_eq(_label("StatusLabel"), "Geri qaytarmaq üçün coin çatmır")
	_play([back])
	assert_eq(_board.session.move_count, 2)
	_board.restart()
	assert_eq(_board.economy.free_undos_left(), 0, "free undos are per day, a restart does not refill them")


func test_completion_pays_by_stars_and_replays_only_the_improvement() -> void:
	_save.coins = 0
	var level: Level = _board.session.level
	var first: Move = level.solution_path[0]
	var detour: Array[Move] = [first, Move.new(first.to_peg, first.from_peg)]
	detour.append_array(level.solution_path)
	_play(detour)
	var stars: int = _board.last_result["stars"]
	assert_true(stars < 3)
	assert_eq(_board.last_result["reward"], EconomySystem.star_reward(stars), "first completion pays the full table value")
	_board.restart()
	_play(level.solution_path)
	assert_eq(_board.last_result["reward"], 8 - EconomySystem.star_reward(stars), "3 stars pay only the difference")
	assert_eq(_save.coins, 8)
	var popup_text: String = (_board.get_popup().get_node("%RecordLabel") as Label).text
	assert_true(popup_text.contains("+%d coin" % (8 - EconomySystem.star_reward(stars))), popup_text)
	_board.restart()
	_play(level.solution_path)
	assert_eq(_board.last_result["reward"], 0, "replaying for coins pays nothing")
	assert_eq(_save.coins, 8)


func test_every_generated_easy_level_loads() -> void:
	for file_name: String in DirAccess.get_files_at("res://data/levels/easy"):
		if file_name.ends_with(".json"):
			assert_true(_board.load_level_file("res://data/levels/easy/" + file_name), file_name)
