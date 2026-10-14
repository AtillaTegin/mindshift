extends "res://tests/test_case.gd"
## "Birləşmə Tapmacası" (combination puzzle): level structure v4 section 4 as
## corrected by v2 and v3, with Water Sort's rule from the auto-group addendum
## (user decision 2026-10-13): equal-sized disks in up to ten colours, pegs
## with a capacity, a disk only onto an empty peg or its own colour, the
## same-colour run at the top moving as one move. Water Sort's shape (N disks
## of each of C colours, E_min empty pegs) growing by stage along the road, a
## "Sadə Yığım" goal that names every disk, its own solvers, and stars against
## a stored example solution.

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


## A RuleSet of the combination rule for these disk colours.
func _rules(capacity: int, colours: Array[String]) -> RuleSet:
	var rules: RuleSet = RuleSet.from_ids([CombinationRule.ID], {CombinationRule.ID: {"capacity": capacity}})
	rules.bind_disk_colours(colours)
	return rules


func test_colour_goal_names_every_disk() -> void:
	var colours: Array[String] = ["red", "blue", "red", "blue"]
	var sort: ColorGoal = ColorGoal.sort()
	assert_true(sort.is_met(PuzzleState.new([[1, 3], [2, 4], []]), colours))
	assert_true(sort.is_met(PuzzleState.new([[], [4, 2], [3, 1]]), colours), "any peg, any order of equal disks")
	assert_false(sort.is_met(PuzzleState.new([[1], [2, 4], [3]]), colours), "all of a colour together")
	assert_eq(sort.progress(PuzzleState.new([[1, 3], [2], [4]]), colours), 2, "a finished peg counts")
	assert_eq(sort.progress_total(colours), 4)
	assert_eq(sort.goal_colours(colours), ["blue", "red"] as Array[String], "a sort goal names every colour")
	var errors: Array[String] = []
	sort.check(1, 2, colours, errors)
	assert_true(" ".join(errors).contains("a peg for each"), str(errors))
	errors.clear()
	sort.check(3, 1, colours, errors)
	assert_true(" ".join(errors).contains("do not fit"), str(errors))
	errors.clear()
	sort.check(3, 2, colours, errors)
	assert_eq(errors, [] as Array[String])
	assert_null(ColorGoal.from_dict({"kind": "pattern", "pegs": [["red"], []]}, errors),
			"Konkret Kombinasiya is gone with Water Sort's rule")
	assert_eq(ColorGoal.from_dict(sort.to_dict(), errors).to_dict(), sort.to_dict(), "round trip")


func test_every_level_has_a_goal_for_every_disk() -> void:
	# Correction v2, error 1: set(disk colours) == set(goal colours).
	for level: Level in _combo_levels():
		var board: Array[String] = []
		for color_name: String in level.disk_colors:
			if not board.has(color_name):
				board.append(color_name)
		board.sort()
		assert_eq(level.color_goal.goal_colours(level.disk_colors), board, "level %d" % level.id)
		assert_eq(level.color_goal.kind, ColorGoal.SORT, "level %d sorts" % level.id)


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
	assert_true(last.get_disk_count() >= 40 and last.get_peg_count() >= 7, "main %d is a large board" % road[-1]["position"])
	# Correction v3: boards grow by colours (and so pegs), never above 7 a peg.
	var previous_colours: int = 0
	for stage: String in ["intro", "middle_1", "middle_2", "hard_1", "hard_2"]:
		assert_true(stages_seen.has(stage), "%s is on the road" % stage)
		var most: int = 0
		for level: Level in stages_seen[stage]:
			most = maxi(most, level.color_goal.goal_colours(level.disk_colors).size())
			assert_true(CombinationSolver.capacity_of(level) <= Difficulty.COMBINATION_MAX_CAPACITY, "a peg holds at most 7")
		assert_true(most > previous_colours or stage == "middle_1", "%s brings more colours" % stage)
		previous_colours = maxi(previous_colours, most)
	var sizes: Dictionary = {}
	for level: Level in stages_seen["hard_2"]:
		sizes["%d/%d" % [level.get_peg_count(), level.get_disk_count()]] = true
	assert_true(sizes.size() >= 2, "variety inside a stage: %s" % str(sizes.keys()))


