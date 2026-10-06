extends "res://tests/test_case.gd"
## The game board scene, driven through its tap handler. Day 4 acceptance: an
## Easy level can be played start to finish and the move count is right.

const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const EASY_LEVEL: String = "res://data/levels/easy/easy_001.json"

var _board: Control
var _completed: Array = []


func before_each() -> void:
	_board = BOARD_SCENE.instantiate()
	_board.level_path = EASY_LEVEL
	_board.level_completed.connect(func(level: Level, moves: int, seconds: float) -> void:
		_completed.append([level.id, moves, seconds]))
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)


func after_each() -> void:
	_board.get_parent().remove_child(_board)
	_board.free()


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
	assert_eq(_label("LevelLabel"), "Easy · 1")
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


func test_every_generated_easy_level_loads() -> void:
	for file_name: String in DirAccess.get_files_at("res://data/levels/easy"):
		if file_name.ends_with(".json"):
			assert_true(_board.load_level_file("res://data/levels/easy/" + file_name), file_name)
