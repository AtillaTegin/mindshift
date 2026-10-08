extends "res://tests/test_case.gd"
## LevelCatalog (shipped levels, unlocking, next level) and star rules.

const PATH: String = "res://.test_saves/test_level_catalog.json"


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


func test_no_shipped_level_has_a_time_limit() -> void:
	# Decision 2026-10-09: v1 has no timed levels; the field stays for a later mode.
	for tier: String in Difficulty.ORDER:
		for index: int in range(1, LevelCatalog.level_count(tier) + 1):
			assert_null(LevelCatalog.load_level(tier, index).time_limit_seconds, "%s %d" % [tier, index])


func test_validator_rejects_an_active_time_limit() -> void:
	var level: Level = LevelCatalog.load_level("easy", 1)
	level.time_limit_seconds = 60
	var errors: Array[String] = []
	LevelValidator.validate_level(level, errors)
	assert_true(" ".join(errors).contains("v1 has no timed levels"), str(errors))
	var data: Dictionary = level.to_dict()
	assert_true(data.has("time_limit_seconds"), "the field stays in the format")


func test_next_after() -> void:
	assert_eq(LevelCatalog.next_after("easy", 1), {"tier": "easy", "index": 2})
	assert_eq(LevelCatalog.next_after("easy", 50), {"tier": "medium", "index": 1})
	assert_eq(LevelCatalog.next_after("hard", 50), {"tier": "expert", "index": 1})
	assert_eq(LevelCatalog.next_after("expert", 50), {})


static func _complete(save: SaveSystem, tier: String, count: int) -> void:
	for index: int in range(1, count + 1):
		save.record_completion(Difficulty.id_for(tier, index), 1, 99, 5.0)


func test_unlocking_inside_a_tier() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_true(LevelCatalog.is_unlocked("easy", 1, save), "first easy level open")
	assert_false(LevelCatalog.is_unlocked("easy", 2, save))
	assert_false(LevelCatalog.is_unlocked("easy", 51, save), "no such level")
	save.record_completion(Difficulty.id_for("easy", 1), 1, 20, 5.0)
	assert_true(LevelCatalog.is_unlocked("easy", 2, save), "even one star unlocks the next")
	assert_false(LevelCatalog.is_unlocked("easy", 3, save))


func test_tiers_open_after_a_partial_count() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_true(LevelCatalog.is_tier_unlocked("easy", save))
	for tier: String in ["medium", "hard", "expert"]:
		assert_false(LevelCatalog.is_tier_unlocked(tier, save), tier)
		assert_false(LevelCatalog.is_unlocked(tier, 1, save), "%s 1 locked" % tier)
	_complete(save, "easy", 14)
	assert_eq(save.completed_count("easy"), 14)
	assert_eq(LevelCatalog.completed_toward_unlock("medium", save), 14)
	assert_false(LevelCatalog.is_tier_unlocked("medium", save), "14 of 15")
	_complete(save, "easy", 15)
	assert_true(LevelCatalog.is_tier_unlocked("medium", save), "15 easy levels open medium")
	assert_true(LevelCatalog.is_unlocked("medium", 1, save))
	assert_false(LevelCatalog.is_unlocked("medium", 2, save), "still one by one inside the tier")
	assert_false(LevelCatalog.is_tier_unlocked("hard", save))
	_complete(save, "medium", 10)
	assert_true(LevelCatalog.is_tier_unlocked("hard", save), "10 medium levels open hard")
	assert_false(LevelCatalog.is_tier_unlocked("expert", save))
	_complete(save, "hard", 9)
	assert_false(LevelCatalog.is_tier_unlocked("expert", save), "9 of 10")
	_complete(save, "hard", 10)
	assert_true(LevelCatalog.is_tier_unlocked("expert", save), "10 hard levels open expert")


func test_completed_count_ignores_other_tiers() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	save.record_completion(1001, 3, 5, 5.0)
	save.record_completion(1002, 3, 5, 5.0)
	save.record_completion(2001, 3, 5, 5.0)
	assert_eq(save.completed_count("easy"), 2)
	assert_eq(save.completed_count("medium"), 1)
	assert_eq(save.completed_count("hard"), 0)


func test_completed_levels_stay_open_in_a_locked_tier() -> void:
	# A save from the old rules (every tier's first level open) keeps its progress.
	var save: SaveSystem = SaveSystem.new(PATH)
	save.record_completion(3001, 2, 30, 50.0)
	assert_false(LevelCatalog.is_tier_unlocked("hard", save))
	assert_true(LevelCatalog.is_unlocked("hard", 1, save), "already completed")
	assert_false(LevelCatalog.is_unlocked("hard", 2, save), "the tier itself is still locked")


func test_next_to_play_follows_progress() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_eq(LevelCatalog.next_to_play(save), {"tier": "easy", "index": 1})
	save.record_completion(1001, 3, 5, 5.0)
	save.record_completion(1002, 3, 5, 5.0)
	assert_eq(LevelCatalog.next_to_play(save), {"tier": "easy", "index": 3})
	_complete(save, "easy", 15)
	assert_eq(LevelCatalog.next_to_play(save), {"tier": "medium", "index": 1}, "moves on to the newly opened tier")
	_complete(save, "medium", 10)
	assert_eq(LevelCatalog.next_to_play(save), {"tier": "hard", "index": 1})


func test_stars_for_moves() -> void:
	var level: Level = LevelCatalog.load_level("easy", 50)
	var min_moves: int = level.min_moves
	assert_eq(level.stars_for_moves(min_moves), 3)
	assert_eq(level.stars_for_moves(min_moves + 1), 2)
	assert_eq(level.stars_for_moves(level.two_star_moves), 2)
	assert_eq(level.stars_for_moves(level.two_star_moves + 1), 1)
	assert_eq(level.stars_for_moves(500), 1)