func test_stage_table_follows_the_correction() -> void:
	# Correction v3: N at most 7 everywhere, more colours stage by stage, and an
	# E_min measured for every colours x capacity a stage on the road can draw.
	var previous_colours: int = 0
	for stage: Dictionary in Difficulty.COMBINATION_STAGES:
		assert_true(stage["capacity"][1] <= Difficulty.COMBINATION_MAX_CAPACITY, "%s: N <= 7" % stage["name"])
		assert_true(stage["colours"][1] >= previous_colours, "%s: colours grow" % stage["name"])
		previous_colours = stage["colours"][1]
		if stage["tier"] == "expert":
			assert_true(stage == Difficulty.COMBINATION_STAGES[-1], "only past the end of the road")
			continue
		for colours: int in range(stage["colours"][0], stage["colours"][1] + 1):
			for capacity: int in range(stage["capacity"][0], stage["capacity"][1] + 1):
				assert_true(Difficulty.combination_empty(colours, capacity) >= 1, "E_min of %dx%d is measured" % [colours, capacity])
	assert_eq(Difficulty.combination_stage(30)["name"], "intro")
	assert_eq(Difficulty.combination_stage(31)["name"], "middle_1")
	assert_eq(Difficulty.combination_stage(LevelCatalog.track_length(MAIN))["tier"], "hard", "the road ends before the expert stage")
	# Measured under Water Sort's rule: one empty peg only for the smallest boards.
	assert_eq(Difficulty.combination_empty(2, 4), 1)
	assert_eq(Difficulty.combination_empty(3, 5), 2)
	assert_eq(Difficulty.combination_empty(10, 7), 2)
	assert_true(ColorGoal.LETTERS.size() >= 8, "enough colours for the largest boards")
	for color_name: String in ColorGoal.LETTERS:
		assert_true(ThemeManager.COMBINATION_DISKS.has(color_name), "%s has a look" % color_name)
	assert_eq(Difficulty.COMBINATION, CombinationRule.ID)


func test_every_colour_has_its_own_pips() -> void:
	# Correction v3, section 5: dice faces 1-6, then two groups "6 | k - 6".
	var seen: Array[int] = []
	for color_name: String in ColorGoal.LETTERS:
		var pips: int = DiskSymbols.pips_of(color_name)
		assert_false(seen.has(pips), "%s has a pip count of its own" % color_name)
		seen.append(pips)
		assert_true(DiskSymbols.width_of(color_name, 10.0) > (20.0 if pips > 6 else 19.0), "two groups past six")
	assert_eq(DiskSymbols.pips_of("red"), 1)
	# A board of up to six colours shows plain dice faces only.
	for level: Level in _combo_levels():
		var colours: Array[String] = level.color_goal.goal_colours(level.disk_colors)
		var largest: int = 0
		for color_name: String in colours:
			largest = maxi(largest, DiskSymbols.pips_of(color_name))
		assert_true(largest <= maxi(colours.size(), 6), "level %d: %s" % [level.id, str(colours)])


func test_water_sort_rule() -> void:
	var errors: Array[String] = []
	assert_null(RuleSet.from_ids([CombinationRule.ID], {}, errors), "a capacity is required")
	assert_null(RuleSet.from_ids([CombinationRule.ID], {CombinationRule.ID: {"capacity": 0}}, errors))
	# Disks 1-3 red, 4-6 blue.
	var colours: Array[String] = ["red", "red", "red", "blue", "blue", "blue"]
	var rules: RuleSet = _rules(3, colours)
	var state: PuzzleState = PuzzleState.new([[4, 1, 2], [5, 3], [6], []])
	assert_true(rules.is_move_legal(state, Move.new(0, 1)), "red onto red")
	assert_false(rules.is_move_legal(state, Move.new(0, 2)), "never onto another colour")
	assert_eq(rules.get_violation_message(state, Move.new(0, 2)), CombinationRule.COLOUR_MESSAGE)
	assert_true(rules.is_move_legal(state, Move.new(2, 3)), "anything onto an empty peg")
	# The whole top run moves, as much as fits, and counts as one move.
	assert_eq(rules.picked_up_disks(state, 0), [1, 2] as Array[int], "a tap lifts the red pair")
	var poured: PuzzleState = rules.apply_move(state, Move.new(0, 3))
	assert_eq(poured.pegs[0], [4])
	assert_eq(poured.pegs[3], [1, 2], "both reds, in the order they stood")
	var partial: PuzzleState = rules.apply_move(state, Move.new(0, 1))
	assert_eq(partial.pegs[1], [5, 3, 2], "only one fits on a peg of 3")
	assert_eq(partial.pegs[0], [4, 1], "the rest stays")
	var full: PuzzleState = PuzzleState.new([[1, 2, 3], [4], [5, 6], []])
	assert_false(rules.is_move_legal(full, Move.new(1, 0)), "not onto a full peg")
	assert_eq(rules.get_violation_message(full, Move.new(1, 0)), "RULE_PEG_FULL")
	assert_false(rules.is_state_valid(PuzzleState.new([[1, 2, 3, 4], [], [], []])), "over capacity")
	# A mixed start is normal (addendum, section 2): only moves are checked.
	assert_true(rules.is_state_valid(PuzzleState.new([[1, 4, 2], [5, 3, 6], [], []])))


