extends "res://tests/test_case.gd"
## Covered pegs as karakuri boxes (cultural integration addendum 2): a closed
## box hides a peg's whole stack, the first tap shows the top disk, and each
## disk under it shows when the one above leaves. The goal preview keeps its fog
## until the box opens. Rules, Solver and generator know nothing about it.

const SAVE_PATH: String = "res://.test_saves/test_covered_peg_save.json"

var _board: GameBoard


## A shipped karakuri level with two boxes (file format checks).
static func _two_box_file() -> String:
	var names: Array = Array(DirAccess.get_files_at(Difficulty.LEVELS_DIR + "/" + Difficulty.MECHANICS))
	names.sort()
	for file_name: String in names:
		if file_name.begins_with("fog_") and LevelCatalog.load_mechanic(file_name).covered_pegs.size() == 2:
			return file_name
	return ""


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## A fixed two-box puzzle, so these tests never depend on how the shipped
## levels are generated: boxes on peg 1 [6,5,4,3] and peg 2 [7,2].
static func _box_level() -> Level:
	var start: PuzzleState = PuzzleState.new([[], [6, 5, 4, 3], [7, 2], [1]])
	var goal: PuzzleState = PuzzleState.new([[], [7, 6, 5, 4, 3, 2, 1], [], []])
	var path: Array[Move] = []
	for pair: Array in [[1, 0], [2, 0], [3, 0], [1, 3], [1, 2], [3, 2], [1, 3], [2, 1], [2, 3], [1, 3], [2, 1], [3, 1],
			[3, 2], [1, 2], [3, 1], [2, 3], [2, 1], [0, 2], [3, 1], [0, 3], [0, 1], [3, 1], [2, 1]]:
		path.append(Move.from_array(pair))
	var level: Level = Level.create(9900, "hard", start, goal, ["classic_hanoi"] as Array[String], path)
	level.covered_pegs = [1, 2]
	return level


func _open_box_level() -> void:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.save_system.coins = 20
	_board.tutorials_enabled = false
	_board.background_hints = false
	_board.animate_transitions = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.start_level(_box_level())
	_board.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)


func _preview() -> BoardPreview:
	return _board.get_node("%GoalPreview")


## Board-local rect of disk `size` (fog rects are board-local too).
func _disk_rect(disk: int) -> Rect2:
	var rect: Rect2 = _board.get_disk_rect(disk)
	return Rect2(rect.position - (_board.get_node("%Board") as Control).global_position, rect.size)


func test_level_format() -> void:
	var file_name: String = _two_box_file()
	var level: Level = LevelCatalog.load_mechanic(file_name)
	assert_eq(level.covered_pegs.size(), 2, "a karakuri level with two boxes")
	assert_eq(level.rule_ids, ["classic_hanoi"] as Array[String], "no rule involved")
	assert_eq(FileAccess.get_file_as_string(LevelCatalog.mechanic_path(file_name)), level.to_json(), "round trip")
	var data: Dictionary = JSON.parse_string(level.to_json())
	for bad: Variant in [[7], [1, 1], [-1], "1", [1.5]]:
		data["covered_pegs"] = bad
		var errors: Array[String] = []
		var parsed: Level = Level.from_dict(data, errors)
		if parsed != null:
			parsed.check(errors)
		assert_false(errors.is_empty(), "rejects covered_pegs %s" % str(bad))


func test_solver_ignores_the_fog() -> void:
	var level: Level = LevelCatalog.load_mechanic(_two_box_file())
	var result: Dictionary = Solver.solve(level.start, level.goal, level.get_rule_set())
	assert_eq(result["min_moves"], level.min_moves, "the fog changes nothing for the Solver")


func test_session_boxes_open_one_layer_at_a_time() -> void:
	# Cultural integration addendum 2: boxes on peg 1 [6,5,4,3] and peg 2 [7,2].
	var level: Level = _box_level()
	var session: GameSession = GameSession.new(level)
	assert_eq(session.covered_pegs, [1, 2] as Array[int], "both boxes start closed")
	assert_eq(session.hidden_count(1), 4, "a closed box hides its whole stack")
	assert_eq(session.hidden_count(0), 0, "an ordinary peg hides nothing")
	assert_eq(session.tap_peg(1), GameSession.TapResult.OPENED, "the first tap only opens the box")
	assert_eq(session.selected_peg, -1, "nothing picked up yet")
	assert_eq(session.hidden_count(1), 3, "only the top disk shows")
	assert_eq(session.move_count, 0, "opening is free")
	assert_eq(session.tap_peg(1), GameSession.TapResult.SELECTED)
	assert_eq(session.tap_peg(0), GameSession.TapResult.MOVED)  # disk 3 leaves the box
	assert_eq(session.hidden_count(1), 2, "the disk under it shows")
	assert_true(session.is_covered(2), "the other box is still closed")
	session.try_move(level.solution_path[1])  # [2, 0]: a move by code opens the box first
	assert_false(session.is_covered(2))
	assert_eq(session.hidden_count(2), 0, "disk 7 shows once disk 2 is gone")
	session.undo()
	session.undo()
	assert_eq(session.hidden_count(1), 2, "undo hides nothing again")
	assert_eq(session.hidden_count(2), 0)
	session.restart()
	assert_eq(session.covered_pegs, [1, 2] as Array[int], "a new attempt closes every box")
	assert_eq(session.hidden_count(1), 4)
	assert_ne(level.covered_pegs.size(), 0, "the level itself is never changed")


