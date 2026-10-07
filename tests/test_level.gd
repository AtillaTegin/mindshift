extends "res://tests/test_case.gd"
## Level model (spec 4.5 JSON) and LevelValidator.

const TEMP_DIR: String = "user://test_levels"


func after_each() -> void:
	_remove_temp_dir()


## Easy level: 3 disks from the left tower to the right tower, 7 moves.
func _classic_level() -> Level:
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[], [], [3, 2, 1]])
	var path: Array[Move] = Solver.solve(start, goal, RuleSet.classic())["path"]
	var rule_ids: Array[String] = ["classic_hanoi"]
	return Level.create(1001, "easy", start, goal, rule_ids, path)


func _errors_for(data: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var level: Level = Level.from_dict(data, errors)
	if level != null:
		LevelValidator.validate_level(level, errors)
	return errors


func _assert_rejected(data: Dictionary, expected_fragment: String) -> void:
	var errors: Array[String] = _errors_for(data)
	var text: String = " | ".join(errors)
	assert_false(errors.is_empty(), "expected a problem mentioning \"%s\"" % expected_fragment)
	assert_true(text.contains(expected_fragment), "\"%s\" not in: %s" % [expected_fragment, text])


func test_created_level_matches_spec_format() -> void:
	var data: Dictionary = _classic_level().to_dict()
	assert_eq(data.keys(), Array(Level.KEYS), "keys in spec order")
	assert_eq(data["id"], 1001)
	assert_eq(data["pegs"], 3)
	assert_eq(data["disks"], 3)
	assert_eq(data["start"], [[3, 2, 1], [], []])
	assert_eq(data["goal"], [[], [], [3, 2, 1]])
	assert_eq(data["rules"], ["classic_hanoi"])
	assert_eq(data["min_moves"], 7)
	assert_eq(data["solution_path"].size(), 7)
	assert_eq(data["star_thresholds"], {"three": 7, "two": 9})
	assert_null(data["time_limit_seconds"])


func test_two_star_threshold_is_rounded_125_percent() -> void:
	assert_eq(Level.two_star_threshold(7), 9, "8.75")
	assert_eq(Level.two_star_threshold(4), 5)
	assert_eq(Level.two_star_threshold(2), 3, "2.5 rounds up")
	assert_eq(Level.two_star_threshold(36), 45)


func test_json_round_trip_validates() -> void:
	var level: Level = _classic_level()
	var errors: Array[String] = []
	var parsed: Level = Level.from_dict(JSON.parse_string(level.to_json()), errors)
	assert_not_null(parsed)
	assert_eq(errors, [] as Array[String])
	assert_eq(parsed.to_dict(), level.to_dict())
	LevelValidator.validate_level(parsed, errors)
	assert_eq(errors, [] as Array[String])


func test_file_round_trip() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR + "/easy")
	var path: String = TEMP_DIR + "/easy/easy_001.json"
	assert_eq(_classic_level().save_file(path), OK)
	var errors: Array[String] = []
	var level: Level = LevelValidator.load_and_validate(path, errors)
	assert_not_null(level)
	assert_eq(errors, [] as Array[String])
	assert_eq(level.min_moves, 7)


func test_rejects_min_moves_that_is_not_minimal() -> void:
	# A legal 5-move path where 3 moves suffice: the validator must re-solve.
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[3], [], [2, 1]])
	var optimal: Array[Move] = Solver.solve(start, goal, RuleSet.classic())["path"]
	assert_eq(optimal.size(), 3, "optimum")
	# Detour: move disk 1 away and back first, then solve.
	var detour: Array[Move] = [Move.new(0, 1), Move.new(1, 0)]
	detour.append_array(optimal)
	var rule_ids: Array[String] = ["classic_hanoi"]
	var level: Level = Level.create(1001, "easy", start, goal, rule_ids, detour)
	var errors: Array[String] = []
	level.check(errors)
	assert_eq(errors, [] as Array[String], "structurally fine")
	LevelValidator.validate_level(level, errors)
	assert_true(" ".join(errors).contains("shortest solution has 3 moves"), str(errors))


