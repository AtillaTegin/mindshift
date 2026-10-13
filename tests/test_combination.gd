extends "res://tests/test_case.gd"
## "Birləşmə Tapmacası" (combination puzzle): level structure v4 section 4 as
## corrected by v2 (2026-10-13). Equal-sized disks in up to seven colours, pegs
## with a capacity, Water Sort's shape (N disks of each of C colours, E empty
## pegs) growing by stage along the road, a goal that names every disk ("Sadə
## Yığım" sort, or a full colour sequence for every peg), its own solvers, and
## stars against a stored example solution (user decisions 2026-10-13).

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


func _combo_levels() -> Array[Level]:
	var levels: Array[Level] = []
	for i: int in range(1, 31):
		levels.append(LevelCatalog.load_mechanic("combo_%02d.json" % i))
	return levels


## The combination levels with their main path positions, in road order.
func _on_road() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == CombinationRule.ID:
			found.append({"position": position, "level": LevelCatalog.load_at(MAIN, position)})
	return found


func _start_board(level: Level) -> void:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.tutorials_enabled = false
	_board.background_hints = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.start_level(level)
	# A phone-sized board area (headless runs have no real window size).
	(_board.get_node("%Board") as Control).size = Vector2(672.0, 700.0)


func test_colour_goals_name_every_disk() -> void:
	var colours: Array[String] = ["red", "blue", "red", "blue"]
	var sort: ColorGoal = ColorGoal.sort()
	assert_true(sort.is_met(PuzzleState.new([[1, 3], [2, 4], []]), colours))
	assert_true(sort.is_met(PuzzleState.new([[], [4, 2], [3, 1]]), colours), "any peg, any order of equal disks")
	assert_false(sort.is_met(PuzzleState.new([[1], [2, 4], [3]]), colours), "all of a colour together")
	var pattern: ColorGoal = ColorGoal.pattern([["red", "blue"], ["blue", "red"], []])
	assert_true(pattern.is_met(PuzzleState.new([[1, 2], [4, 3], []]), colours))
	assert_true(pattern.is_met(PuzzleState.new([[3, 4], [2, 1], []]), colours), "read by colour, not identity")
	assert_false(pattern.is_met(PuzzleState.new([[1, 2], [3, 4], []]), colours), "every peg must show its own target")
	assert_eq(pattern.progress(PuzzleState.new([[1, 4], [2], [3]]), colours), 3, "peg 0 right (2), peg 1 started (1)")
	assert_eq(pattern.progress_total(colours), 4)
	assert_eq(pattern.goal_colours(colours), ["blue", "red"] as Array[String])
	assert_eq(sort.goal_colours(colours), ["blue", "red"] as Array[String], "a sort goal names every colour")
	var errors: Array[String] = []
	ColorGoal.pattern([["red", "red"], [], []]).check(3, 2, colours, errors)
	assert_true(" ".join(errors).contains("the goal names"), "correction v2: no colour without a goal (%s)" % str(errors))
	errors.clear()
	ColorGoal.pattern([["red", "blue"], ["blue"], []]).check(3, 2, colours, errors)
	assert_true(" ".join(errors).contains("every disk"), str(errors))
	errors.clear()
	ColorGoal.pattern([["red", "blue"], ["blue", "red"]]).check(3, 2, colours, errors)
	assert_true(" ".join(errors).contains("each of the 3 pegs"), str(errors))
	errors.clear()
	pattern.check(3, 2, colours, errors)
	assert_eq(errors, [] as Array[String])
	assert_null(ColorGoal.from_dict({"kind": "pattern", "peg": 1, "colors": ["red"]}, errors), "the old one-peg form is gone")
	assert_eq(ColorGoal.from_dict(pattern.to_dict(), errors).to_dict(), pattern.to_dict(), "round trip")


func test_every_level_has_a_goal_for_every_disk() -> void:
	# Correction v2, error 1: set(disk colours) == set(goal colours), and a
	# pattern places every disk; audited for every shipped level.
	for level: Level in _combo_levels():
		var board: Array[String] = []
		for color_name: String in level.disk_colors:
			if not board.has(color_name):
				board.append(color_name)
		board.sort()
		assert_eq(level.color_goal.goal_colours(level.disk_colors), board, "level %d" % level.id)
		if level.color_goal.kind == ColorGoal.PATTERN:
			var named: int = 0
			for target: Array in level.color_goal.targets:
				named += target.size()
			assert_eq(named, level.get_disk_count(), "level %d: the pattern places every disk" % level.id)
			assert_eq(level.color_goal.targets.size(), level.get_peg_count(), "a target for every peg")


