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
	assert_eq(LevelForge.puzzle_key(start, goal, classic, {}), LevelValidator.pair_key(start, goal))
	var capacity: Array[String] = ["classic_hanoi", "peg_capacity"]
	assert_ne(LevelForge.puzzle_key(start, goal, capacity, {"peg_capacity": {"capacities": [4, 2, 4]}}),
			LevelValidator.pair_key(start, goal), "a rule makes another puzzle")


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