func test_solvers() -> void:
	var sort: ColorGoal = ColorGoal.sort()
	var exact: Dictionary = CombinationSolver.search(PackedStringArray(["rb", "rb", ""]), 2, sort)
	assert_eq(exact["min_moves"], 3, "blue aside, red across, blue on blue")
	# A group pour is one move: "rrbb" sorts in one pour of both blues.
	assert_eq(CombinationSolver.search(PackedStringArray(["rrbb", ""]), 4, sort)["min_moves"], 1)
	assert_eq(CombinationSolver.apply(PackedStringArray(["rbb", "b", ""]), Vector2i(0, 1), 2), PackedStringArray(["rb", "bb", ""]),
			"only what fits is poured")
	assert_false(CombinationSolver.is_legal(PackedStringArray(["rb", "r", ""]), Vector2i(0, 1), 3), "blue never onto red")
	# Dead ends exist: nothing can move, and search proves it unsolvable.
	var stuck: Dictionary = CombinationSolver.search(PackedStringArray(["rb", "br"]), 2, sort)
	assert_false(stuck["solvable"])
	assert_false(stuck["limit_reached"])
	var start: PackedStringArray = PackedStringArray(["rbgr", "gbrb", "bgrg", "", ""])
	var guided: Dictionary = CombinationSolver.guided_search(start, 4, sort, 20000)
	assert_true(guided["solvable"])
	assert_true(CombinationSolver.solves(start, guided["path"], 4, sort), "the guided path is legal and reaches the goal")
	assert_eq(CombinationSolver.heuristic(PackedStringArray(["rrr", "bb", ""])), 0.0)
	assert_eq(CombinationSolver.heuristic(PackedStringArray(["rb", "r", "b"])), 2.0, "the blue on top, one of the red bottoms")
	# shorten(): moves the solution does not need are dropped, the rest still solves.
	var detour: Array[Move] = [Move.new(0, 2), Move.new(2, 0)]
	detour.append_array(exact["path"])
	var short: Array[Move] = CombinationSolver.shorten(PackedStringArray(["rb", "rb", ""]), detour, 2, sort)
	assert_eq(short.size(), 3)
	assert_true(CombinationSolver.solves(PackedStringArray(["rb", "rb", ""]), short, 2, sort))


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


func test_hint_off_the_path_finds_a_way_or_asks_to_take_back() -> void:
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
	if back != null:
		var before: PuzzleState = session.rules.apply_move(session.state, back)
		assert_true(before.equals(level.start), "taking back really restores the start")
	var hint: Move = GameSession.solve_hint(level, session.state.duplicate_state(), session.rules)
	assert_not_null(hint, "the guided search finds a way on the largest board")
	assert_true(session.rules.is_move_legal(session.state, hint), "a found hint is legal")
	_start_board(level)
	_board.on_peg_pressed(off_path.from_peg)
	_board.on_peg_pressed(off_path.to_peg)
	_board.economy.earn(50, "test")
	_board.request_hint()
	assert_not_null(_board.hints.hint_move, "a large board gets a hint")


