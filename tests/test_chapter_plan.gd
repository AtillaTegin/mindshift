extends "res://tests/test_case.gd"
## The chapter system (MindShift_Fesil_Sistemi_v1.md): the plan itself, the
## combination rules, and the road the builder made from it.

const MAIN: String = LevelCatalog.MAIN


func _level_at(track: String, position: int) -> Level:
	return LevelCatalog.load_at(track, position)


## Chapters of the built road (every chapter that ends on it).
func _built_chapters() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		if int(chapter["last"]) <= LevelCatalog.track_length(MAIN):
			found.append(chapter)
	return found


func test_plan_follows_the_table() -> void:
	# Section 2: seven worlds, ~2020 levels, chapters back to back.
	var next: int = 1
	var world: int = 1
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		assert_eq(chapter["first"], next, "no gap before main %d" % chapter["first"])
		assert_true(int(chapter["world"]) == world or int(chapter["world"]) == world + 1, "worlds in order")
		world = chapter["world"]
		next = int(chapter["last"]) + 1
	assert_eq(next - 1, 2020)
	assert_eq(world, 7)
	var lengths: Dictionary = {}
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		lengths[chapter.get("mode", "%s %d" % [chapter["kind"], chapter["first"]])] = ChapterPlan.length_of(chapter)
	assert_eq(lengths["peg_capacity"], 50)
	assert_eq(lengths["covered_pegs"], 100)
	assert_eq(lengths["alternation"], 120)
	assert_eq(lengths["balance"], 150)
	assert_eq(lengths["color_swap"], 150)
	assert_eq(lengths["combo 301"], 50)
	assert_eq(lengths["combo 1921"], 100)
	for mode: String in ChapterPlan.MODES:
		assert_eq(ChapterPlan.CHAPTERS.filter(func(c: Dictionary) -> bool: return c.get("mode", "") == mode).size(), 1,
				"%s has one chapter" % mode)


func test_bands_climb_through_a_chapter() -> void:
	# Section 3.2: first 15% easy-medium, to 45% medium, to 75% medium-hard, the
	# last 25% hard.
	assert_eq(ChapterPlan.band_for(0, 100), "easy_medium")
	assert_eq(ChapterPlan.band_for(14, 100), "easy_medium")
	assert_eq(ChapterPlan.band_for(15, 100), "medium")
	assert_eq(ChapterPlan.band_for(50, 100), "medium_hard")
	assert_eq(ChapterPlan.band_for(99, 100), "hard")
	assert_eq(ChapterPlan.classic_band(3), "easy")
	assert_eq(ChapterPlan.classic_band(20), "easy_medium")
	assert_eq(ChapterPlan.classic_band(46), "medium_hard")
	assert_eq(ChapterPlan.classic_band(100), "hard")
	assert_eq(ChapterPlan.classic_band(101), "")
	for band: String in ChapterPlan.BAND_ORDER:
		assert_true(ChapterPlan.BANDS[band][1] <= 33, "the main road stays within 33 moves (user decision)")
	assert_eq(ChapterPlan.BANDS["expert"][0], 34, "34+ only on the islands")


func test_combination_rules() -> void:
	# Section 4.2: one mode per category, karakuri never with a history mode or
	# the chain, the mirror only with unequal capacity.
	assert_true(ChapterPlan.is_combo_allowed(["peg_capacity", "foundation"]), "two local filters")
	assert_false(ChapterPlan.is_combo_allowed(["adjacent_pegs", "linked_pegs"]), "two topologies")
	assert_false(ChapterPlan.is_combo_allowed(["stripes", "magnet"]), "two colour systems")
	assert_false(ChapterPlan.is_combo_allowed(["alternation", "trail"]), "two histories")
	assert_false(ChapterPlan.is_combo_allowed(["covered_pegs", "alternation"]), "boxes and history")
	assert_false(ChapterPlan.is_combo_allowed(["covered_pegs", "chain"]), "boxes and the chain")
	assert_false(ChapterPlan.is_combo_allowed(["mirror", "foundation"]), "the mirror only with capacity")
	assert_true(ChapterPlan.is_combo_allowed(["mirror", "peg_capacity"]))
	assert_false(ChapterPlan.is_combo_allowed(["balance", "color_swap"]), "two special goals")
	# Section 4.3: every listed combination obeys the rules and joins modes taught before it.
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		for combo: Array in chapter.get("combos", []):
			assert_true(ChapterPlan.is_combo_allowed(combo), str(combo))
			for mode: String in combo:
				assert_true(ChapterPlan.modes_before(chapter["first"]).has(mode), "%s is learned before main %d" % [mode, chapter["first"]])
	assert_eq(ChapterPlan.combo_key(["foundation", "peg_capacity"]), "peg_capacity+foundation", "one name per combination")
	assert_true(ChapterPlan.whitelist().has("balance+covered_pegs") == false and ChapterPlan.whitelist().has("covered_pegs+balance"))