func test_rejects_tampered_fields() -> void:
	var base: Dictionary = JSON.parse_string(_classic_level().to_json())
	var short_path: Dictionary = base.duplicate(true)
	short_path["solution_path"] = base["solution_path"].slice(0, 6)
	_assert_rejected(short_path, "solution_path has 6 moves, min_moves is 7")
	var cases: Array = [
		["min_moves", 6, "three must equal min_moves"],
		["star_thresholds", {"three": 7, "two": 10}, "star_thresholds.two"],
		["star_thresholds", {"three": 6, "two": 9}, "three must equal min_moves"],
		["difficulty", "hard", "is not a hard size"],
		["difficulty", "legendary", "unknown difficulty"],
		["id", 2001, "outside the easy range"],
		["id", 1001.5, "must be an integer"],
		["pegs", 4, "do not match start"],
		["disks", 2, "do not match start"],
		["rules", ["classic_hanoi", "gravity"], "empty or unknown"],
		["rules", [], "empty or unknown"],
		["goal", [[], [], [3, 1, 2]], "goal is not a valid position"],
		["goal", [[], [], [4, 2, 1]], "exactly the disks 1..3"],
		["goal", [[], [3, 2, 1]], "goal has 2 pegs"],
		["start", [[1, 2, 3], [], []], "start is not a valid position"],
		["solution_path", [[0, 2], [0, 2], [2, 1], [0, 2], [1, 0], [1, 2], [0, 2]], "move 2"],
		["solution_path", [[0, 1], [1, 0], [0, 1], [1, 0], [0, 1], [1, 0], [0, 1]], "does not end at the goal"],
		["solution_path", [[0, 2], "x"], "integer pairs"],
		["time_limit_seconds", -5, "positive number"],
		["time_limit_seconds", "soon", "positive number"],
	]
	for entry: Array in cases:
		var data: Dictionary = base.duplicate(true)
		data[entry[0]] = entry[1]
		_assert_rejected(data, entry[2])


func test_rejects_missing_unknown_and_wrong_type() -> void:
	var base: Dictionary = JSON.parse_string(_classic_level().to_json())
	var missing: Dictionary = base.duplicate(true)
	missing.erase("goal")
	_assert_rejected(missing, "missing key \"goal\"")
	var extra: Dictionary = base.duplicate(true)
	extra["bonus"] = 1
	_assert_rejected(extra, "unknown key \"bonus\"")
	var errors: Array[String] = []
	assert_null(Level.from_dict([1, 2], errors))
	assert_true(" ".join(errors).contains("JSON object"))


func test_rejects_start_equal_to_goal() -> void:
	var data: Dictionary = JSON.parse_string(_classic_level().to_json())
	data["goal"] = data["start"]
	_assert_rejected(data, "start equals goal")


