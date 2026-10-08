extends "res://tests/test_case.gd"
## Frozen disk (bonus mechanics addendum 1): FrozenDiskRule, its use by the
## unchanged Solver, the board feedback and the bonus level files.

const SAVE_PATH: String = "res://.test_saves/test_frozen_disk_save.json"
const FROZEN_RULES: Array[String] = ["classic_hanoi", "frozen_disk"]

var _board: GameBoard


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func _frozen(size: int) -> RuleSet:
	return RuleSet.from_ids(FROZEN_RULES, {"frozen_disk": {"disk_size": size}})


## Independent shortest-path oracle: plain BFS over nested arrays with the two
## rules written out here, sharing no code with RuleSet or Solver.
static func _oracle_min_moves(start: Array, goal: Array, frozen: int) -> int:
	var key: Callable = func(pegs: Array) -> String: return JSON.stringify(pegs)
	var target: String = key.call(goal)
	var seen: Dictionary = {key.call(start): true}
	var frontier: Array = [start]
	var depth: int = 0
	while not frontier.is_empty():
		var next: Array = []
		for pegs: Array in frontier:
			if key.call(pegs) == target:
				return depth
			for a: int in pegs.size():
				if pegs[a].is_empty() or pegs[a][-1] == frozen:
					continue
				for b: int in pegs.size():
					if a == b or (not pegs[b].is_empty() and pegs[b][-1] < pegs[a][-1]):
						continue
					var moved: Array = pegs.duplicate(true)
					moved[b].append(moved[a].pop_back())
					var moved_key: String = key.call(moved)
					if not seen.has(moved_key):
						seen[moved_key] = true
						next.append(moved)
		frontier = next
		depth += 1
	return -1


func test_rule_settings_come_from_rule_params() -> void:
	var rules: RuleSet = _frozen(3)
	assert_not_null(rules)
	assert_eq(rules.get_rule_ids(), FROZEN_RULES)
	assert_eq(rules.get_rule_params(), {"frozen_disk": {"disk_size": 3}})
	assert_not_null(RuleSet.from_ids(FROZEN_RULES, {"frozen_disk": {"disk_size": 3.0}}), "JSON floats are fine")
	for bad: Variant in [{}, {"frozen_disk": {}}, {"frozen_disk": {"disk_size": "3"}}, {"frozen_disk": {"disk_size": 2.5}},
			{"frozen_disk": {"disk_size": 0}}, {"frozen_disk": {"disk_size": 3, "x": 1}}, {"frozen_disk": 3}]:
		var errors: Array[String] = []
		assert_null(RuleSet.from_ids(FROZEN_RULES, bad, errors), str(bad))
		assert_false(errors.is_empty(), "reason given for %s" % str(bad))
	var errors: Array[String] = []
	assert_null(RuleSet.from_ids(["classic_hanoi"], {"frozen_disk": {"disk_size": 3}}, errors), "params for an unused rule")
	assert_null(RuleSet.from_ids(["classic_hanoi"], {"classic_hanoi": {"x": 1}}), "classic takes no settings")
	assert_eq(RuleSet.classic().get_rule_params(), {})


func test_frozen_disk_never_moves_but_takes_smaller_disks() -> void:
	var rules: RuleSet = _frozen(3)
	var state: PuzzleState = PuzzleState.new([[5, 3], [4, 2, 1], [], []])
	for move: Move in rules.get_legal_moves(state):
		assert_ne(move.from_peg, 0, "the frozen disk is never a source")
	assert_true(rules.is_move_legal(state, Move.new(1, 0)), "disk 1 may rest on the frozen 3")
	assert_false(rules.can_pick_up(state, 0))
	assert_true(rules.can_pick_up(state, 1))
	assert_eq(rules.get_pick_up_violation_message(state, 0), "RULE_FROZEN_DISK")
	assert_eq(rules.get_violation_message(state, Move.new(0, 2)), "RULE_FROZEN_DISK")
	assert_false(rules.is_disk_movable(3))
	assert_true(rules.is_disk_movable(4))