func test_road_follows_the_plan() -> void:
	# The validator checks every level's chapter and every combination against
	# the whitelist; a combination off the list fails it.
	assert_eq(LevelValidator.validate_path(Difficulty.LEVELS_DIR), [] as Array[String])
	var chapters: Array[Dictionary] = _built_chapters()
	assert_true(chapters.size() >= 5, "world 1-2 at least")
	assert_eq(LevelCatalog.track_length(MAIN), chapters[-1]["last"], "the road ends with its last built chapter")
	assert_eq(LevelValidator.fits_chapter(["peg_capacity", "trail"] as Array[String], 320).is_empty(), false,
			"a combination the chapter does not list is refused")
	assert_eq(LevelValidator.fits_chapter(["covered_pegs"] as Array[String], 60).is_empty(), false,
			"a mode before its chapter is refused")
	var level: Level = _level_at(MAIN, 1)
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		level = _level_at(MAIN, position)
		assert_true(level.min_moves <= 33, "main %d stays within 33 moves" % position)


func test_world_one_is_classic_then_capacity() -> void:
	# Section 2/3.1: 1-50 classic only, then unequal capacity mixed with classic
	# (2-3 mode levels for each classic one).
	for position: int in range(1, 51):
		assert_eq(LevelCatalog.mechanic_at(MAIN, position), Level.CLASSIC, "main %d" % position)
	for position: int in range(1, 6):
		var level: Level = _level_at(MAIN, position)
		assert_eq([level.get_peg_count(), level.get_disk_count()], [3, 3], "main %d: 3 disks on 3 pegs" % position)
	var classic: int = 0
	for position: int in range(51, 101):
		classic += 1 if LevelCatalog.mechanic_at(MAIN, position) == Level.CLASSIC else 0
	assert_eq(LevelCatalog.mechanic_at(MAIN, 51), PegCapacityRule.ID, "the chapter opens with its mode")
	assert_true(classic >= 12 and classic <= 17, "2-3 capacity levels per classic one (%d classic)" % classic)


func test_mode_chapters_mix_classic_and_repeats() -> void:
	for chapter: Dictionary in _built_chapters():
		if chapter["kind"] != ChapterPlan.MODE_CHAPTER:
			continue
		var first: int = chapter["first"]
		var length: int = ChapterPlan.length_of(chapter)
		var counts: Dictionary = {}
		var repeats_first_half: int = 0
		var run: int = 0
		var longest_classic_run: int = 0
		var previous: int = 0
		for position: int in range(first, int(chapter["last"]) + 1):
			var level: Level = _level_at(MAIN, position)
			var lesson: String = level.lesson()
			counts[lesson] = counts.get(lesson, 0) + 1
			run = run + 1 if lesson == Level.CLASSIC else 0
			longest_classic_run = maxi(longest_classic_run, run)
			if lesson != Level.CLASSIC and lesson != chapter["mode"]:
				assert_true(ChapterPlan.modes_before(first).has(lesson), "main %d repeats an earlier mode" % position)
				repeats_first_half += 1 if position - first < length / 2 else 0
			if lesson == chapter["mode"]:
				assert_true(level.min_moves >= previous, "main %d: the chapter's mode never gets easier" % position)
				previous = level.min_moves
		assert_eq(LevelCatalog.lesson_at(MAIN, first), chapter["mode"], "%s opens its chapter" % chapter["mode"])
		var classic: int = counts.get(Level.CLASSIC, 0)
		var expected: float = length / (float(chapter["ratio"]) + 1.0)
		assert_true(absf(classic - expected) <= 1.0, "%s: %d classic levels (%.1f)" % [chapter["mode"], classic, expected])
		assert_true(longest_classic_run <= 2, "classic levels never bunch up")
		assert_eq(repeats_first_half, 0, "repeats only in the second half")
		var repeats: int = length - classic - counts[chapter["mode"]]
		var earlier: Array[String] = ChapterPlan.modes_before(first)
		assert_eq(repeats, 0 if earlier.is_empty() else ceili((length - length / 2) / float(ChapterPlan.REPEAT_EVERY)),
				"%s: one earlier mode in every %d of the second half" % [chapter["mode"], ChapterPlan.REPEAT_EVERY])