func test_levels_follow_the_stage_table() -> void:
	# Correction v2, error 2: N / C / E / T by the level's stretch of the road.
	var road: Array[Dictionary] = _on_road()
	assert_eq(road.size(), 30)
	var stages_seen: Dictionary = {}
	for entry: Dictionary in road:
		var level: Level = entry["level"]
		var position: int = entry["position"]
		assert_eq(LevelValidator.combination_stage_errors(level, position), [] as Array[String], "main %d" % position)
		var errors: Array[String] = []
		LevelValidator.validate_combination_shape(level, errors)
		assert_eq(errors, [] as Array[String], "main %d: Water Sort's shape" % position)
		var stage: String = Difficulty.combination_stage(position)["name"]
		if not stages_seen.has(stage):
			stages_seen[stage] = []
		(stages_seen[stage] as Array).append(level)
	assert_eq(road[0]["position"], 30, "first at main 30")
	var first: Level = road[0]["level"]
	assert_eq([first.get_disk_count(), first.get_peg_count(), CombinationSolver.capacity_of(first)], [8, 3, 4], "intro: N4 C2 E1")
	var last: Level = road[-1]["level"]
	assert_true(last.get_disk_count() >= 40 and last.get_peg_count() >= 7, "main %d is a hard_2 board" % road[-1]["position"])
	# Boards grow stage by stage (inside a stage sizes vary on purpose).
	var previous_largest: int = 0
	for stage: String in ["intro", "middle_1", "middle_2", "hard_1", "hard_2"]:
		assert_true(stages_seen.has(stage), "%s is on the road" % stage)
		var largest: int = 0
		for level: Level in stages_seen[stage]:
			largest = maxi(largest, level.get_disk_count())
		assert_true(largest > previous_largest, "%s boards are larger than the stage before" % stage)
		previous_largest = largest
	for level: Level in stages_seen["intro"] + stages_seen["middle_1"]:
		assert_eq(level.color_goal.kind, ColorGoal.SORT, "sorting first (v4 gradient)")
	var middle: Array[String] = []
	for level: Level in stages_seen["middle_2"]:
		middle.append(level.color_goal.kind)
	assert_true(middle.has(ColorGoal.SORT) and middle.has(ColorGoal.PATTERN), "both goals in the middle")
	for level: Level in stages_seen["hard_1"] + stages_seen["hard_2"]:
		assert_eq(level.color_goal.kind, ColorGoal.PATTERN, "patterns late")
	var sizes: Dictionary = {}
	for level: Level in stages_seen["hard_2"]:
		sizes["%d/%d" % [level.get_peg_count(), level.get_disk_count()]] = true
	assert_true(sizes.size() >= 2, "variety inside a stage: %s" % str(sizes.keys()))


func test_stage_table_matches_the_correction() -> void:
	var expected: Array = [
		["intro", 30, [4, 4], [2, 2], [1, 1], [3, 3]],
		["middle_1", 80, [5, 5], [3, 3], [1, 1], [4, 4]],
		["middle_2", 130, [6, 6], [3, 4], [1, 2], [5, 6]],
		["hard_1", 200, [7, 8], [4, 5], [2, 2], [6, 7]],
		["hard_2", 280, [8, 9], [5, 6], [2, 3], [7, 9]],
		["expert", 100000, [9, 12], [6, 7], [3, 4], [9, 11]],
	]
	for i: int in expected.size():
		var stage: Dictionary = Difficulty.COMBINATION_STAGES[i]
		assert_eq([stage["name"], stage["to"], stage["capacity"], stage["colours"], stage["empty"], stage["pegs"]], expected[i])
	assert_eq(Difficulty.combination_stage(30)["name"], "intro")
	assert_eq(Difficulty.combination_stage(31)["name"], "middle_1")
	assert_eq(Difficulty.combination_stage(265)["name"], "hard_2")
	assert_true(ColorGoal.LETTERS.size() >= 7, "enough colours for the expert stage")
	for color_name: String in ColorGoal.LETTERS:
		assert_true(ThemeManager.COMBINATION_DISKS.has(color_name), "%s has a look" % color_name)
	assert_eq(Difficulty.COMBINATION, CombinationRule.ID)