func test_solver_finds_the_minimum_with_a_frozen_middle_disk() -> void:
	# Acceptance: 4 pegs / 5 disks, the middle disk (3) frozen. Expected minimum,
	# worked out by hand: 4 must go to peg 3 (1 move), 2 must reach peg 0 (1
	# move), and 1 sits under where 2 goes, so it must leave peg 0 and come back
	# (2 moves): at least 4, and 1->2, 2->0, 1->0, 4->3 does it in 4.
	var start: PuzzleState = PuzzleState.new([[5, 3, 1], [4, 2], [], []])
	var goal: PuzzleState = PuzzleState.new([[5, 3, 2, 1], [], [], [4]])
	const EXPECTED: int = 4
	var result: Dictionary = Solver.solve(start, goal, _frozen(3))
	assert_true(result["solvable"])
	assert_eq(result["min_moves"], EXPECTED)
	assert_eq(_oracle_min_moves(start.to_array(), goal.to_array(), 3), EXPECTED, "independent oracle agrees")
	assert_eq(result["strategy"], "packed", "the fast path still applies; the Solver was not changed")
	var state: PuzzleState = start
	for move: Move in result["path"]:
		assert_ne(state.get_top_disk(move.from_peg), 3, "the path never moves the frozen disk")
		state = _frozen(3).apply_move(state, move)
	assert_true(state.equals(goal))


func test_solver_matches_the_oracle_where_the_freeze_matters() -> void:
	for file_name: String in ["frozen_01.json", "frozen_02.json"]:
		var level: Level = LevelCatalog.load_bonus(file_name)
		var frozen: int = level.rule_params["frozen_disk"]["disk_size"]
		assert_eq(Solver.solve(level.start, level.goal, level.get_rule_set())["min_moves"], level.min_moves, file_name)
		assert_eq(_oracle_min_moves(level.start.to_array(), level.goal.to_array(), frozen), level.min_moves,
				"%s: oracle agrees" % file_name)
		var plain: int = Solver.solve(level.start, level.goal, RuleSet.classic())["min_moves"]
		assert_true(plain < level.min_moves, "%s: the freeze makes it longer (%d < %d)" % [file_name, plain, level.min_moves])


