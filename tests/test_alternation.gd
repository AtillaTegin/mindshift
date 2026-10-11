extends "res://tests/test_case.gd"
## Nine Rings alternation (cultural integration addendum 1, variant D): the
## rule, the last moved disk in positions, the Solver's history search, the
## board feedback and the level files.

const SAVE_PATH: String = "res://.test_saves/test_alternation_save.json"
const RULES: Array[String] = ["classic_hanoi", "alternation"]
const RINGS_FILES: Array[String] = ["rings_01.json", "rings_02.json", "rings_03.json", "rings_04.json"]

var _board: GameBoard


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func _rules() -> RuleSet:
	return RuleSet.from_ids(RULES)


## Independent shortest-path oracle: plain BFS over (nested arrays, last disk)
## with both rules written out here, sharing no code with RuleSet or Solver.
static func _oracle_min_moves(start: Array, goal: Array) -> int:
	var target: String = JSON.stringify(goal)
	var seen: Dictionary = {JSON.stringify([start, 0]): true}
	var frontier: Array = [[start, 0]]
	var depth: int = 0
	while not frontier.is_empty():
		var next: Array = []
		for item: Array in frontier:
			var pegs: Array = item[0]
			var last: int = item[1]
			if JSON.stringify(pegs) == target:
				return depth
			for a: int in pegs.size():
				if pegs[a].is_empty():
					continue
				var disk: int = pegs[a][-1]
				if not (disk == 1 or last == 1 or absi(disk - last) == 1):
					continue
				for b: int in pegs.size():
					if a == b or (not pegs[b].is_empty() and pegs[b][-1] < disk):
						continue
					var moved: Array = pegs.duplicate(true)
					moved[b].append(moved[a].pop_back())
					var moved_key: String = JSON.stringify([moved, disk])
					if not seen.has(moved_key):
						seen[moved_key] = true
						next.append([moved, disk])
		frontier = next
		depth += 1
	return -1


func test_rule_variant_d() -> void:
	var rule: AlternationRule = AlternationRule.new()
	assert_true(rule.is_disk_movable(1, 0), "disk 1 at the start")
	for disk: int in range(2, 8):
		assert_false(rule.is_disk_movable(disk, 0), "nothing else before the first move (%d)" % disk)
		assert_true(rule.is_disk_movable(disk, 1), "after disk 1 any disk (%d)" % disk)
	assert_true(rule.is_disk_movable(1, 5), "disk 1 always")
	assert_true(rule.is_disk_movable(4, 5))
	assert_true(rule.is_disk_movable(6, 5))
	assert_false(rule.is_disk_movable(3, 5), "two sizes away")
	assert_false(rule.is_disk_movable(5, 5), "not the same disk twice in a row")
	assert_true(rule.uses_last_move())
	assert_eq(_rules().get_rule_ids(), RULES)
	assert_null(RuleSet.from_ids(RULES, {"alternation": {"x": 1}}), "takes no settings")


func test_positions_remember_the_last_moved_disk_without_changing_identity() -> void:
	var rules: RuleSet = _rules()
	var start: PuzzleState = PuzzleState.new([[3, 2], [1], [], []])
	assert_eq(start.last_moved_disk, 0)
	var after: PuzzleState = rules.apply_move(start, Move.new(1, 2))
	assert_eq(after.last_moved_disk, 1)
	assert_eq(after.duplicate_state().last_moved_disk, 1, "copies keep it")
	var same: PuzzleState = PuzzleState.new([[3, 2], [], [1], []])
	assert_true(after.equals(same), "not part of the position")
	assert_eq(after.hash_key(), same.hash_key())
	assert_ne(rules.search_key(after), rules.search_key(same), "but searches tell them apart")
	assert_eq(RuleSet.classic().search_key(after), RuleSet.classic().search_key(same), "classic searches do not")


