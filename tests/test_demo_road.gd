extends "res://tests/test_case.gd"
## The demo road (data/levels/demo_path.json, tools/demo_road.gd): 205 levels
## picked from the full road, chapter by chapter, no islands.
## Tests of the demo road; ROAD_MODE=full skips them.
const DEMO_ROAD_TESTS: Array[String] = ["test_chapters_have_their_counts", "test_demo_path_validates",
		"test_classic_chapter_teaches_on_small_boards", "test_chapters_end_with_their_big_test"]


func before_each() -> void:
	LevelCatalog.clear_cache()


func after_each() -> void:
	LevelCatalog.clear_cache()


func test_chapters_have_their_counts() -> void:
	var main: Array = LevelCatalog.path_data()[LevelCatalog.MAIN]
	assert_eq(main.size(), 205)
	assert_eq((LevelCatalog.path_data()["islands"] as Array).size(), 0, "no islands in the demo")
	assert_eq(int(ChapterPlan.CHAPTERS[-1]["last"]), 205)
	var expected: Array[int] = [25, 20, 20, 20, 10, 20, 20, 20, 10, 15, 15, 10]
	var lengths: Array[int] = []
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		lengths.append(ChapterPlan.length_of(chapter))
	assert_eq(lengths, expected)


func test_demo_path_validates() -> void:
	assert_eq(LevelValidator.validate_path(Difficulty.LEVELS_DIR), [] as Array[String])


func test_classic_chapter_teaches_on_small_boards() -> void:
	var main: Array = LevelCatalog.path_data()[LevelCatalog.MAIN]
	for i: int in 25:
		var level: Level = Level.load_file("%s/%s" % [Difficulty.LEVELS_DIR, main[i]["file"]], [] as Array[String])
		assert_true(level.modes().is_empty(), "main %d is classic" % (i + 1))
		assert_true(level.get_disk_count() >= 3 and level.get_disk_count() <= 5, "main %d has 3-5 disks" % (i + 1))


func test_chapters_end_with_their_big_test() -> void:
	var main: Array = LevelCatalog.path_data()[LevelCatalog.MAIN]
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		if chapter["kind"] == ChapterPlan.CLASSIC_CHAPTER:
			continue
		var last: int = int(chapter["last"])
		assert_true(ChapterPlan.is_big_test(last))
		var level: Level = Level.load_file("%s/%s" % [Difficulty.LEVELS_DIR, main[last - 1]["file"]], [] as Array[String])
		var weight: String = ChapterPlan.weight_of(level.modes()) if ChapterPlan.is_eased(int(chapter["world"])) else ""
		var span: Array[int] = ChapterPlan.big_test_range(weight) if weight != "" else ChapterPlan.BIG_TEST
		assert_true(level.min_moves >= span[0] and level.min_moves <= span[1], "main %d: %d moves" % [last, level.min_moves])