func test_dead_end_hint_asks_to_take_back() -> void:
	# Pours cannot always be poured back; a stuck position gets an honest word.
	var level: Level = LevelCatalog.load_mechanic("combo_01.json")
	_start_board(level)
	var session: GameSession = _board.session
	var stuck: PuzzleState = null
	var start: PackedStringArray = ColorGoal.letters_of(level.start, level.disk_colors)
	for move: Vector2i in CombinationSolver.moves_of(start, 4):
		var next: PackedStringArray = CombinationSolver.apply(start, move, 4)
		if not CombinationSolver.search(next, 4, level.color_goal)["solvable"]:
			stuck = session.rules.apply_move(level.start, Move.new(move.x, move.y))
			session.try_move(Move.new(move.x, move.y))
			break
	if stuck == null:
		return  # this start has no dead end one move away
	_board.economy.earn(50, "test")
	var coins: int = _board.economy.coins
	_board.request_hint()
	var hint: Move = _board.hints.hint_move
	if hint == null:
		assert_eq((_board.get_node("%StatusLabel") as Label).text, tr("HINT_TAKE_BACK"))
		assert_eq(_board.economy.coins, coins, "a hint that finds nothing is free")
	else:
		assert_true(session.rules.is_move_legal(session.state, hint), "or a legal way back")


func test_board_shows_colours_and_example_solution() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_01.json")
	_start_board(level)
	assert_eq(_board.get_board_skin().skin, "glass", "a modern dress")
	assert_eq((_board.get_node("%MinLabel") as Label).text, tr("BOARD_EXAMPLE") % level.min_moves, "no false claim of a minimum")
	var widths: Array[float] = []
	for view: DiskView in _board.get_node("%DiskLayer").get_children():
		var color_name: String = level.disk_colors[view.disk_size - 1]
		assert_eq(view.symbol, color_name, "pips, not a number")
		assert_eq(view.color, ThemeManager.COMBINATION_DISKS[color_name]["fill"])
		assert_eq(view.corner, BoardLayout.BLOCK_RADIUS, "a block, not a pill")
		assert_true(absf(view.size.y - BoardLayout.BLOCK_HEIGHT) < 0.5, "34 high when the board has room")
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


func test_a_tap_lifts_the_whole_top_run() -> void:
	var level: Level = null
	var peg_index: int = -1
	for candidate: Level in _combo_levels():
		var rules: RuleSet = candidate.get_rule_set()
		for p: int in candidate.get_peg_count():
			if rules.picked_up_disks(candidate.start, p).size() >= 2:
				level = candidate
				peg_index = p
				break
		if level != null:
			break
	assert_not_null(level, "a start with two disks of one colour on top")
	_start_board(level)
	_board.on_peg_pressed(peg_index)
	var lifted: Array[int] = _board.session.get_selected_disks()
	assert_true(lifted.size() >= 2)
	var stack: Array = level.start.pegs[peg_index]
	var below: Rect2 = _board.get_disk_rect(stack[stack.size() - lifted.size() - 1]) if stack.size() > lifted.size() else Rect2()
	for i: int in lifted.size():
		var view: DiskView = (_board.get_node("%DiskLayer") as Node).get_children().filter(
				func(v: DiskView) -> bool: return v.disk_size == lifted[i])[0]
		assert_true(view.selected, "disk %d shows as picked up" % lifted[i])
		var rect: Rect2 = _board.get_disk_rect(lifted[i])
		if i > 0:
			assert_true(rect.position.y < _board.get_disk_rect(lifted[i - 1]).position.y, "the group keeps its order")
		if below.size != Vector2.ZERO:
			assert_true(rect.end.y < below.position.y - 1.0, "lifted clear of the stack")
	_board.on_peg_pressed(peg_index)
	assert_eq(_board.session.get_selected_disks(), [] as Array[int], "a second tap puts the group back")


func test_large_board_stands_in_two_rows_and_shows_every_colour() -> void:
	var level: Level = LevelCatalog.load_mechanic("combo_30.json")
	_start_board(level)
	var rows: Dictionary = {}
	var board: Control = _board.get_node("%Board")
	for peg: PegView in _board.get_node("%PegLayer").get_children():
		rows[peg.position.y] = true
		assert_true(peg.position.x >= 0.0 and peg.position.x + peg.size.x <= board.size.x + 0.5, "inside the board")
	assert_eq(rows.size(), 2, "%d pegs in two rows" % level.get_peg_count())
	var preview: BoardPreview = _board.get_node("%GoalPreview")
	var colours: int = level.color_goal.goal_colours(level.disk_colors).size()
	assert_eq(preview.sort_colours().size(), colours, "an icon for every colour on the board")
	for move: Move in level.solution_path:
		_board.on_peg_pressed(move.from_peg)
		_board.on_peg_pressed(move.to_peg)
	assert_true(_board.session.is_solved())
	assert_eq(preview.finished_colours().size(), colours)