func test_rejects_min_moves_outside_tier() -> void:
	# 3 pegs / 4 disks, 15 moves: correct and optimal, but too long for easy.
	var start: PuzzleState = PuzzleState.new([[4, 3, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[], [], [4, 3, 2, 1]])
	var rule_ids: Array[String] = ["classic_hanoi"]
	var level: Level = Level.create(1001, "easy", start, goal, rule_ids, Solver.solve(start, goal, RuleSet.classic())["path"])
	var errors: Array[String] = []
	level.check(errors)
	assert_true(" ".join(errors).contains("min_moves 15 is outside easy (5-11)"), str(errors))


func test_load_file_reports_bad_json_and_missing_file() -> void:
	var errors: Array[String] = []
	assert_null(Level.load_file(TEMP_DIR + "/nope.json", errors))
	assert_true(" ".join(errors).contains("file not found"))
	DirAccess.make_dir_recursive_absolute(TEMP_DIR)
	var file: FileAccess = FileAccess.open(TEMP_DIR + "/broken.json", FileAccess.WRITE)
	file.store_string("{ \"id\": ")
	file.close()
	errors.clear()
	assert_null(Level.load_file(TEMP_DIR + "/broken.json", errors))
	assert_true(" ".join(errors).contains("invalid JSON"))


func test_directory_checks_folder_duplicates_and_counts() -> void:
	DirAccess.make_dir_recursive_absolute(TEMP_DIR + "/easy")
	DirAccess.make_dir_recursive_absolute(TEMP_DIR + "/medium")
	var level: Level = _classic_level()
	level.save_file(TEMP_DIR + "/easy/easy_001.json")
	level.save_file(TEMP_DIR + "/easy/easy_002.json")  # same id, same puzzle
	level.save_file(TEMP_DIR + "/medium/medium_001.json")  # wrong folder
	var report: Dictionary = LevelValidator.validate_directory(TEMP_DIR)
	assert_eq(report["files"], 3)
	var failures: Dictionary = report["failures"]
	assert_false(failures.has(TEMP_DIR + "/easy/easy_001.json"), "first copy is fine")
	var second: String = " ".join(failures.get(TEMP_DIR + "/easy/easy_002.json", []))
	assert_true(second.contains("duplicate id 1001"), second)
	assert_true(second.contains("same start and goal"), second)
	var wrong_folder: String = " ".join(failures.get(TEMP_DIR + "/medium/medium_001.json", []))
	assert_true(wrong_folder.contains("stored in the \"medium\" folder"), wrong_folder)
	assert_eq(report["valid_counts"], {"easy": 1})


func test_difficulty_table() -> void:
	assert_eq(Difficulty.ORDER, ["easy", "medium", "hard", "expert"] as Array[String])
	assert_false(Difficulty.accepts_moves("easy", 4))
	assert_true(Difficulty.accepts_moves("easy", 5))
	assert_true(Difficulty.accepts_moves("easy", 11))
	assert_false(Difficulty.accepts_moves("easy", 12))
	assert_true(Difficulty.accepts_moves("medium", 12))
	assert_true(Difficulty.accepts_moves("medium", 20))
	assert_true(Difficulty.accepts_moves("hard", 21))
	assert_true(Difficulty.accepts_moves("hard", 33))
	assert_true(Difficulty.accepts_moves("expert", 34))
	assert_true(Difficulty.accepts_moves("expert", 49))
	assert_false(Difficulty.accepts_moves("expert", 33))
	assert_false(Difficulty.accepts_moves("nope", 5))
	assert_true(Difficulty.accepts_size("hard", 4, 7))
	assert_false(Difficulty.accepts_size("hard", 4, 6), "4p/6d can never reach 21 moves")
	assert_false(Difficulty.accepts_size("expert", 5, 10), "5 pegs dropped")
	assert_true(Difficulty.accepts_id("medium", 2001))
	assert_false(Difficulty.accepts_id("medium", 3001))
	assert_eq(Difficulty.describe_moves("easy"), "5-11")
	assert_eq(Difficulty.describe_moves("expert"), "34+")


func test_tier_ranges_do_not_overlap() -> void:
	for i: int in range(1, Difficulty.ORDER.size()):
		var previous: Dictionary = Difficulty.get_tier(Difficulty.ORDER[i - 1])
		var current: Dictionary = Difficulty.get_tier(Difficulty.ORDER[i])
		assert_eq(current["min_moves"], previous["max_moves"] + 1, Difficulty.ORDER[i])


func test_unlock_requirements() -> void:
	assert_eq(Difficulty.unlock_requirement("easy"), 0)
	assert_eq(Difficulty.unlock_requirement("medium"), 15)
	assert_eq(Difficulty.unlock_requirement("hard"), 10)
	assert_eq(Difficulty.unlock_requirement("expert"), 10)
	assert_eq(Difficulty.previous_tier("easy"), "")
	assert_eq(Difficulty.previous_tier("expert"), "hard")


func _remove_temp_dir() -> void:
	if not DirAccess.dir_exists_absolute(TEMP_DIR):
		return
	for sub: String in DirAccess.get_directories_at(TEMP_DIR):
		for file_name: String in DirAccess.get_files_at("%s/%s" % [TEMP_DIR, sub]):
			DirAccess.remove_absolute("%s/%s/%s" % [TEMP_DIR, sub, file_name])
		DirAccess.remove_absolute("%s/%s" % [TEMP_DIR, sub])
	for file_name: String in DirAccess.get_files_at(TEMP_DIR):
		DirAccess.remove_absolute("%s/%s" % [TEMP_DIR, file_name])
	DirAccess.remove_absolute(TEMP_DIR)
