extends "res://tests/test_case.gd"
## Covered pegs (bonus mechanics addendum 2): a purely visual fog over a peg's
## lower disks, opened by the first move that uses the peg, also in the goal
## preview. Rules, Solver and generator know nothing about it.

const SAVE_PATH: String = "res://.test_saves/test_covered_peg_save.json"
const FOG_LEVEL: String = "fog_03.json"

var _board: GameBoard


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _open(file_name: String) -> void:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.save_system.coins = 20
	_board.tutorials_enabled = false
	_board.background_hints = false
	_board.animate_transitions = false
	_board.level_path = LevelCatalog.mechanic_path(file_name)
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)


func _preview() -> BoardPreview:
	return _board.get_node("%GoalPreview")


## Board-local rect of disk `size` (fog rects are board-local too).
func _disk_rect(disk: int) -> Rect2:
	var rect: Rect2 = _board.get_disk_rect(disk)
	return Rect2(rect.position - (_board.get_node("%Board") as Control).global_position, rect.size)


func test_level_format() -> void:
	var level: Level = LevelCatalog.load_mechanic(FOG_LEVEL)
	assert_eq(level.covered_pegs, [1, 2] as Array[int])
	assert_eq(level.rule_ids, ["classic_hanoi"] as Array[String], "no rule involved")
	assert_eq(FileAccess.get_file_as_string(LevelCatalog.mechanic_path(FOG_LEVEL)), level.to_json(), "round trip")
	var data: Dictionary = JSON.parse_string(level.to_json())
	for bad: Variant in [[7], [1, 1], [-1], "1", [1.5]]:
		data["covered_pegs"] = bad
		var errors: Array[String] = []
		var parsed: Level = Level.from_dict(data, errors)
		if parsed != null:
			parsed.check(errors)
		assert_false(errors.is_empty(), "rejects covered_pegs %s" % str(bad))


func test_solver_ignores_the_fog() -> void:
	var level: Level = LevelCatalog.load_mechanic(FOG_LEVEL)
	var result: Dictionary = Solver.solve(level.start, level.goal, level.get_rule_set())
	assert_eq(result["min_moves"], level.min_moves, "the fog changes nothing for the Solver")


func test_session_opens_a_peg_on_its_first_move_until_restart() -> void:
	var level: Level = LevelCatalog.load_mechanic(FOG_LEVEL)
	var session: GameSession = GameSession.new(level)
	assert_eq(session.covered_pegs, [1, 2] as Array[int])
	session.tap_peg(1)
	assert_true(session.is_covered(1), "lifting the top disk is not a move")
	session.tap_peg(1)
	var first: Move = level.solution_path[0]  # [1, 0]
	session.try_move(first)
	assert_false(session.is_covered(1), "used as the source")
	assert_true(session.is_covered(2))
	session.try_move(level.solution_path[1])  # [2, 0]
	assert_false(session.is_covered(2), "used by the second move")
	session.undo()
	session.undo()
	assert_eq(session.covered_pegs, [] as Array[int], "undo does not bring the fog back")
	session.restart()
	assert_eq(session.covered_pegs, [1, 2] as Array[int], "a new attempt is covered again")
	assert_ne(level.covered_pegs.size(), 0, "the level itself is never changed")


func test_fog_hides_all_but_the_top_disk() -> void:
	_open(FOG_LEVEL)
	var state: PuzzleState = _board.session.state
	for peg_index: int in [1, 2]:
		var fog: PegFog = _board.get_peg_fog(peg_index)
		assert_not_null(fog)
		assert_true(fog.is_shown())
		assert_eq(fog.modulate.a, 1.0, "fully covered from the first frame")
		assert_eq(fog.color.a, 1.0, "opaque")
		var area: Rect2 = Rect2(fog.position, fog.size)
		var stack: Array = state.pegs[peg_index]
		assert_false(area.intersects(_disk_rect(stack[-1])), "peg %d: the top disk stays visible" % peg_index)
		for i: int in stack.size() - 1:
			assert_true(area.encloses(_disk_rect(stack[i])), "peg %d: disk %d hidden" % [peg_index, stack[i]])
	# The preview fog must hide the goal's lower disks completely, edges included.
	var preview: BoardPreview = _preview()
	preview.size = Vector2(672, preview.custom_minimum_size.y)
	for label: Dictionary in preview.get_disk_labels():
		var column: float = preview.size.x / state.get_peg_count()
		var peg_index: int = int(label["rect"].get_center().x / column)
		var goal_stack: Array = _board.session.level.goal.pegs[peg_index]
		if peg_index in [1, 2] and label["disk"] != goal_stack[-1]:
			var fog_left: float = column * peg_index + column * 0.01
			assert_true(label["rect"].position.x >= fog_left and label["rect"].end.x <= fog_left + column * 0.98,
					"goal disk %d fully under the preview fog" % label["disk"])
	assert_null(_board.get_peg_fog(0), "uncovered pegs have no fog")
	assert_null(_board.get_peg_fog(3))
	assert_eq(_preview().covered_pegs, [1, 2] as Array[int], "the goal is fogged too")
	assert_true(_preview().is_peg_fogged(1))


func test_first_move_opens_the_peg_on_board_and_preview() -> void:
	_open(FOG_LEVEL)
	var path: Array[Move] = _board.session.level.solution_path
	_board.on_peg_pressed(1)
	assert_true(_board.get_peg_fog(1).is_shown(), "picking up is not yet a move")
	_board.on_peg_pressed(1)
	_board.on_peg_pressed(path[0].from_peg)
	_board.on_peg_pressed(path[0].to_peg)
	assert_false(_board.get_peg_fog(1).is_shown(), "fading away")
	assert_true(_board.get_peg_fog(1).visible, "with a fade, not a jump")
	assert_false(_preview().covered_pegs.has(1), "goal fog lifts together")
	assert_true(_board.get_peg_fog(2).is_shown(), "the other peg stays covered")
	_board.restart()
	assert_true(_board.get_peg_fog(1).is_shown(), "restart covers it again")
	assert_eq(_preview().covered_pegs, [1, 2] as Array[int])


func test_hint_and_solve_work_under_fog() -> void:
	_open(FOG_LEVEL)
	_board.request_hint()
	assert_not_null(_board.hints.hint_move, "the hint sees the full position")
	for move: Move in _board.session.level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_true(_board.session.is_solved())
	assert_eq(_board.last_result["stars"], 3, "the optimal path opens every fog early enough")


func test_validator_rules_for_covered_pegs() -> void:
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], [4]])
	var goal: PuzzleState = PuzzleState.new([[], [], [4, 3, 2, 1]])
	var level: Level = Level.create(9070, "easy", start, goal, ["classic_hanoi"] as Array[String],
			Solver.solve(start, goal, RuleSet.classic())["path"])
	level.covered_pegs = [2]
	var errors: Array[String] = []
	LevelValidator.validate_mechanic_design(level, errors)
	assert_true(" ".join(errors).contains("hides nothing"), str(errors))
	level.covered_pegs = [0]
	errors.clear()
	LevelValidator.validate_mechanic_design(level, errors)
	assert_eq(errors, [] as Array[String], "peg 0 is used by the first move")
	for file_name: String in ["fog_01.json", "fog_02.json", "fog_03.json", "fog_04.json"]:
		var file_errors: Array[String] = []
		LevelValidator.load_and_validate(LevelCatalog.mechanic_path(file_name), file_errors)
		assert_eq(file_errors, [] as Array[String], file_name)
