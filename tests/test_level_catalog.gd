extends "res://tests/test_case.gd"
## LevelCatalog: the shipped levels, the level path (one road plus an island
## at the end of each chapter, chapter system v1), unlocking, next level and
## stars. The road's makeup is tested in test_chapter_plan.gd.
## Tests of the full road (ROAD_MODE=full); the demo road skips them.
const FULL_ROAD_TESTS: Array[String] = ["test_every_level_is_on_the_path_once", "test_expert_levels_only_on_islands", "test_next_after_stays_on_the_track", "test_tracks_and_islands", "test_islands_open_after_their_main_level", "test_next_to_play_follows_progress", "test_place_and_title"]

const PATH: String = "res://.test_saves/test_level_catalog.json"
const MAIN: String = LevelCatalog.MAIN


func after_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _complete(save: SaveSystem, track: String, last_position: int) -> void:
	for position: int in range(1, last_position + 1):
		save.record_completion(LevelCatalog.level_id_at(track, position), 1, 99, 5.0)


func _level_at(track: String, position: int) -> Level:
	return LevelCatalog.load_at(track, position)


func _first_island() -> String:
	return LevelCatalog.island_tracks()[0]


func test_counts_and_loading() -> void:
	for tier: String in Difficulty.ORDER:
		assert_true(LevelCatalog.level_count(tier) > 0, tier)
	assert_eq(LevelCatalog.level_count("nope"), 0)
	var level: Level = LevelCatalog.load_level("hard", 7)
	assert_not_null(level)
	assert_eq(level.id, 3007)
	assert_eq(level.difficulty, "hard")
	assert_null(LevelCatalog.load_level("hard", 0))
	assert_null(LevelCatalog.load_level("hard", LevelCatalog.level_count("hard") + 1))


func test_every_level_is_on_the_path_once() -> void:
	var files: int = 0
	for folder: String in DirAccess.get_directories_at(Difficulty.LEVELS_DIR):
		for file_name: String in DirAccess.get_files_at(Difficulty.LEVELS_DIR + "/" + folder):
			files += 1 if file_name.ends_with(".json") else 0
	assert_eq(LevelCatalog.total_levels(), files)
	assert_eq(LevelValidator.validate_path(Difficulty.LEVELS_DIR), [] as Array[String])


func test_path_starts_with_the_tutorial() -> void:
	assert_eq(LevelCatalog.level_id_at(MAIN, 1), TutorialDirector.GUIDED_LEVEL_ID)
	assert_eq(LevelCatalog.level_id_at(MAIN, 2), TutorialDirector.FREE_LEVEL_ID)
	assert_eq(LevelValidator.TUTORIAL_LEVEL_IDS, [TutorialDirector.GUIDED_LEVEL_ID, TutorialDirector.FREE_LEVEL_ID] as Array[int])
	assert_eq(_level_at(MAIN, 1).start.to_array(), [[1], [2], [3]], "the tutorial levels never change")
	assert_eq(_level_at(MAIN, 2).goal.to_array(), [[], [], [3, 2, 1]])


func test_expert_levels_only_on_islands() -> void:
	# ...and as each chapter's Böyük Sınaq (Fəsil Sistemi v1.2, 3.2a).
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if not ChapterPlan.is_big_test(position):
			assert_ne(_level_at(MAIN, position).difficulty, "expert", "main %d" % position)
	var experts: int = 0
	for island: String in LevelCatalog.island_tracks():
		for position: int in range(1, LevelCatalog.track_length(island) + 1):
			experts += 1 if _level_at(island, position).difficulty == "expert" else 0
	assert_true(experts > 0)


func test_it_gets_harder_along_each_chapter() -> void:
	var first_half: int = 0
	var second_half: int = 0
	for position: int in range(1, 101):
		var moves: int = _level_at(MAIN, position).min_moves
		if position <= 50:
			first_half += moves
		else:
			second_half += moves
	assert_true(first_half < second_half, "the first world climbs (%d < %d)" % [first_half, second_half])


func test_no_shipped_level_has_a_time_limit() -> void:
	# Decision 2026-10-09: v1 has no timed levels; the field stays for a later mode.
	for track: String in LevelCatalog.tracks():
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
	var island: String = _first_island()
	assert_eq(LevelCatalog.next_after(island, 3), {"track": island, "position": 4})
	assert_eq(LevelCatalog.next_after(island, LevelCatalog.track_length(island)), {})


func test_tracks_and_islands() -> void:
	var islands: Array[String] = LevelCatalog.island_tracks()
	assert_eq(islands[0], "island_1")
	assert_eq(LevelCatalog.tracks()[0], MAIN)
	assert_eq(LevelCatalog.tracks().size(), islands.size() + 1)
	assert_true(LevelCatalog.is_island(islands[0]))
	assert_false(LevelCatalog.is_island(MAIN))
	assert_eq(LevelCatalog.island_after(islands[0]), 50, "the classic island after main 50, as before")
	assert_eq(LevelCatalog.island_at(50), islands[0])
	assert_eq(LevelCatalog.island_at(49), "")
	assert_eq(LevelCatalog.island_after(MAIN), 0)


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


func test_islands_open_after_their_main_level() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	var islands: Array[String] = LevelCatalog.island_tracks()
	var first: String = islands[0]
	var second: String = islands[1]
	var after: int = LevelCatalog.island_after(first)
	_complete(save, MAIN, after - 1)
	assert_false(LevelCatalog.is_island_open(first, save))
	assert_false(LevelCatalog.is_unlocked(first, 1, save), "hidden until main %d" % after)
	save.record_completion(LevelCatalog.level_id_at(MAIN, after), 2, 99, 5.0)
	assert_true(LevelCatalog.is_island_open(first, save))
	assert_true(LevelCatalog.is_unlocked(first, 1, save))
	assert_false(LevelCatalog.is_unlocked(first, 2, save), "one by one on the island too")
	assert_false(LevelCatalog.is_island_open(second, save), "each island waits for its own chapter")
	assert_eq(LevelCatalog.open_islands(save), [first] as Array[String])
	_complete(save, MAIN, LevelCatalog.island_after(second))
	assert_true(LevelCatalog.is_unlocked(second, 1, save), "without playing the first island")
	assert_eq(LevelCatalog.open_islands(save), [first, second] as Array[String])


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
	_complete(save, MAIN, 50)
	assert_eq(LevelCatalog.next_to_play(save), {"track": MAIN, "position": 51}, "the road comes first, islands are optional")
	_complete(save, MAIN, LevelCatalog.track_length(MAIN))
	assert_eq(LevelCatalog.next_to_play(save), {"track": _first_island(), "position": 1}, "then the islands")
	_complete(save, _first_island(), LevelCatalog.track_length(_first_island()))
	assert_eq(LevelCatalog.next_to_play(save), {"track": LevelCatalog.island_tracks()[1], "position": 1})
	assert_eq(LevelCatalog.next_on(_first_island(), save), 0, "nothing left there")


func test_place_and_title() -> void:
	assert_eq(LevelCatalog.place_of(1001), {"track": MAIN, "position": 1})
	assert_eq(LevelCatalog.place_of(12345), {})
	assert_eq(LevelCatalog.level_title(_level_at(MAIN, 7)), "Səviyyə 7")
	assert_eq(LevelCatalog.level_title(_level_at(_first_island(), 3)), "Ada · 3")
	assert_eq(LevelCatalog.level_title(_level_at(LevelCatalog.island_tracks()[1], 2)), "Ada · 2")
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
