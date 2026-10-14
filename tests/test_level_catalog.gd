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
	assert_eq(mechanic_files, 136, "22 Nine Rings, 24 karakuri, 30 caravan road, 30 great exchange and 30 combination levels")
	assert_eq(LevelCatalog.total_levels(), classic + mechanic_files)
	assert_eq(LevelValidator.validate_path(Difficulty.LEVELS_DIR), [] as Array[String])


func test_path_starts_with_the_tutorial_and_easy_levels() -> void:
	assert_eq(LevelCatalog.level_id_at(MAIN, 1), TutorialDirector.GUIDED_LEVEL_ID)
	assert_eq(LevelCatalog.level_id_at(MAIN, 2), TutorialDirector.FREE_LEVEL_ID)
	assert_eq(LevelValidator.TUTORIAL_LEVEL_IDS, [TutorialDirector.GUIDED_LEVEL_ID, TutorialDirector.FREE_LEVEL_ID] as Array[int])
	assert_eq(PathBuilder.FIRST_EASY, 4, "level structure v4: the first 3-4 levels")
	for position: int in range(1, PathBuilder.FIRST_EASY + 1):
		var level: Level = _level_at(MAIN, position)
		assert_eq(level.difficulty, "easy", "main %d" % position)
		assert_eq(level.mechanic(), Level.CLASSIC, "main %d" % position)
		assert_eq(level.get_disk_count(), 3, "main %d: 3 disks on 3 pegs" % position)
		assert_eq(level.get_peg_count(), 3)


func test_difficulty_mix_follows_the_addendum() -> void:
	# Level structure v4: easy only for learning at the start (3-disk levels
	# first, then 4-disk ones) and none after main 50; medium and hard as the
	# body; expert only on the island.
	var counts: Dictionary = {}
	var main_length: int = LevelCatalog.track_length(MAIN)
	var last_easy: int = 0
	var first_hard: int = 0
	var moves_by_third: Array[int] = [0, 0, 0]
	for position: int in range(1, main_length + 1):
		var level: Level = _level_at(MAIN, position)
		counts[level.difficulty] = counts.get(level.difficulty, 0) + 1
		if level.difficulty == "easy":
			last_easy = position
			if position > PathBuilder.FIRST_EASY and level.mechanic() == Level.CLASSIC:
				assert_eq(level.get_disk_count(), 4, "main %d: past the first levels easy means 4 disks" % position)
		if level.difficulty == "hard" and first_hard == 0:
			first_hard = position
		moves_by_third[mini(3 * (position - 1) / main_length, 2)] += level.min_moves
	assert_false(counts.has("expert"), "expert levels live on the island")
	assert_true(last_easy <= 50, "no easy level after main 50 (last at %d)" % last_easy)
	assert_true(counts["medium"] + counts["hard"] >= 0.85 * main_length, "medium and hard dominate: %s" % str(counts))
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
			assert_true(position >= PathBuilder.CHAPTER_STARTS.values().min(), "not before the first chapter")
			assert_eq(mechanic, _level_at(MAIN, position).mechanic())
			assert_true(Difficulty.is_known(_level_at(MAIN, position).difficulty), "a real tier")
			found.append(mechanic)
	assert_eq(found.count("alternation"), 22)
	assert_eq(found.count("covered_pegs"), 24)
	assert_eq(found.count("adjacent_pegs"), 30)
	assert_eq(found.count(ColorSwapRule.ID), 30)
	assert_eq(found.count(CombinationRule.ID), 30)