func test_moves_follow_the_rule() -> void:
	var rules: RuleSet = _rules()
	var state: PuzzleState = PuzzleState.new([[5, 3], [4, 2], [1], []])
	assert_false(rules.can_pick_up(state, 0), "only disk 1 may open the game")
	assert_true(rules.can_pick_up(state, 2))
	assert_eq(rules.get_pick_up_violation_message(state, 0), "RULE_ALTERNATION")
	assert_eq(rules.get_violation_message(state, Move.new(0, 3)), "RULE_ALTERNATION")
	state = rules.apply_move(state, Move.new(2, 3))  # disk 1
	assert_true(rules.can_pick_up(state, 0), "after disk 1 any disk: 3")
	assert_true(rules.can_pick_up(state, 1), "and 2")
	state = rules.apply_move(state, Move.new(0, 2))  # disk 3
	assert_true(rules.can_pick_up(state, 1), "after 3: its neighbour 2")
	assert_false(rules.can_pick_up(state, 0), "but not 5")
	assert_true(rules.can_pick_up(state, 3), "and always disk 1")


func test_solver_history_search_matches_the_oracle() -> void:
	var rules: RuleSet = _rules()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261012
	var longer: int = 0
	for i: int in 12:
		var pegs: int = 4
		var disks: int = 4 + i % 2
		var start: PuzzleState = LevelGenerator.random_state(rng, pegs, disks)
		var goal: PuzzleState = LevelGenerator.tower_state(pegs, disks, rng.randi_range(0, pegs - 1))
		if start.equals(goal):
			continue
		var result: Dictionary = Solver.solve(start, goal, rules)
		assert_eq(result["strategy"], "packed_history")
		assert_eq(result["min_moves"], _oracle_min_moves(start.to_array(), goal.to_array()), "puzzle %d" % i)
		var state: PuzzleState = start
		for move: Move in result["path"]:
			state = rules.apply_move(state, move)
			assert_not_null(state, "every step of the path is legal")
		assert_true(state.equals(goal))
		if result["min_moves"] > Solver.solve(start, goal, RuleSet.classic())["min_moves"]:
			longer += 1
	assert_true(longer >= 6, "on 4 pegs the rule usually adds moves (%d of 12)" % longer)


func test_solver_starts_from_the_last_moved_disk() -> void:
	# Mid-game hints start from a position whose last move counts.
	var rules: RuleSet = _rules()
	var state: PuzzleState = PuzzleState.new([[4, 3], [2], [1], []])
	var goal: PuzzleState = PuzzleState.new([[4], [2], [1], [3]])
	state.last_moved_disk = 1
	assert_eq(Solver.solve(state, goal, rules)["min_moves"], 1, "after disk 1, disk 3 may go at once")
	state.last_moved_disk = 2
	assert_eq(Solver.solve(state, goal, rules)["min_moves"], 1, "3 is 2's neighbour")
	state.last_moved_disk = 0
	assert_true(Solver.solve(state, goal, rules)["min_moves"] > 1, "at the start disk 1 must go first")


func test_session_hints_and_undo_keep_the_last_move() -> void:
	var level: Level = LevelCatalog.load_mechanic(RINGS_FILES[0])
	var session: GameSession = GameSession.new(level)
	for i: int in level.solution_path.size():
		var hint: Dictionary = session.get_hint()
		assert_true(hint["from_path"], "step %d comes from the stored path" % i)
		assert_true(session.try_move(hint["move"]))
	assert_true(session.is_solved())
	session.restart()
	session.try_move(level.solution_path[0])
	var last: int = session.state.last_moved_disk
	assert_ne(last, 0)
	session.try_move(Move.new(level.solution_path[0].to_peg, level.solution_path[0].from_peg))
	session.undo()
	assert_eq(session.state.last_moved_disk, last, "undo brings the last move back too")


