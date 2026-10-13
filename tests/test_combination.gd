extends "res://tests/test_case.gd"
## "Birləşmə Tapmacası" (combination puzzle, level structure v4, section 4;
## user decisions 2026-10-13): equal-sized disks in four colours, pegs with a
## capacity, a colour goal ("Sadə Yığım" sort or "Konkret Kombinasiya"
## pattern), its own solver, its own move scale and ~30 levels on the road.

const SAVE_PATH: String = "res://.test_saves/test_combination_save.json"
const MAIN: String = LevelCatalog.MAIN

var _board: GameBoard


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Disks 1-4 coloured red, blue, red, blue on 3 pegs of capacity 2.
func _small_level(goal: ColorGoal, start: Array, end: Array, path: Array[Move]) -> Level:
	var params: Dictionary = {CombinationRule.ID: {"capacity": 2}}
	var level: Level = Level.create(9999, "easy", PuzzleState.new(start), PuzzleState.new(end),
			[CombinationRule.ID] as Array[String], path, params)
	level.disk_colors = ["red", "blue", "red", "blue"] as Array[String]
	level.color_goal = goal
	return level


func _combo_levels() -> Array[Level]:
	var levels: Array[Level] = []
	for i: int in range(1, 31):
		levels.append(LevelCatalog.load_mechanic("combo_%02d.json" % i))
	return levels


func _start_board(level: Level) -> void:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.tutorials_enabled = false
	_board.background_hints = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.start_level(level)
	# A phone-sized board area (headless runs have no real window size).
	(_board.get_node("%Board") as Control).size = Vector2(672.0, 700.0)


func test_colour_goals() -> void:
	var colours: Array[String] = ["red", "blue", "red", "blue"]
	var sort: ColorGoal = ColorGoal.sort()
	assert_true(sort.is_met(PuzzleState.new([[1, 3], [2, 4], []]), colours))
	assert_true(sort.is_met(PuzzleState.new([[], [4, 2], [3, 1]]), colours), "any peg, any order of equal disks")
	assert_false(sort.is_met(PuzzleState.new([[1], [2, 4], [3]]), colours), "all of a colour together")
	assert_false(sort.is_met(PuzzleState.new([[1, 2], [3, 4], []]), colours), "one colour per peg")
	var pattern: ColorGoal = ColorGoal.pattern(2, ["red", "blue"] as Array[String])
	assert_true(pattern.is_met(PuzzleState.new([[3], [4], [1, 2]]), colours))
	assert_true(pattern.is_met(PuzzleState.new([[1], [2], [3, 4]]), colours), "read by colour, not identity")
	assert_false(pattern.is_met(PuzzleState.new([[1], [4], [2, 3]]), colours), "bottom to top")
	assert_false(pattern.is_met(PuzzleState.new([[], [4], [1, 2, 3]]), colours), "exactly the pattern")
	assert_eq(pattern.progress(PuzzleState.new([[4], [2], [1, 3]]), colours), 1)
	assert_eq(sort.progress(PuzzleState.new([[1, 3], [2], [4]]), colours), 1, "one finished peg")
	assert_eq(sort.progress_total(colours), 2)
	assert_eq(pattern.progress_total(colours), 2)
	var errors: Array[String] = []
	assert_null(ColorGoal.from_dict({"kind": "pattern", "peg": 1}, errors))
	assert_null(ColorGoal.from_dict({"kind": "spiral"}, errors))
	assert_eq(ColorGoal.from_dict(pattern.to_dict(), errors).to_dict(), pattern.to_dict(), "round trip")


func test_same_puzzle_in_other_colours_has_the_same_shape() -> void:
	var goal: ColorGoal = ColorGoal.pattern(0, ["red", "blue"] as Array[String])
	var other: ColorGoal = ColorGoal.pattern(0, ["green", "yellow"] as Array[String])
	assert_eq(goal.shape_key(PackedStringArray(["br", "rb", ""])), other.shape_key(PackedStringArray(["yg", "gy", ""])))
	assert_ne(goal.shape_key(PackedStringArray(["br", "rb", ""])), other.shape_key(PackedStringArray(["gy", "yg", ""])))


