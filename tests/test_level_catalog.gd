extends "res://tests/test_case.gd"
## LevelCatalog: the shipped levels, the level path (level structure addendum
## v3: one road plus the island branch), unlocking, next level and stars.

const PATH: String = "res://.test_saves/test_level_catalog.json"
const MAIN: String = LevelCatalog.MAIN
const BRANCH: String = LevelCatalog.BRANCH


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _complete(save: SaveSystem, track: String, last_position: int) -> void:
	for position: int in range(1, last_position + 1):
		save.record_completion(LevelCatalog.level_id_at(track, position), 1, 99, 5.0)


func _level_at(track: String, position: int) -> Level:
	return LevelCatalog.load_at(track, position)


func test_counts_and_loading() -> void:
	for tier: String in Difficulty.ORDER:
		assert_eq(LevelCatalog.level_count(tier), Difficulty.default_count(tier), tier)
	assert_eq(LevelCatalog.level_count("nope"), 0)
	var level: Level = LevelCatalog.load_level("hard", 7)
	assert_not_null(level)
	assert_eq(level.id, 3007)
	assert_eq(level.difficulty, "hard")
	assert_null(LevelCatalog.load_level("hard", 0))
	assert_null(LevelCatalog.load_level("hard", Difficulty.default_count("hard") + 1))


func test_every_level_is_on_the_path_once() -> void:
	var classic: int = 0
	for tier: String in Difficulty.ORDER:
		classic += LevelCatalog.level_count(tier)
	var mechanic_files: int = 0
	for file_name: String in DirAccess.get_files_at(Difficulty.LEVELS_DIR + "/" + Difficulty.MECHANICS):
		if file_name.ends_with(".json"):
			mechanic_files += 1
	assert_eq(mechanic_files, 24, "four frozen-disk and twenty karakuri levels")
	assert_eq(LevelCatalog.total_levels(), classic + mechanic_files)
	assert_eq(LevelValidator.validate_path(Difficulty.LEVELS_DIR), [] as Array[String])


func test_path_starts_with_the_tutorial_and_easy_levels() -> void:
	assert_eq(LevelCatalog.level_id_at(MAIN, 1), TutorialDirector.GUIDED_LEVEL_ID)
	assert_eq(LevelCatalog.level_id_at(MAIN, 2), TutorialDirector.FREE_LEVEL_ID)
	assert_eq(LevelValidator.TUTORIAL_LEVEL_IDS, [TutorialDirector.GUIDED_LEVEL_ID, TutorialDirector.FREE_LEVEL_ID] as Array[int])
	for position: int in range(1, PathBuilder.FIRST_EASY + 1):
		var level: Level = _level_at(MAIN, position)
		assert_eq(level.difficulty, "easy", "main %d" % position)
		assert_eq(level.mechanic(), Level.CLASSIC, "main %d" % position)


func test_difficulty_mix_follows_the_addendum() -> void:
	# Few easy levels (breathers), medium and hard as the body, expert only on the island.
	var counts: Dictionary = {}
	var main_length: int = LevelCatalog.track_length(MAIN)
	var late_easy: int = 0
	var first_hard: int = 0
	var moves_by_third: Array[int] = [0, 0, 0]
	for position: int in range(1, main_length + 1):
		var level: Level = _level_at(MAIN, position)
		counts[level.difficulty] = counts.get(level.difficulty, 0) + 1
		if level.difficulty == "easy" and position > 40:
			late_easy += 1
		if level.difficulty == "hard" and first_hard == 0:
			first_hard = position
		moves_by_third[mini(3 * (position - 1) / main_length, 2)] += level.min_moves
	assert_false(counts.has("expert"), "expert levels live on the island")
	assert_true(counts["easy"] <= 0.16 * main_length, "easy is rare: %s" % str(counts))
	assert_true(counts["medium"] + counts["hard"] >= 0.75 * main_length, "medium and hard dominate: %s" % str(counts))
	assert_true(late_easy >= 3, "easy breathers keep coming later on (%d)" % late_easy)
	assert_true(first_hard > PathBuilder.FIRST_EASY + 5, "hard levels wait a little (first at %d)" % first_hard)
	assert_true(moves_by_third[0] < moves_by_third[1] and moves_by_third[1] < moves_by_third[2],
			"it gets harder along the road: %s" % str(moves_by_third))
	var island: Dictionary = {}
	for position: int in range(1, LevelCatalog.track_length(BRANCH) + 1):
		var level: Level = _level_at(BRANCH, position)
		island[level.difficulty] = island.get(level.difficulty, 0) + 1
	assert_eq(island.get("expert", 0), LevelCatalog.level_count("expert"), "every expert level is on the island")
	assert_true(island.get("medium", 0) >= 1, "with a few medium breathers: %s" % str(island))
	assert_eq(_level_at(BRANCH, 1).difficulty, "hard", "the island opens gently")
	assert_eq(LevelCatalog.branch_after(), PathBuilder.BRANCH_AFTER)


