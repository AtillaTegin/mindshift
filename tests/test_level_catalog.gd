extends "res://tests/test_case.gd"
## LevelCatalog (shipped levels, unlocking, next level) and star rules.

const PATH: String = "user://test_level_catalog.json"


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func test_counts_and_loading() -> void:
	for tier: String in Difficulty.ORDER:
		assert_eq(LevelCatalog.level_count(tier), 50, tier)
	assert_eq(LevelCatalog.level_count("nope"), 0)
	var level: Level = LevelCatalog.load_level("hard", 7)
	assert_not_null(level)
	assert_eq(level.id, 3007)
	assert_eq(level.difficulty, "hard")
	assert_null(LevelCatalog.load_level("hard", 0))
	assert_null(LevelCatalog.load_level("hard", 51))


func test_next_after() -> void:
	assert_eq(LevelCatalog.next_after("easy", 1), {"tier": "easy", "index": 2})
	assert_eq(LevelCatalog.next_after("easy", 50), {"tier": "medium", "index": 1})
	assert_eq(LevelCatalog.next_after("hard", 50), {"tier": "expert", "index": 1})
	assert_eq(LevelCatalog.next_after("expert", 50), {})


func test_unlocking() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	for tier: String in Difficulty.ORDER:
		assert_true(LevelCatalog.is_unlocked(tier, 1, save), "first %s level open" % tier)
	assert_false(LevelCatalog.is_unlocked("easy", 2, save))
	assert_false(LevelCatalog.is_unlocked("easy", 51, save), "no such level")
	save.record_completion(Difficulty.id_for("easy", 1), 1, 20, 5.0)
	assert_true(LevelCatalog.is_unlocked("easy", 2, save), "even one star unlocks the next")
	assert_false(LevelCatalog.is_unlocked("easy", 3, save))


func test_next_to_play_follows_progress() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_eq(LevelCatalog.next_to_play(save), {"tier": "easy", "index": 1})
	save.record_completion(1001, 3, 5, 5.0)
	save.record_completion(1002, 3, 5, 5.0)
	assert_eq(LevelCatalog.next_to_play(save), {"tier": "easy", "index": 3})


func test_stars_for_moves() -> void:
	var level: Level = LevelCatalog.load_level("easy", 50)
	var min_moves: int = level.min_moves
	assert_eq(level.stars_for_moves(min_moves), 3)
	assert_eq(level.stars_for_moves(min_moves + 1), 2)
	assert_eq(level.stars_for_moves(level.two_star_moves), 2)
	assert_eq(level.stars_for_moves(level.two_star_moves + 1), 1)
	assert_eq(level.stars_for_moves(500), 1)
