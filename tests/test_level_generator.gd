extends "res://tests/test_case.gd"
## LevelGenerator (in memory; never touches data/levels).


func _check_tier(tier: String, count: int, seed_value: int) -> Array[Level]:
	var stats: Dictionary = {}
	var levels: Array[Level] = LevelGenerator.generate(tier, count, seed_value, stats)
	assert_eq(levels.size(), count, "%s count" % tier)
	var pairs: Dictionary = {}
	var first_id: int = Difficulty.get_tier(tier)["first_id"]
	for i: int in levels.size():
		var level: Level = levels[i]
		var errors: Array[String] = []
		LevelValidator.validate_level(level, errors)
		assert_eq(errors, [] as Array[String], "%s level %d" % [tier, level.id])
		assert_eq(level.id, first_id + i, "ids are consecutive")
		assert_eq(level.rule_ids, ["classic_hanoi"] as Array[String])
		assert_null(level.time_limit_seconds)
		pairs[LevelValidator.pair_key(level.start, level.goal)] = true
		if i > 0:
			assert_true(levels[i - 1].min_moves <= level.min_moves, "sorted easiest first")
	assert_eq(pairs.size(), count, "%s puzzles are distinct" % tier)
	print("    %s: %d levels from %d attempts, min_moves %d..%d" % [
			tier, count, stats["attempts"], levels[0].min_moves, levels[-1].min_moves])
	return levels


func test_easy_levels_are_valid() -> void:
	_check_tier("easy", 15, 1)


func test_medium_levels_are_valid() -> void:
	_check_tier("medium", 8, 2)


func test_hard_levels_are_valid() -> void:
	_check_tier("hard", 4, 3)


func test_expert_levels_are_valid() -> void:
	_check_tier("expert", 2, 4)


func test_same_seed_gives_same_levels() -> void:
	var a: Array[Level] = LevelGenerator.generate("medium", 6, 99)
	var b: Array[Level] = LevelGenerator.generate("medium", 6, 99)
	var c: Array[Level] = LevelGenerator.generate("medium", 6, 100)
	assert_eq(_as_json(a), _as_json(b))
	assert_ne(_as_json(a), _as_json(c), "another seed gives other levels")


func test_random_state_is_legal_and_complete() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in 50:
		var state: PuzzleState = LevelGenerator.random_state(rng, 4, 9)
		assert_eq(state.get_peg_count(), 4)
		assert_eq(state.get_disk_count(), 9)
		assert_true(RuleSet.classic().is_state_valid(state), state.hash_key())
	assert_eq(LevelGenerator.tower_state(3, 3, 1).to_array(), [[], [3, 2, 1], []])


func test_file_names_and_ids() -> void:
	assert_eq(Difficulty.level_file_name("easy", 7), "easy_007.json")
	assert_eq(Difficulty.level_path("expert", 50), "res://data/levels/expert/expert_050.json")
	assert_eq(Difficulty.id_for("medium", 3), 2003)
	assert_eq(Difficulty.tier_of_id(2003), "medium")
	assert_eq(Difficulty.index_of_id(2003), 3)
	assert_eq(Difficulty.tier_of_id(5), "")
	assert_eq(Difficulty.index_of_id(5), -1)


static func _as_json(levels: Array[Level]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for level: Level in levels:
		parts.append(level.to_json())
	return "".join(parts)