func test_mechanic_levels_are_ordinary_path_levels() -> void:
	var found: Array[String] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		var mechanic: String = LevelCatalog.mechanic_at(MAIN, position)
		if mechanic != Level.CLASSIC:
			assert_true(position > PathBuilder.MECHANICS_FROM, "not before main %d" % PathBuilder.MECHANICS_FROM)
			assert_eq(mechanic, _level_at(MAIN, position).mechanic())
			assert_true(Difficulty.is_known(_level_at(MAIN, position).difficulty), "a real tier")
			found.append(mechanic)
	assert_eq(found.count("frozen_disk"), 4)
	assert_eq(found.count("covered_pegs"), 20)


func test_karakuri_levels_come_early_often_and_get_harder() -> void:
	# User request 2026-10-12: ~15-20 karakuri levels, the first one soon after
	# the tutorial, then every 5-9 levels, from small and easy to large and hard.
	var positions: Array[int] = []
	var levels: Array[Level] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == "covered_pegs":
			positions.append(position)
			levels.append(_level_at(MAIN, position))
	assert_true(positions.size() >= 15 and positions.size() <= 20, "%d karakuri levels" % positions.size())
	assert_true(positions[0] >= 10 and positions[0] <= 14, "the first one at %d" % positions[0])
	for i: int in range(1, positions.size()):
		var gap: int = positions[i] - positions[i - 1]
		assert_true(gap >= 5 and gap <= 9, "gap %d between %d and %d" % [gap, positions[i - 1], positions[i]])
		assert_true(levels[i].min_moves >= levels[i - 1].min_moves, "never easier than the one before (%d)" % positions[i])
	assert_eq(levels[0].get_disk_count(), 3, "the first one is small")
	assert_eq(levels[0].covered_pegs.size(), 1, "with a single box")
	assert_eq(levels[0].difficulty, "easy")
	assert_eq(levels[-1].get_disk_count(), 8, "the last ones are large")
	assert_eq(levels[-1].covered_pegs.size(), 2, "with two boxes")


func test_no_shipped_level_has_a_time_limit() -> void:
	# Decision 2026-10-09: v1 has no timed levels; the field stays for a later mode.
	for track: String in LevelCatalog.TRACKS:
		for position: int in range(1, LevelCatalog.track_length(track) + 1):
			assert_null(_level_at(track, position).time_limit_seconds, "%s %d" % [track, position])


func test_validator_rejects_an_active_time_limit() -> void:
	var level: Level = LevelCatalog.load_level("easy", 1)
	level.time_limit_seconds = 60
	var errors: Array[String] = []
	LevelValidator.validate_level(level, errors)
	assert_true(" ".join(errors).contains("v1 has no timed levels"), str(errors))
	var data: Dictionary = level.to_dict()
	assert_true(data.has("time_limit_seconds"), "the field stays in the format")