func test_classic_and_mechanic_levels_take_turns_after_50() -> void:
	# Level structure v4, section 3 (user decisions 2026-10-13): about 1:1 from
	# main 51 to 200, weighted at random (no long runs, no strict rhythm); after
	# that the rest thin out, and every chapter still reaches the end of the road.
	var mechanic_count: int = 0
	var run: int = 0
	var longest: int = 0
	var was_mechanic: bool = false
	var strict: bool = true
	for position: int in range(PathBuilder.MIX_FROM, PathBuilder.MIX_UNTIL + 1):
		var is_mechanic: bool = LevelCatalog.mechanic_at(MAIN, position) != Level.CLASSIC
		mechanic_count += 1 if is_mechanic else 0
		run = run + 1 if is_mechanic == was_mechanic and position > PathBuilder.MIX_FROM else 1
		longest = maxi(longest, run)
		strict = strict and (run == 1 or position == PathBuilder.MIX_FROM)
		was_mechanic = is_mechanic
	var mixed: int = PathBuilder.MIX_UNTIL - PathBuilder.MIX_FROM + 1
	assert_true(absf(float(mechanic_count) / mixed - 0.5) <= 0.03, "about 1:1 (%d of %d)" % [mechanic_count, mixed])
	assert_true(longest <= 3, "no long runs of one kind (%d)" % longest)
	assert_false(strict, "not a strict rhythm either")
	var main_length: int = LevelCatalog.track_length(MAIN)
	var tail: int = 0
	var last: Dictionary = {}
	for position: int in range(1, main_length + 1):
		var mechanic: String = LevelCatalog.mechanic_at(MAIN, position)
		if mechanic == Level.CLASSIC:
			continue
		last[mechanic] = position
		tail += 1 if position > PathBuilder.MIX_UNTIL else 0
	# Since the great exchange became a 30-level chapter (v2 addendum) the end of
	# the road is only a little thinner than the 1:1 middle (0.48 of its slots).
	var share: float = float(tail) / (main_length - PathBuilder.MIX_UNTIL)
	assert_true(share > 0.15 and share < PathBuilder.MIX_SHARE, "the end of the road has fewer but some (%.2f)" % share)
	for mechanic: String in PathBuilder.CHAPTER_STARTS:
		assert_eq(LevelCatalog.mechanic_at(MAIN, PathBuilder.CHAPTER_STARTS[mechanic]), mechanic, "%s starts on time" % mechanic)
		assert_true(last[mechanic] > PathBuilder.MIX_UNTIL, "%s runs to the end of the road (%d)" % [mechanic, last[mechanic]])


func test_karakuri_levels_come_early_and_get_harder() -> void:
	# User requests 2026-10-12: 22-24 karakuri levels, the first one soon after
	# the tutorial, up to the end of the road, from small and easy to large and
	# hard (spacing: level structure v4's 1:1 mix).
	var positions: Array[int] = []
	var levels: Array[Level] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == "covered_pegs":
			positions.append(position)
			levels.append(_level_at(MAIN, position))
	assert_true(positions.size() >= 22 and positions.size() <= 24, "%d karakuri levels" % positions.size())
	assert_true(positions[-1] > PathBuilder.MIX_UNTIL, "the end of the road has them too")
	assert_eq(positions[0], 12, "the first one at %d" % positions[0])
	for i: int in range(1, positions.size()):
		assert_true(levels[i].min_moves >= levels[i - 1].min_moves, "never easier than the one before (%d)" % positions[i])
	assert_eq(levels[0].get_disk_count(), 3, "the first one is small")
	assert_eq(levels[0].covered_pegs.size(), 1, "with a single box")
	assert_eq(levels[0].difficulty, "easy")
	assert_eq(levels[-1].get_disk_count(), 8, "the last ones are large")
	assert_true(levels[-1].covered_pegs.size() >= 2, "with two or three boxes")


func test_nine_rings_run_the_whole_road_easy_to_hard() -> void:
	# User request 2026-10-12: ~20-25 Nine Rings levels, the first one at about
	# main 15-20, then every ~10-15 levels into the last fifth of the road, from
	# short to long like the karakuri.
	var positions: Array[int] = []
	var tiers: Dictionary = {}
	var previous: int = 0
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == "alternation":
			positions.append(position)
			var level: Level = _level_at(MAIN, position)
			assert_true(level.min_moves >= previous, "never easier than the one before (%d)" % position)
			previous = level.min_moves
			tiers[level.difficulty] = tiers.get(level.difficulty, 0) + 1
	assert_true(positions.size() >= 20 and positions.size() <= 25, "%d Nine Rings levels" % positions.size())
	assert_eq(positions[0], 20, "the first one at %d" % positions[0])
	assert_true(positions[-1] >= 0.8 * LevelCatalog.track_length(MAIN), "into the last fifth of the road (%d)" % positions[-1])
	for tier: String in ["easy", "medium", "hard"]:
		assert_true(tiers.get(tier, 0) >= 3, "%s ones too: %s" % [tier, str(tiers)])


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