func test_capacity_rule() -> void:
	var errors: Array[String] = []
	assert_null(RuleSet.from_ids([CombinationRule.ID], {}, errors), "a capacity is required")
	assert_null(RuleSet.from_ids([CombinationRule.ID], {CombinationRule.ID: {"capacity": 0}}, errors))
	var rules: RuleSet = RuleSet.from_ids([CombinationRule.ID], {CombinationRule.ID: {"capacity": 2}})
	var state: PuzzleState = PuzzleState.new([[4, 1], [2], [3]])
	assert_true(rules.is_move_legal(state, Move.new(0, 1)), "any disk onto any disk: sizes do not count")
	assert_true(rules.is_move_legal(state, Move.new(1, 0)) == false, "but not onto a full peg")
	assert_eq(rules.get_violation_message(state, Move.new(1, 0)), "RULE_PEG_FULL")
	assert_false(rules.is_state_valid(PuzzleState.new([[1, 2, 3], [], []])), "over capacity")
	assert_eq(rules.get_rule_params(), {CombinationRule.ID: {"capacity": 2}})
	assert_eq(Difficulty.COMBINATION, CombinationRule.ID)


func test_solver_finds_the_shortest_way_by_colour() -> void:
	var level: Level = _small_level(ColorGoal.sort(), [[1, 2], [3, 4], []], [[1, 3], [], [4, 2]], [])
	var result: Dictionary = CombinationSolver.solve(level, level.start)
	assert_true(result["solvable"])
	assert_eq(result["min_moves"], 3, "blue to the empty peg, red across, the other blue over")
	var state: PuzzleState = level.start
	for move: Move in result["path"]:
		state = level.get_rule_set().apply_move(state, move)
		assert_not_null(state, "every move is legal")
	assert_true(level.is_goal_met(state, level.get_rule_set()))
	# The distance map gives the same answer from the goal side.
	var goals: Array[PackedStringArray] = CombinationSolver.goal_positions(level.color_goal, "rbrb", 3, 2)
	assert_eq(goals.size(), 6, "two colours on two of three pegs")
	var map: Dictionary = CombinationSolver.distance_map(goals, 2)
	assert_eq(map["rb|rb|"][0], 3)
	assert_eq(CombinationSolver.path_from(map, "rb|rb|").size(), 3)
	var pattern_goals: Array[PackedStringArray] = CombinationSolver.goal_positions(
			ColorGoal.pattern(2, ["blue", "red"] as Array[String]), "rbrb", 3, 2)
	for pegs: PackedStringArray in pattern_goals:
		assert_eq(pegs[2], "br")
		assert_eq("".join(pegs).length(), 4)