func test_session_refuses_to_pick_up_the_frozen_disk() -> void:
	var start: PuzzleState = PuzzleState.new([[5, 3], [4, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[5, 3, 1], [4, 2], [], []])
	var path: Array[Move] = [Move.new(1, 0)]
	var session: GameSession = GameSession.new(Level.create(9050, "bonus", start, goal, FROZEN_RULES, path,
			{"frozen_disk": {"disk_size": 3}}))
	assert_eq(session.tap_peg(0), GameSession.TapResult.BLOCKED)
	assert_eq(session.selected_peg, -1)
	assert_eq(session.tap_peg(1), GameSession.TapResult.SELECTED)
	assert_eq(session.tap_peg(0), GameSession.TapResult.MOVED, "landing on the frozen disk is fine")
	assert_true(session.is_solved())


func test_board_shows_ice_and_wobbles_on_tap() -> void:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.tutorials_enabled = false
	_board.background_hints = false
	_board.level_path = LevelCatalog.bonus_dir() + "/frozen_01.json"
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	var frozen: int = _board.session.level.rule_params["frozen_disk"]["disk_size"]
	assert_eq((_board.get_node("%LevelLabel") as Label).text, "Bonus · 1")
	assert_eq((_board.get_node("%HintButton") as Button).text, "Hint · 3 coin", "priced like its tab (easy)")
	var disks: Node = _board.get_node("%DiskLayer")
	for view: DiskView in disks.get_children():
		assert_eq(view.frozen, view.disk_size == frozen, "only disk %d looks frozen" % frozen)
	assert_eq((_board.get_node("%GoalPreview") as BoardPreview).pinned_disks, [frozen] as Array[int])
	var peg: int = -1
	for i: int in _board.session.state.get_peg_count():
		if _board.session.state.get_top_disk(i) == frozen:
			peg = i
	assert_true(peg >= 0, "the frozen disk is on top somewhere in frozen_01")
	var refused: Array = []
	_board.pick_up_refused.connect(func(p: int, message: String) -> void: refused.append([p, message]))
	_board.on_peg_pressed(peg)
	assert_eq(_board.session.selected_peg, -1, "nothing picked up")
	assert_eq(_board.session.move_count, 0)
	var view: DiskView = null
	for candidate: DiskView in disks.get_children():
		if candidate.disk_size == frozen:
			view = candidate
	assert_true(view.is_wobbling(), "the disk wobbles")
	var text: String = tr("RULE_FROZEN_DISK")
	assert_eq((_board.get_node("%StatusLabel") as Label).text, text)
	assert_eq(refused, [[peg, text]])
	assert_eq(_board.hints.nudge.mistakes_in_a_row, 1, "counts as a mistake for the hint nudge")


func test_main_level_files_keep_their_exact_form() -> void:
	# Backward compatibility: loading and writing a main level gives the same bytes.
	for tier: String in Difficulty.ORDER:
		for index: int in range(1, LevelCatalog.level_count(tier) + 1):
			var path: String = Difficulty.level_path(tier, index)
			var level: Level = LevelCatalog.load_level(tier, index)
			assert_eq(level.rule_params, {})
			assert_eq(level.to_json(), FileAccess.get_file_as_string(path), path)


func test_bonus_level_round_trip() -> void:
	var level: Level = LevelCatalog.load_bonus("frozen_03.json")
	assert_true(level.is_bonus())
	assert_eq(Level.from_dict(JSON.parse_string(level.to_json()), [] as Array[String]).to_json(), level.to_json())
	assert_eq(FileAccess.get_file_as_string(LevelCatalog.bonus_dir() + "/frozen_03.json"), level.to_json())


func test_validator_checks_the_bonus_design() -> void:
	# A frozen bottom disk is just a peg base.
	var start: PuzzleState = PuzzleState.new([[4], [3, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[4], [], [], [3, 2, 1]])
	var rules: RuleSet = _frozen(4)
	var level: Level = Level.create(9060, "bonus", start, goal, FROZEN_RULES, Solver.solve(start, goal, rules)["path"],
			{"frozen_disk": {"disk_size": 4}})
	var errors: Array[String] = []
	LevelValidator.validate_bonus_design(level, errors)
	var text: String = " ".join(errors)
	assert_true(text.contains("bottom disk"), text)
	assert_true(text.contains("changes nothing"), text)
	assert_eq(LevelValidator.validate_bonus_index(Difficulty.LEVELS_DIR), [] as Array[String], "index is valid")
	for entry: Dictionary in LevelCatalog.bonus_entries():
		var file_errors: Array[String] = []
		LevelValidator.load_and_validate(LevelCatalog.bonus_dir() + "/" + entry["file"], file_errors)
		assert_eq(file_errors, [] as Array[String], entry["file"])


func test_bonus_levels_never_count_toward_unlocking() -> void:
	var save: SaveSystem = SaveSystem.new(SAVE_PATH)
	for entry: Dictionary in LevelCatalog.bonus_entries():
		save.record_completion(entry["id"], 3, 10, 10.0)
		assert_eq(Difficulty.tier_of_id(entry["id"]), "")
	for tier: String in Difficulty.ORDER:
		assert_eq(save.completed_count(tier), 0, tier)
	assert_false(LevelCatalog.is_tier_unlocked("medium", save))
	assert_eq(LevelCatalog.bonus_for_tab("easy").size(), 1)
	assert_eq(LevelCatalog.bonus_for_tab("easy")[0]["file"], "frozen_01.json")
