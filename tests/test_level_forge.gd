extends "res://tests/test_case.gd"
## LevelForge and RoadBuilder's level drawing (in memory; never touch
## data/levels).


## Levels of `modes` in `band` drawn like the road builder does.
func _group(modes: Array, band: String, count: int, seed_value: int) -> Array[Dictionary]:
	var errors: Array[String] = []
	var drafts: Array[Dictionary] = RoadBuilder.draw_group(modes, band, count, seed_value, {}, errors)
	assert_eq(errors, [] as Array[String])
	return drafts


func _as_level(draft: Dictionary, id: int) -> Level:
	var level: Level = Level.create(id, Difficulty.tier_for_moves(draft["moves"]), draft["start"], draft["goal"],
			draft["rule_ids"], draft["path"], draft["params"])
	level.covered_pegs.assign(draft["covered"])
	return level


func test_classic_group_is_valid_and_spread() -> void:
	var drafts: Array[Dictionary] = _group([], "medium", 6, 2)
	assert_eq(drafts.size(), 6)
	var keys: Dictionary = {}
	for i: int in drafts.size():
		var level: Level = _as_level(drafts[i], 2001 + i)
		var errors: Array[String] = []
		LevelValidator.validate_level(level, errors)
		assert_eq(errors, [] as Array[String], "level %d" % i)
		assert_true(level.min_moves >= 12 and level.min_moves <= 18, "in the medium band (%d)" % level.min_moves)
		keys[drafts[i]["key"]] = true
		if i > 0:
			assert_true(drafts[i - 1]["moves"] <= drafts[i]["moves"], "easiest first")
	assert_eq(keys.size(), 6, "all different")


func test_mode_levels_need_their_rule() -> void:
	for modes: Array in [["peg_capacity"], ["foundation"], ["peg_capacity", "foundation"]]:
		var drafts: Array[Dictionary] = _group(modes, "medium", 2, 7)
		for draft: Dictionary in drafts:
			var level: Level = _as_level(draft, 10001)
			assert_eq(level.modes(), LevelForge.rule_modes(modes), str(modes))
			var errors: Array[String] = []
			LevelValidator.validate_level(level, errors)
			LevelValidator.validate_mechanic_design(level, errors)
			assert_eq(errors, [] as Array[String], str(modes))
			assert_true(LevelForge.matters(level.start, level.goal, level.rule_ids, level.rule_params, level.min_moves))


func test_a_combination_is_longer_than_either_mode() -> void:
	var drafts: Array[Dictionary] = _group(["peg_capacity", "foundation"], "medium_hard", 1, 3)
	var level: Level = _as_level(drafts[0], 30001)
	assert_true(level.is_combo())
	assert_eq(level.lesson(), "peg_capacity+foundation")
	for kept: String in ["peg_capacity", "foundation"]:
		var params: Dictionary = {kept: level.rule_params[kept]}
		var alone: Dictionary = Solver.solve(level.start, level.goal, RuleSet.from_ids(["classic_hanoi", kept], params))
		assert_true(alone["min_moves"] < level.min_moves, "longer than %s alone" % kept)


func test_karakuri_boxes_hide_something_used_early() -> void:
	var drafts: Array[Dictionary] = _group(["covered_pegs"], "medium_hard", 3, 4)
	for draft: Dictionary in drafts:
		var level: Level = _as_level(draft, 11001)
		assert_false(level.covered_pegs.is_empty())
		assert_eq(level.rule_ids, ["classic_hanoi"] as Array[String], "boxes are no rule")
		var errors: Array[String] = []
		LevelValidator.validate_mechanic_design(level, errors)
		assert_eq(errors, [] as Array[String])
	# A boxed board is the same puzzle as the open one: one key.
	var start: PuzzleState = LevelForge.tower_state(3, 4, 0)
	var goal: PuzzleState = LevelForge.tower_state(3, 4, 2)
	var classic: Array[String] = ["classic_hanoi"]
	# The canonical form (PuzzleIdentity): the same tower moved between two
	# other pegs is the same puzzle.
	assert_eq(LevelForge.puzzle_key(start, goal, classic, {}),
			LevelForge.puzzle_key(LevelForge.tower_state(3, 4, 1), LevelForge.tower_state(3, 4, 0), classic, {}))
	var capacity: Array[String] = ["classic_hanoi", "peg_capacity"]
	assert_ne(LevelForge.puzzle_key(start, goal, capacity, {"peg_capacity": {"capacities": [4, 2, 4]}}),
			LevelForge.puzzle_key(start, goal, classic, {}), "a rule makes another puzzle")