func test_disks_put_on_a_box_stay_visible() -> void:
	var level: Level = _box_level()
	var session: GameSession = GameSession.new(level)
	session.tap_peg(1)
	assert_true(session.try_move(Move.new(3, 1)), "disk 1 onto the opened box")
	assert_eq(session.hidden_count(1), 3, "still only the old disks are hidden")
	assert_true(session.try_move(Move.new(1, 0)), "disk 1 leaves again")
	assert_eq(session.hidden_count(1), 3, "disk 3 was already showing")


func test_closed_box_hides_the_whole_peg_then_shrinks() -> void:
	_open_box_level()
	var state: PuzzleState = _board.session.state
	var first: PegFog = _board.get_peg_fog(1)
	var second: PegFog = _board.get_peg_fog(2)
	for peg_index: int in [1, 2]:
		var fog: PegFog = _board.get_peg_fog(peg_index)
		assert_true(fog.is_shown())
		assert_eq(fog.modulate.a, 1.0, "fully covered from the first frame")
		var area: Rect2 = fog.get_target_area()
		for disk: int in state.pegs[peg_index]:
			assert_true(area.encloses(_disk_rect(disk)), "peg %d: disk %d hidden, the top one too" % [peg_index, disk])
	assert_eq(first.get_target_area().size.y, second.get_target_area().size.y, "4 and 2 disks: the box does not tell")
	assert_eq(first.skin, "wood", "a karakuri box in the wood dress")
	assert_null(_board.get_peg_fog(0), "ordinary pegs have no box")
	assert_null(_board.get_peg_fog(3))
	# The goal is never hidden (current decisions 2026-10-16, B.3): every goal
	# disk is drawn, the boxed pegs' too.
	var goal_disks: int = 0
	for peg: Array in _board.session.level.goal.pegs:
		goal_disks += peg.size()
	assert_eq(_preview().get_disk_labels().size(), goal_disks, "the whole goal shows")
	_board.on_peg_pressed(1)
	assert_eq(_board.session.selected_peg, -1, "the tap opened the box")
	var opened: Rect2 = first.get_target_area()
	var stack: Array = state.pegs[1]
	assert_false(opened.intersects(_disk_rect(stack[-1])), "the top disk shows")
	for i: int in stack.size() - 1:
		assert_true(opened.encloses(_disk_rect(stack[i])), "disk %d still hidden" % stack[i])


func test_box_layers_open_as_disks_leave_and_restart_closes_it() -> void:
	_open_box_level()
	var fog: PegFog = _board.get_peg_fog(2)  # [7, 2]
	_board.on_peg_pressed(2)  # open: disk 2 shows
	_board.on_peg_pressed(2)
	_board.on_peg_pressed(0)  # disk 2 leaves: disk 7 shows, nothing hidden is left
	assert_eq(_board.session.hidden_count(2), 0)
	assert_false(fog.is_shown(), "the empty box fades away")
	assert_true(fog.visible, "with a fade, not a jump")
	assert_true(_board.get_peg_fog(1).is_shown(), "the other box stays")
	_board.restart()
	assert_true(fog.is_shown(), "restart closes the box again")
	assert_true(_board.session.is_covered(2))
	assert_eq(_board.session.covered_pegs, [1, 2] as Array[int])


func test_hint_and_solve_work_with_boxes() -> void:
	_open_box_level()
	_board.request_hint()
	assert_not_null(_board.hints.hint_move, "the hint sees the full position")
	for peg_index: int in _board.session.level.covered_pegs:
		_board.on_peg_pressed(peg_index)
	for move: Move in _board.session.level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_true(_board.session.is_solved())
	assert_eq(_board.last_result["stars"], 3, "opening boxes costs no moves")

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
	var karakuri: int = 0
	for file_name: String in DirAccess.get_files_at(Difficulty.LEVELS_DIR + "/" + Difficulty.MECHANICS):
		if not file_name.begins_with("fog_") or not file_name.ends_with(".json"):
			continue
		karakuri += 1
		var file_errors: Array[String] = []
		LevelValidator.load_and_validate(LevelCatalog.mechanic_path(file_name), file_errors)
		assert_eq(file_errors, [] as Array[String], file_name)
	assert_true(karakuri >= 70, "a whole chapter of them (%d)" % karakuri)