func test_board_rings_the_disks_that_may_go_and_refuses_the_others() -> void:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.tutorials_enabled = false
	_board.background_hints = false
	_board.level_path = LevelCatalog.mechanic_path(RINGS_FILES[1])
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	var state: PuzzleState = _board.session.state
	var disks: Node = _board.get_node("%DiskLayer")
	var ringed: Array[int] = []
	for view: DiskView in disks.get_children():
		if view.movable_ring:
			ringed.append(view.disk_size)
			assert_eq(view.ring_color, ThemeManager.skin_color("jade", "mark"), "jade rings")
	assert_eq(ringed, [1] as Array[int], "only disk 1 may open the game")
	assert_eq(_board.get_board_skin().skin, "jade", "the Nine Rings dress")
	var blocked: int = -1
	for peg: int in state.get_peg_count():
		var top: int = state.get_top_disk(peg)
		if top > 1:
			blocked = peg
	assert_true(blocked >= 0)
	var refused: Array = []
	_board.pick_up_refused.connect(func(p: int, message: String) -> void: refused.append([p, message]))
	_board.on_peg_pressed(blocked)
	assert_eq(_board.session.selected_peg, -1, "nothing picked up, nothing punished")
	assert_eq(_board.session.move_count, 0)
	var text: String = tr("RULE_ALTERNATION")
	assert_eq((_board.get_node("%StatusLabel") as Label).text, text)
	assert_eq((_board.get_node("%StatusLabel") as Label).theme_type_variation, &"SecondaryLabel", "a grey reminder, not a red warning")
	assert_eq(refused, [[blocked, text]])
	var first: Move = _board.session.level.solution_path[0]
	_board.on_peg_pressed(first.from_peg)
	_board.on_peg_pressed(first.to_peg)
	var after: Array[int] = []
	for view: DiskView in disks.get_children():
		if view.movable_ring:
			after.append(view.disk_size)
	assert_ne(after, ringed, "the rings follow the last move")


func test_rings_levels() -> void:
	var previous: int = 0
	for file_name: String in RINGS_FILES:
		var level: Level = LevelCatalog.load_mechanic(file_name)
		assert_eq(level.mechanic(), "alternation", file_name)
		assert_eq(level.get_peg_count(), 4, "%s: 4 pegs, where the rule matters" % file_name)
		assert_eq(level.difficulty, Difficulty.tier_for_moves(level.min_moves), file_name)
		assert_true(level.min_moves >= previous, "%s: easy to hard" % file_name)
		previous = level.min_moves
		var plain: int = Solver.solve(level.start, level.goal, RuleSet.classic())["min_moves"]
		assert_true(plain < level.min_moves, "%s: the rule adds moves (%d < %d)" % [file_name, plain, level.min_moves])
		assert_eq(LevelCatalog.place_of(level.id).get("track"), LevelCatalog.MAIN, "%s is on the road" % file_name)
		assert_eq(FileAccess.get_file_as_string(LevelCatalog.mechanic_path(file_name)), level.to_json(), "round trip")
		var errors: Array[String] = []
		LevelValidator.load_and_validate(LevelCatalog.mechanic_path(file_name), errors)
		assert_eq(errors, [] as Array[String], file_name)
	assert_false(FileAccess.file_exists(LevelCatalog.mechanic_path("frozen_01.json")), "the frozen disk is gone")
	assert_null(RuleSet.create_rule("frozen_disk"))


func test_validator_rejects_an_alternation_that_changes_nothing() -> void:
	# 3 pegs, a plain tower move: the classic optimum already alternates around disk 1.
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[], [], [3, 2, 1]])
	var level: Level = Level.create(9060, "easy", start, goal, RULES, Solver.solve(start, goal, _rules())["path"])
	assert_eq(level.min_moves, 7)
	var errors: Array[String] = []
	LevelValidator.validate_mechanic_design(level, errors)
	assert_true(" ".join(errors).contains("changes nothing"), str(errors))


func test_classic_level_files_keep_their_exact_form() -> void:
	# Backward compatibility: loading and writing a classic level gives the same bytes.
	for tier: String in Difficulty.ORDER:
		for index: int in [1, LevelCatalog.level_count(tier)]:
			var path: String = Difficulty.level_path(tier, index)
			assert_eq(LevelCatalog.load_level(tier, index).to_json(), FileAccess.get_file_as_string(path), path)
