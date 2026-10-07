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


func test_every_generated_easy_level_loads() -> void:
	for file_name: String in DirAccess.get_files_at("res://data/levels/easy"):
		if file_name.ends_with(".json"):
			assert_true(_board.load_level_file("res://data/levels/easy/" + file_name), file_name)