func test_capacity_rule() -> void:
	var errors: Array[String] = []
	assert_null(RuleSet.from_ids([CombinationRule.ID], {}, errors), "a capacity is required")
	assert_null(RuleSet.from_ids([CombinationRule.ID], {CombinationRule.ID: {"capacity": 0}}, errors))
	var rules: RuleSet = RuleSet.from_ids([CombinationRule.ID], {CombinationRule.ID: {"capacity": 2}})
	var state: PuzzleState = PuzzleState.new([[4, 1], [2], [3]])
	assert_true(rules.is_move_legal(state, Move.new(0, 1)), "any disk onto any disk: sizes do not count")
	assert_false(rules.is_move_legal(state, Move.new(1, 0)), "but not onto a full peg")
	assert_eq(rules.get_violation_message(state, Move.new(1, 0)), "RULE_PEG_FULL")
	assert_false(rules.is_state_valid(PuzzleState.new([[1, 2, 3], [], []])), "over capacity")


func test_solvers() -> void:
	var sort: ColorGoal = ColorGoal.sort()
	var exact: Dictionary = CombinationSolver.search(PackedStringArray(["rb", "rb", ""]), 2, sort)
	assert_eq(exact["min_moves"], 3, "blue aside, red across, blue on blue")
	var pattern: ColorGoal = ColorGoal.pattern([["red", "blue", "red"], ["blue", "red", "blue"], [], []])
	var start: PackedStringArray = PackedStringArray(["bbr", "", "rrb", ""])
	var guided: Dictionary = CombinationSolver.guided_search(start, 3, pattern, 20000)
	assert_true(guided["solvable"])
	var pegs: PackedStringArray = start
	for move: Move in guided["path"]:
		assert_true(pegs[move.from_peg].length() > 0 and pegs[move.to_peg].length() < 3, "legal")
		pegs = _move(pegs, move)
	assert_true(pattern.matches(pegs), "the guided path reaches the goal")
	assert_eq(CombinationSolver.heuristic(pattern.target_letters(), pattern), 0.0)
	assert_true(CombinationSolver.heuristic(start, pattern) > 0.0)
	# shorten(): a disk moved twice goes straight there; one moved back stays.
	var detour: Array[Move] = [Move.new(0, 1), Move.new(1, 3), Move.new(2, 1), Move.new(1, 2)]
	var short: Array[Move] = CombinationSolver.shorten(start, detour)
	assert_eq(short.size(), 1)
	assert_true(short[0].equals(Move.new(0, 3)))
	# scramble(): walked back, every position on the walk is solved.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3
	var walk: Dictionary = CombinationSolver.scramble(pattern.target_letters(), 3, 60, rng)
	var keys: PackedStringArray = walk["keys"]
	pegs = keys[-1].split("|")
	for move: Move in CombinationSolver.walk_back(walk, keys.size() - 1):
		pegs = _move(pegs, move)
	assert_true(pattern.matches(pegs))


func _move(pegs: PackedStringArray, move: Move) -> PackedStringArray:
	var next: PackedStringArray = pegs.duplicate()
	next[move.to_peg] += pegs[move.from_peg].right(1)
	next[move.from_peg] = pegs[move.from_peg].left(-1)
	return next


func test_level_format_and_checks() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_20.json")
	var errors: Array[String] = []
	var copy: Level = Level.from_dict(level.to_dict(), errors)
	assert_eq(errors, [] as Array[String])
	assert_eq(copy.disk_colors, level.disk_colors)
	assert_eq(copy.color_goal.to_dict(), level.color_goal.to_dict())
	assert_eq(level.mechanic(), CombinationRule.ID)
	assert_true(level.example_solution(), "min_moves is an example solution")
	copy.check(errors)
	assert_eq(errors, [] as Array[String])
	copy.rule_ids = ["classic_hanoi", CombinationRule.ID] as Array[String]
	copy.check(errors)
	assert_true(" ".join(errors).contains("alone"), str(errors))
	errors.clear()
	copy = Level.from_dict(level.to_dict(), errors)
	copy.goal = copy.start.duplicate_state()
	copy.solution_path.clear()
	copy.check(errors)
	assert_true(" ".join(errors).contains("does not meet the colour goal"), str(errors))
	# The stored solution proves it solvable; small boards also prove it shortest.
	var small: Level = LevelCatalog.load_mechanic("combo_01.json")
	errors.clear()
	LevelValidator.validate_level(small, errors)
	assert_eq(errors, [] as Array[String])
	small.min_moves += 1
	small.solution_path.append(Move.new(0, 0))
	errors.clear()
	LevelValidator.validate_level(small, errors)
	assert_false(errors.is_empty(), "a longer stored solution on a small board is caught")


func test_chapter_on_the_road() -> void:
	var road: Array[Dictionary] = _on_road()
	for entry: Dictionary in road:
		if (entry["level"] as Level).difficulty == "easy":
			assert_true(entry["position"] <= PathBuilder.EASY_UNTIL, "easy only while learning (%d)" % entry["position"])
	assert_true(road[-1]["position"] > PathBuilder.MIX_UNTIL, "to the end of the road (%d)" % road[-1]["position"])