func test_next_after_stays_on_the_track() -> void:
	assert_eq(LevelCatalog.next_after(MAIN, 1), {"track": MAIN, "position": 2})
	var main_length: int = LevelCatalog.track_length(MAIN)
	assert_eq(LevelCatalog.next_after(MAIN, main_length), {}, "the road ends")
	assert_eq(LevelCatalog.next_after(BRANCH, 3), {"track": BRANCH, "position": 4})
	assert_eq(LevelCatalog.next_after(BRANCH, LevelCatalog.track_length(BRANCH)), {})


func test_levels_open_one_by_one_with_no_tier_counter() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_true(LevelCatalog.is_unlocked(MAIN, 1, save), "first level open")
	assert_false(LevelCatalog.is_unlocked(MAIN, 2, save))
	assert_false(LevelCatalog.is_unlocked(MAIN, 0, save), "no such level")
	save.record_completion(LevelCatalog.level_id_at(MAIN, 1), 1, 20, 5.0)
	assert_true(LevelCatalog.is_unlocked(MAIN, 2, save), "even one star opens the next")
	assert_false(LevelCatalog.is_unlocked(MAIN, 3, save))
	_complete(save, MAIN, 30)
	var thirty_one: Level = _level_at(MAIN, 31)
	assert_true(LevelCatalog.is_unlocked(MAIN, 31, save), "%s level opens like any other" % thirty_one.difficulty)


func test_island_opens_after_its_main_level() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	var after: int = LevelCatalog.branch_after()
	_complete(save, MAIN, after - 1)
	assert_false(LevelCatalog.is_branch_open(save))
	assert_false(LevelCatalog.is_unlocked(BRANCH, 1, save), "hidden until main %d" % after)
	save.record_completion(LevelCatalog.level_id_at(MAIN, after), 2, 99, 5.0)
	assert_true(LevelCatalog.is_branch_open(save))
	assert_true(LevelCatalog.is_unlocked(BRANCH, 1, save))
	assert_false(LevelCatalog.is_unlocked(BRANCH, 2, save), "one by one on the island too")


func test_completed_levels_stay_open() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	save.record_completion(LevelCatalog.level_id_at(MAIN, 9), 2, 30, 50.0)
	assert_true(LevelCatalog.is_unlocked(MAIN, 9, save), "already completed")
	assert_true(LevelCatalog.is_unlocked(MAIN, 10, save), "and it opens the next")
	assert_false(LevelCatalog.is_unlocked(MAIN, 8, save))


func test_next_to_play_follows_progress() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_eq(LevelCatalog.next_to_play(save), {"track": MAIN, "position": 1})
	_complete(save, MAIN, 2)
	assert_eq(LevelCatalog.next_to_play(save), {"track": MAIN, "position": 3})
	_complete(save, MAIN, LevelCatalog.branch_after())
	assert_eq(LevelCatalog.next_to_play(save), {"track": MAIN, "position": LevelCatalog.branch_after() + 1},
			"the road comes first, the island is optional")
	_complete(save, MAIN, LevelCatalog.track_length(MAIN))
	assert_eq(LevelCatalog.next_to_play(save), {"track": BRANCH, "position": 1}, "then the island")


func test_place_and_title() -> void:
	assert_eq(LevelCatalog.place_of(1001), {"track": MAIN, "position": 1})
	assert_eq(LevelCatalog.place_of(12345), {})
	assert_eq(LevelCatalog.level_title(_level_at(MAIN, 7)), "Səviyyə 7")
	assert_eq(LevelCatalog.level_title(_level_at(BRANCH, 3)), "Ada · 3")
	var loose: Level = LevelCatalog.load_level("easy", 1)
	loose.id = 1999
	assert_eq(LevelCatalog.level_title(loose), "Səviyyə", "not on the path")


func test_stars_for_moves() -> void:
	var level: Level = LevelCatalog.load_level("easy", LevelCatalog.level_count("easy"))
	var min_moves: int = level.min_moves
	assert_eq(level.stars_for_moves(min_moves), 3)
	assert_eq(level.stars_for_moves(min_moves + 1), 2)
	assert_eq(level.stars_for_moves(level.two_star_moves), 2)
	assert_eq(level.stars_for_moves(level.two_star_moves + 1), 1)
	assert_eq(level.stars_for_moves(500), 1)