func test_combination_chapters() -> void:
	# Section 3.4: half combinations, 30% single modes of the world, 20% classic;
	# it opens with a combination, and each combination comes in its first half.
	for chapter: Dictionary in _built_chapters():
		if chapter["kind"] != ChapterPlan.COMBO_CHAPTER:
			continue
		var first: int = chapter["first"]
		var length: int = ChapterPlan.length_of(chapter)
		var combos: int = 0
		var singles: int = 0
		var classic: int = 0
		var met: Dictionary = {}
		for position: int in range(first, int(chapter["last"]) + 1):
			var level: Level = _level_at(MAIN, position)
			if level.is_combo():
				combos += 1
				if not met.has(level.lesson()):
					met[level.lesson()] = position
					assert_true(position - first < length / 2, "%s first comes in the first half" % level.lesson())
					assert_true(TutorialDirector.is_mechanic_intro(level), "%s has a mini-tutorial" % level.lesson())
				# Each mode must matter: longer than either mode alone.
				assert_true(LevelForge.matters(level.start, level.goal, level.rule_ids, level.rule_params, level.min_moves),
						"main %d: both rules matter" % position)
			elif level.modes().is_empty():
				classic += 1
			else:
				singles += 1
				assert_true((chapter["singles"] as Array).has(level.lesson()), "main %d: a mode of this world" % position)
		assert_true(_level_at(MAIN, first).is_combo(), "a combination opens the chapter")
		assert_eq([combos, singles, classic], [length / 2, roundi(length * 0.3), roundi(length * 0.2)])
		assert_eq(met.size(), (chapter["combos"] as Array).size(), "every listed combination: %s" % str(met.keys()))


func test_islands_end_their_chapters() -> void:
	# Section 7 and the user's decision: an island at the end of every mode
	# chapter (and of the classic one), opened when the chapter is done.
	var islands: Array[String] = LevelCatalog.island_tracks()
	var expected: Array[int] = []
	for chapter: Dictionary in _built_chapters():
		if chapter["kind"] != ChapterPlan.COMBO_CHAPTER:
			expected.append(chapter["last"])
	var afters: Array[int] = []
	for island: String in islands:
		afters.append(LevelCatalog.island_after(island))
	assert_eq(afters, expected)
	assert_eq(LevelCatalog.island_mode(islands[0]), Level.CLASSIC)
	assert_eq(LevelCatalog.track_length(islands[0]), 40, "the classic island keeps its 40 levels")
	assert_eq(_level_at(islands[0], 1).difficulty, "hard", "and opens gently")
	for i: int in range(1, islands.size()):
		var mode: String = LevelCatalog.island_mode(islands[i])
		assert_eq(LevelCatalog.track_length(islands[i]), ChapterPlan.ISLAND_LEVELS, mode)
		for position: int in range(1, ChapterPlan.ISLAND_LEVELS + 1):
			var level: Level = _level_at(islands[i], position)
			assert_eq(level.modes(), [mode] as Array[String], "%s island %d" % [mode, position])
			assert_eq(level.difficulty, "expert", "%s island %d" % [mode, position])


func test_id_blocks() -> void:
	# Each mode and each combination numbers its levels in its own block.
	assert_eq(RoadBuilder.id_block("peg_capacity"), Difficulty.MECHANIC_FIRST_ID)
	assert_eq(RoadBuilder.id_block("covered_pegs"), Difficulty.MECHANIC_FIRST_ID + RoadBuilder.ID_BLOCK)
	var last: int = RoadBuilder.id_block(ChapterPlan.whitelist()[-1]) + RoadBuilder.ID_BLOCK - 1
	assert_true(Difficulty.is_mechanic_id(last), "the last combination block is still a mechanic id")
	assert_eq(RoadBuilder.file_stem("peg_capacity+foundation"), "capacity_foundation")
	assert_eq(RoadBuilder.parse_worlds("1-3"), [1, 2, 3] as Array[int])
	assert_eq(RoadBuilder.parse_worlds("1,4"), [1, 4] as Array[int])