func test_session_wins_by_colour() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_01.json")
	var session: GameSession = GameSession.new(level)
	assert_true(session.get_path_hint().equals(level.solution_path[0]), "on the stored path the hint is instant")
	for move: Move in level.solution_path:
		assert_false(session.is_solved())
		assert_true(session.try_move(move))
	assert_true(session.is_solved())
	assert_eq(level.stars_for_moves(level.min_moves), 3)
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


func test_hint_off_the_path_finds_a_way_or_leads_back() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_30.json")
	var session: GameSession = GameSession.new(level)
	assert_null(session.return_to_path_move(), "on the path there is nothing to take back")
	var off_path: Move = null
	for move: Move in session.rules.get_legal_moves(session.state):
		if not move.equals(level.solution_path[0]):
			off_path = move
			break
	session.try_move(off_path)
	var back: Move = session.return_to_path_move()
	assert_true(back.equals(Move.new(off_path.to_peg, off_path.from_peg)), "the last move taken back")
	var hint: Move = GameSession.solve_hint(level, session.state.duplicate_state(), session.rules)
	if hint != null:
		assert_true(session.rules.is_move_legal(session.state, hint), "a found hint is legal")
	_start_board(level)
	_board.on_peg_pressed(off_path.from_peg)
	_board.on_peg_pressed(off_path.to_peg)
	_board.economy.earn(50, "test")
	_board.request_hint()
	assert_not_null(_board.hints.hint_move, "a large board always gets a hint")


func test_board_shows_colours_and_example_solution() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_01.json")
	_start_board(level)
	assert_eq(_board.get_board_skin().skin, "glass", "a modern dress")
	assert_eq((_board.get_node("%MinLabel") as Label).text, tr("BOARD_EXAMPLE") % level.min_moves, "no false claim of a minimum")
	var widths: Array[float] = []
	for view: DiskView in _board.get_node("%DiskLayer").get_children():
		var color_name: String = level.disk_colors[view.disk_size - 1]
		assert_eq(view.symbol, color_name, "a shape, not a number")
		assert_eq(view.color, ThemeManager.COMBINATION_DISKS[color_name]["fill"])
		if not widths.has(snappedf(view.size.x, 0.1)):
			widths.append(snappedf(view.size.x, 0.1))
	assert_eq(widths.size(), 1, "every disk the same size %s" % str(widths))
	var peg: PegView = _board.get_node("%PegLayer").get_child(0)
	var disk_height: float = _board.get_disk_rect(1).size.y + 4.0
	assert_true(absf((peg.base_top - peg.rod_top) - disk_height * (CombinationSolver.capacity_of(level) + 0.3)) < 1.0,
			"the rod is as tall as the peg holds")
	var preview: BoardPreview = _board.get_node("%GoalPreview")
	assert_eq(preview.sort_colours().size(), 2, "an icon for every colour on the board")
	var status: Label = _board.get_node("%StatusLabel")
	assert_eq(status.text, tr("COMBINATION_SORT_INTRO"), "a sort goal is told in words")
	_board.restart()
	assert_eq(status.text, tr("COMBINATION_SORT_INTRO"), "on every attempt")
	for move: Move in level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_true(_board.session.is_solved())
	assert_eq(_board.last_result["stars"], 3, "matching the example solution earns three stars")
	assert_eq(preview.finished_colours().size(), 2, "every colour checked off")
	assert_eq(status.text, tr("BOARD_SOLVED_EXAMPLE") % [level.min_moves, level.min_moves])


func test_large_board_stands_in_two_rows_and_shows_every_target() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_30.json")
	_start_board(level)
	var rows: Dictionary = {}
	var board: Control = _board.get_node("%Board")
	for peg: PegView in _board.get_node("%PegLayer").get_children():
		rows[peg.position.y] = true
		assert_true(peg.position.x >= 0.0 and peg.position.x + peg.size.x <= board.size.x + 0.5, "inside the board")
	assert_eq(rows.size(), 2, "%d pegs in two rows" % level.get_peg_count())
	var status: Label = _board.get_node("%StatusLabel")
	assert_eq(status.text, "", "a pattern goal is only shown")
	var preview: BoardPreview = _board.get_node("%GoalPreview")
	assert_eq(preview.color_goal.targets.size(), level.get_peg_count(), "a target for every peg")
	for move: Move in level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_true(_board.session.is_solved())
	for peg_index: int in level.get_peg_count():
		assert_eq(preview.placed_on(peg_index), level.color_goal.targets[peg_index].size(), "peg %d in place" % peg_index)
