extends "res://tests/test_case.gd"
## The caravan road (caravan road addendum, section 1; Hanoi variant C): a disk
## only moves to a neighbouring peg. The rule, the Solver against an oracle, the
## levels and their place on the road, and the board's caravan dress.

const SAVE_PATH: String = "res://.test_saves/test_caravan_save.json"
const RULES: Array[String] = ["classic_hanoi", "adjacent_pegs"]
const MAIN: String = LevelCatalog.MAIN

var _board: GameBoard


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


## Independent shortest-path oracle: plain BFS over nested arrays with both
## rules written out here, sharing no code with RuleSet or Solver.
static func _oracle_min_moves(start: Array, goal: Array) -> int:
	var target: String = JSON.stringify(goal)
	var seen: Dictionary = {JSON.stringify(start): true}
	var frontier: Array = [start]
	var depth: int = 0
	while not frontier.is_empty():
		var next: Array = []
		for pegs: Array in frontier:
			if JSON.stringify(pegs) == target:
				return depth
			for a: int in pegs.size():
				if pegs[a].is_empty():
					continue
				for b: int in [a - 1, a + 1]:
					if b < 0 or b >= pegs.size() or (not pegs[b].is_empty() and pegs[b][-1] < pegs[a][-1]):
						continue
					var moved: Array = pegs.duplicate(true)
					moved[b].append(moved[a].pop_back())
					var key: String = JSON.stringify(moved)
					if not seen.has(key):
						seen[key] = true
						next.append(moved)
		frontier = next
		depth += 1
	return -1


func _caravan_files() -> Array[String]:
	var files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(Difficulty.LEVELS_DIR + "/" + Difficulty.MECHANICS):
		if file_name.begins_with("caravan_") and file_name.ends_with(".json"):
			files.append(file_name)
	files.sort()
	return files


func test_only_neighbouring_pegs() -> void:
	var rules: RuleSet = RuleSet.from_ids(RULES)
	var state: PuzzleState = PuzzleState.new([[3, 1], [], [2], []])
	assert_true(rules.is_move_legal(state, Move.new(0, 1)))
	assert_false(rules.is_move_legal(state, Move.new(0, 2)), "no jumping over a stop")
	assert_false(rules.is_move_legal(state, Move.new(0, 3)))
	assert_true(rules.is_move_legal(state, Move.new(2, 3)))
	assert_eq(rules.get_violation_message(state, Move.new(0, 3)), "RULE_ADJACENT_PEGS")
	assert_null(RuleSet.from_ids(RULES, {"adjacent_pegs": {"x": 1}}), "takes no settings")


func test_solver_matches_the_oracle() -> void:
	var rules: RuleSet = RuleSet.from_ids(RULES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261012
	for i: int in 10:
		var pegs: int = 3 + i % 2
		var start: PuzzleState = LevelGenerator.random_state(rng, pegs, 3)
		var goal: PuzzleState = LevelGenerator.tower_state(pegs, 3, rng.randi_range(0, pegs - 1))
		if start.equals(goal):
			continue
		var result: Dictionary = Solver.solve(start, goal, rules)
		assert_eq(result["strategy"], "packed", "the rule keeps the fast path")
		assert_eq(result["min_moves"], _oracle_min_moves(start.to_array(), goal.to_array()), "puzzle %d" % i)
	# The classic result for 3 pegs: an end-to-end tower of n disks takes 3^n - 1 moves.
	var tower: PuzzleState = LevelGenerator.tower_state(3, 3, 0)
	assert_eq(Solver.solve(tower, LevelGenerator.tower_state(3, 3, 2), rules)["min_moves"], 26)


func test_caravan_levels() -> void:
	var files: Array[String] = _caravan_files()
	assert_eq(files.size(), 30, "at least 30 caravan road levels")
	for file_name: String in files:
		var level: Level = LevelCatalog.load_mechanic(file_name)
		assert_eq(level.mechanic(), "adjacent_pegs", file_name)
		assert_true(level.min_moves <= 33, "%s fits the main road" % file_name)
		var plain: int = Solver.solve(level.start, level.goal, RuleSet.classic())["min_moves"]
		assert_true(plain < level.min_moves, "%s: the road adds moves" % file_name)
		var errors: Array[String] = []
		LevelValidator.load_and_validate(LevelCatalog.mechanic_path(file_name), errors)
		assert_eq(errors, [] as Array[String], file_name)


func test_caravan_road_runs_along_the_whole_road_easy_to_hard() -> void:
	var positions: Array[int] = []
	var previous: int = 0
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == "adjacent_pegs":
			positions.append(position)
			var moves: int = LevelCatalog.load_at(MAIN, position).min_moves
			assert_true(moves >= previous, "never easier than the one before (%d)" % position)
			previous = moves
	assert_eq(positions.size(), 30)
	assert_true(positions[0] >= 15 and positions[0] <= 20, "first at %d" % positions[0])
	for i: int in range(1, positions.size()):
		var gap: int = positions[i] - positions[i - 1]
		assert_true(gap >= 4 and gap <= 10, "gap %d at %d" % [gap, positions[i]])
	assert_true(LevelCatalog.track_length(MAIN) - positions[-1] <= 10, "to the end of the road")


func test_board_wears_the_caravan_dress_and_refuses_a_jump() -> void:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.tutorials_enabled = false
	_board.background_hints = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.start_level(LevelCatalog.load_mechanic("caravan_04.json"))
	_board.propagate_notification(Container.NOTIFICATION_SORT_CHILDREN)
	var skin: BoardSkin = _board.get_board_skin()
	assert_eq(skin.skin, "caravan")
	assert_eq(skin.peg_count, 5, "a stop under every peg")
	assert_true(skin.bottom_room() > 0.0)
	var board_height: float = (_board.get_node("%Board") as Control).size.y
	for peg: int in 5:
		var area: Rect2 = _board.get_peg_rect(peg)
		var bottom: float = area.end.y - (_board.get_node("%Board") as Control).global_position.y
		assert_true(bottom <= board_height - skin.bottom_room() + 0.5, "peg %d stands above the road" % peg)
	var state: PuzzleState = _board.session.state
	var from: int = -1
	for peg: int in 5:
		if not state.pegs[peg].is_empty() and peg + 2 < 5:
			from = peg
			break
	assert_true(from >= 0)
	var illegal: Array = []
	_board.illegal_move.connect(func(_move: Move, message: String) -> void: illegal.append(message))
	_board.on_peg_pressed(from)
	_board.on_peg_pressed(from + 2)
	assert_eq(illegal, [tr("RULE_ADJACENT_PEGS")], "no jumping over a stop")
	assert_eq(_board.session.move_count, 0)