func test_level_format_and_checks() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_21.json")
	var errors: Array[String] = []
	var copy: Level = Level.from_dict(level.to_dict(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(copy.disk_colors, level.disk_colors)
	assert_eq(copy.color_goal.to_dict(), level.color_goal.to_dict())
	assert_eq(level.mechanic(), CombinationRule.ID)
	copy.check(errors)
	assert_eq(errors, [] as Array[String])
	copy.rule_ids = ["classic_hanoi", CombinationRule.ID] as Array[String]
	copy.check(errors)
	assert_true(" ".join(errors).contains("alone"), str(errors))
	errors.clear()
	copy = Level.from_dict(level.to_dict(), errors)
	copy.disk_colors.pop_back()
	copy.check(errors)
	assert_true(" ".join(errors).contains("disk_colors"), str(errors))
	errors.clear()
	copy = Level.from_dict(level.to_dict(), errors)
	copy.goal = copy.start.duplicate_state()
	copy.solution_path.clear()
	copy.check(errors)
	assert_true(" ".join(errors).contains("does not meet the colour goal"), str(errors))


func test_own_move_scale() -> void:
	# User decision 2026-10-13: these puzzles are short, so 5-7 / 8-10 / 11+.
	assert_eq(Difficulty.tier_for_moves(7, Difficulty.COMBINATION), "easy")
	assert_eq(Difficulty.tier_for_moves(8, Difficulty.COMBINATION), "medium")
	assert_eq(Difficulty.tier_for_moves(10, Difficulty.COMBINATION), "medium")
	assert_eq(Difficulty.tier_for_moves(11, Difficulty.COMBINATION), "hard")
	assert_eq(Difficulty.tier_for_moves(16, Difficulty.COMBINATION), "hard")
	assert_eq(Difficulty.tier_for_moves(11), "easy", "other levels keep the usual ranges")
	assert_eq(Difficulty.describe_moves("medium", Difficulty.COMBINATION), "8-10")


func test_thirty_levels_from_sorting_with_room_to_full_patterns() -> void:
	var levels: Array[Level] = _combo_levels()
	var shapes: Dictionary = {}
	var previous: int = 0
	for i: int in levels.size():
		var level: Level = levels[i]
		assert_not_null(level, "combo_%02d" % (i + 1))
		var errors: Array[String] = []
		LevelValidator.validate_level(level, errors)
		assert_eq(errors, [] as Array[String], "combo_%02d" % (i + 1))
		assert_eq(level.difficulty, Difficulty.tier_for_moves(level.min_moves, Difficulty.COMBINATION))
		assert_true(level.min_moves >= previous, "never shorter than the one before (combo_%02d)" % (i + 1))
		previous = level.min_moves
		var key: String = LevelValidator.puzzle_key(level)
		assert_false(shapes.has(key), "combo_%02d repeats an earlier one in other colours" % (i + 1))
		shapes[key] = true
		var empty_peg: bool = false
		for peg: Array in level.start.pegs:
			empty_peg = empty_peg or peg.is_empty()
		if i < 4:
			assert_eq(level.get_disk_count(), 6, "early: 6 disks")
			assert_true(empty_peg, "with room to manoeuvre")
			assert_eq(level.color_goal.kind, ColorGoal.SORT, "and the plain sort goal")
		elif i >= 14:
			assert_true(level.get_disk_count() >= 8, "hard: 8-9 disks (combo_%02d)" % (i + 1))
			assert_false(empty_peg, "no empty peg (combo_%02d)" % (i + 1))
			assert_eq(level.color_goal.kind, ColorGoal.PATTERN, "a combination to read off the picture")
		if level.color_goal.kind == ColorGoal.PATTERN:
			var distinct: Array[String] = []
			for color_name: String in level.color_goal.colors:
				if not distinct.has(color_name):
					distinct.append(color_name)
			assert_true(distinct.size() >= 2, "a combination of colours")
	assert_eq(levels[0].difficulty, "easy", "the first one is a gentle start")
	var kinds: Array[String] = []
	for i: int in range(4, 14):
		kinds.append(levels[i].color_goal.kind)
	assert_true(kinds.has(ColorGoal.SORT) and kinds.has(ColorGoal.PATTERN), "the middle mixes both goals")


func test_chapter_on_the_road() -> void:
	var positions: Array[int] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == CombinationRule.ID:
			positions.append(position)
			var level: Level = LevelCatalog.load_at(MAIN, position)
			if level.difficulty == "easy":
				assert_true(position <= PathBuilder.EASY_UNTIL, "easy ones only while learning (%d)" % position)
	assert_eq(positions.size(), 30)
	assert_eq(positions[0], 30, "first at main 30")
	assert_true(positions[-1] > PathBuilder.MIX_UNTIL, "to the end of the road (%d)" % positions[-1])


func test_session_wins_by_colour_with_hints_and_undo() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_06.json")
	var session: GameSession = GameSession.new(level)
	assert_true(session.get_path_hint().equals(level.solution_path[0]), "on the stored path the hint is instant")
	var off_path: Move = null
	for move: Move in session.rules.get_legal_moves(session.state):
		if not move.equals(level.solution_path[0]):
			off_path = move
			break
	session.try_move(off_path)
	var hint: Move = GameSession.solve_hint(level, session.state.duplicate_state(), session.rules)
	assert_not_null(hint, "off the path the combination solver answers")
	var rest: Array[Move] = CombinationSolver.solve(level, session.state)["path"]
	assert_true(hint.equals(rest[0]))
	assert_true(session.undo())
	for move: Move in level.solution_path:
		assert_false(session.is_solved())
		assert_true(session.try_move(move))
	assert_true(session.is_solved())
	# Equal disks of one colour are interchangeable: the goal holds by colour.
	var swapped: PuzzleState = session.state.duplicate_state()
	var twins: Array[int] = []
	for disk: int in range(1, level.disk_colors.size() + 1):
		if level.disk_colors[disk - 1] == level.disk_colors[0]:
			twins.append(disk)
	var where: Dictionary = {}
	for peg_index: int in swapped.pegs.size():
		for i: int in swapped.pegs[peg_index].size():
			where[swapped.pegs[peg_index][i]] = [peg_index, i]
	swapped.pegs[where[twins[0]][0]][where[twins[0]][1]] = twins[1]
	swapped.pegs[where[twins[1]][0]][where[twins[1]][1]] = twins[0]
	assert_false(swapped.equals(session.state))
	assert_true(level.is_goal_met(swapped, session.rules))


func test_board_shows_colours_capacity_and_the_goal() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_01.json")
	_start_board(level)
	assert_eq(_board.get_board_skin().skin, "glass", "a modern dress")
	var widths: Array[float] = []
	for view: DiskView in _board.get_node("%DiskLayer").get_children():
		var color_name: String = level.disk_colors[view.disk_size - 1]
		assert_eq(view.symbol, color_name, "a shape, not a number")
		assert_eq(view.color, ThemeManager.COMBINATION_DISKS[color_name]["fill"])
		if not widths.has(view.size.x):
			widths.append(view.size.x)
	assert_eq(widths.size(), 1, "every disk the same size")
	var rod: Rect2 = _board.get_peg_rect(0)
	var disk_height: float = _board.get_disk_rect(1).size.y + 4.0
	var peg: PegView = _board.get_node("%PegLayer").get_child(0)
	assert_true(absf((peg.base_top - peg.rod_top) - disk_height * (CombinationSolver.capacity_of(level) + 0.3)) < 1.0,
			"the rod is as tall as the peg holds (%.1f, disk %.1f)" % [peg.base_top - peg.rod_top, disk_height])
	assert_true(rod.size.y > 0.0)
	var preview: BoardPreview = _board.get_node("%GoalPreview")
	assert_not_null(preview.color_goal)
	assert_eq(preview.sort_colours().size(), 3, "one stack per colour")
	var status: Label = _board.get_node("%StatusLabel")
	assert_eq(status.text, tr("COMBINATION_SORT_INTRO"), "a sort goal is told in words")
	assert_eq(status.theme_type_variation, &"SecondaryLabel")
	_board.on_peg_pressed(level.solution_path[0].from_peg)
	_board.on_peg_pressed(level.solution_path[0].to_peg)
	_board.restart()
	assert_eq(status.text, tr("COMBINATION_SORT_INTRO"), "on every attempt")
	for move: Move in level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_true(_board.session.is_solved())
	assert_eq(_board.last_result["stars"], 3)
	assert_eq(preview.finished_colours().size(), 3, "every colour checked off")


func test_board_refuses_a_full_peg_and_shows_pattern_progress() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_21.json")
	_start_board(level)
	var status: Label = _board.get_node("%StatusLabel")
	assert_eq(status.text, "", "a pattern goal is only shown")
	var capacity: int = CombinationSolver.capacity_of(level)
	var full: int = -1
	var other: int = -1
	for peg_index: int in level.get_peg_count():
		if level.start.pegs[peg_index].size() == capacity:
			full = peg_index
		elif not level.start.pegs[peg_index].is_empty():
			other = peg_index
	assert_true(full >= 0 and other >= 0)
	var refused: Array[String] = []
	_board.illegal_move.connect(func(_move: Move, message: String) -> void: refused.append(message))
	_board.on_peg_pressed(other)
	_board.on_peg_pressed(full)
	assert_eq(refused, [tr("RULE_PEG_FULL")] as Array[String], "the full peg says why")
	assert_true((_board.get_node("%PegLayer").get_child(full) as PegView).flash_amount > 0.0, "and flashes")
	assert_eq(_board.session.move_count, 0)
	_board.on_peg_pressed(other)
	var preview: BoardPreview = _board.get_node("%GoalPreview")
	for move: Move in level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_eq(preview.pattern_done(), level.color_goal.colors.size())
	assert_true(_board.session.is_solved())