func test_same_seed_gives_same_levels() -> void:
	var a: Array[Dictionary] = _group(["foundation"], "easy_medium", 3, 99)
	var b: Array[Dictionary] = _group(["foundation"], "easy_medium", 3, 99)
	var c: Array[Dictionary] = _group(["foundation"], "easy_medium", 3, 100)
	assert_eq(_keys(a), _keys(b))
	assert_ne(_keys(a), _keys(c), "another seed gives other levels")


func test_random_state_is_legal_and_complete() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in 50:
		var state: PuzzleState = LevelForge.random_state(rng, 4, 9)
		assert_eq(state.get_peg_count(), 4)
		assert_eq(state.get_disk_count(), 9)
		assert_true(RuleSet.classic().is_state_valid(state), state.hash_key())
	assert_eq(LevelForge.tower_state(3, 3, 1).to_array(), [[], [3, 2, 1], []])


func test_file_names_and_ids() -> void:
	assert_eq(Difficulty.level_file_name("easy", 7), "easy_007.json")
	assert_eq(Difficulty.level_path("expert", 50), "res://data/levels/expert/expert_050.json")
	assert_eq(Difficulty.id_for("medium", 3), 2003)
	assert_eq(Difficulty.tier_of_id(2003), "medium")
	assert_eq(Difficulty.index_of_id(2003), 3)
	assert_eq(Difficulty.tier_of_id(5), "")
	assert_eq(Difficulty.index_of_id(5), -1)
	assert_true(Difficulty.is_mechanic_id(10001))
	assert_false(Difficulty.is_mechanic_id(4999))


static func _keys(drafts: Array[Dictionary]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for draft: Dictionary in drafts:
		parts.append(draft["key"])
	return "|".join(parts)


func test_a_draw_stops_at_the_deadline() -> void:
	# Three scales of 9 disks (6^9 positions to sort through) give up at once
	# when the level's time is over instead of running for hours.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var board: Dictionary = {"pegs": 4, "disks": 9, "tolerance": [5, 9], "variants": ["three_scales"]}
	var started_ms: int = Time.get_ticks_msec()
	Solver.deadline_msec = started_ms + 300
	var draft: Dictionary = LevelForge.attempt([BalanceRule.ID], board, 18, 20, {}, rng)
	Solver.deadline_msec = 0
	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	assert_true(draft.is_empty())
	assert_true(elapsed_ms < 1500, "took %d ms past a 300 ms deadline" % elapsed_ms)


func test_checkpoint_gives_back_the_drawn_levels() -> void:
	# `--resume` takes the drawn levels back from the checkpoint as they were.
	var draft: Dictionary = _group([BalanceRule.ID], "medium", 1, 5)[0]
	var tracks: Array = [[{"world": 4, "modes": [BalanceRule.ID], "band": "medium", "draft": draft}, {"world": 4, "modes": []}]]
	var saved_path: String = RoadBuilder.checkpoint_path
	RoadBuilder.checkpoint_path = "res://.test_saves/test_road_checkpoint.json"
	RoadBuilder._save_checkpoint(tracks)
	var fresh: Array = [[{"world": 4, "modes": [BalanceRule.ID], "band": "medium"}, {"world": 4, "modes": []}]]
	var used: Dictionary = {}
	RoadBuilder._load_checkpoint(fresh, [4] as Array[int], used)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RoadBuilder.checkpoint_path))
	RoadBuilder.checkpoint_path = saved_path
	var back: Dictionary = fresh[0][0]["draft"]
	assert_false(fresh[0][1].has("draft"), "an undrawn slot stays undrawn")
	assert_true(used.has(draft["key"]))
	assert_true((back["start"] as PuzzleState).equals(draft["start"]))
	assert_true((back["goal"] as PuzzleState).equals(draft["goal"]))
	assert_eq(back["moves"], draft["moves"])
	assert_eq(back["params"], draft["params"])
	assert_eq((back["path"] as Array).size(), (draft["path"] as Array).size())
	var level: Level = Level.create(1, "medium", back["start"], back["goal"], back["rule_ids"], back["path"], back["params"])
	assert_true(Solver.solve(back["start"], back["goal"], level.get_rule_set())["min_moves"] == back["moves"])
