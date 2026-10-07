extends "res://tests/test_case.gd"
## SaveSystem. Day 5 acceptance: progress survives closing and reopening the
## game, i.e. a fresh SaveSystem reading the same file sees the same progress.

const PATH: String = "user://test_save_system.json"


func before_each() -> void:
	_cleanup()


func after_each() -> void:
	_cleanup()


func _cleanup() -> void:
	for suffix: String in ["", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(PATH + suffix)


func test_missing_file_is_a_fresh_start() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_false(save.load_save())
	assert_eq(save.coins, 0)
	assert_eq(save.completed_levels, {})
	assert_false(FileAccess.file_exists(PATH), "loading never creates the file")


func test_progress_survives_reopening() -> void:
	var first: SaveSystem = SaveSystem.new(PATH)
	first.load_save()
	first.record_completion(1001, 3, 7, 12.4)
	first.record_completion(1002, 2, 10, 95.6)
	first.coins = 120
	first.last_daily_bonus_date = "2026-10-06"
	assert_true(first.write())
	# "Restart the game": a new instance reads the file.
	var second: SaveSystem = SaveSystem.new(PATH)
	assert_true(second.load_save())
	assert_eq(second.coins, 120)
	assert_eq(second.last_daily_bonus_date, "2026-10-06")
	assert_eq(second.get_record(1001), {"stars": 3, "best_moves": 7, "best_time_seconds": 12})
	assert_eq(second.get_record(1002), {"stars": 2, "best_moves": 10, "best_time_seconds": 95}, "rounded down like the stopwatch")
	assert_true(second.is_completed(1001))
	assert_false(second.is_completed(1003))
	assert_eq(second.get_total_stars(), 5)


func test_completion_is_written_immediately() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	save.record_completion(2001, 1, 30, 40.0)
	var reopened: SaveSystem = SaveSystem.new(PATH)
	assert_true(reopened.load_save(), "file exists without an explicit write()")
	assert_eq(reopened.get_stars(2001), 1)


func test_file_matches_spec_schema() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	save.coins = 120
	save.last_daily_bonus_date = "2026-10-06"
	save.record_completion(57, 3, 42, 95.0)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	assert_eq(data["coins"], 120)
	var record: Dictionary = data["completed_levels"]["57"]
	assert_eq(record.keys().size(), 3)
	assert_eq(record["stars"], 3)
	assert_eq(record["best_moves"], 42)
	assert_eq(record["best_time_seconds"], 95)
	assert_eq(data["last_daily_bonus_date"], "2026-10-06")
	assert_true(data.has("version"))
	save.last_daily_bonus_date = ""
	save.write()
	assert_null(JSON.parse_string(FileAccess.get_file_as_string(PATH))["last_daily_bonus_date"])


func test_best_values_are_kept_separately() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_true(save.record_completion(1001, 2, 9, 30.0), "first completion")
	assert_false(save.record_completion(1001, 1, 12, 50.0), "worse in every way")
	assert_eq(save.get_record(1001), {"stars": 2, "best_moves": 9, "best_time_seconds": 30})
	assert_true(save.record_completion(1001, 2, 9, 20.0), "faster")
	assert_true(save.record_completion(1001, 3, 7, 60.0), "better moves, slower")
	assert_eq(save.get_record(1001), {"stars": 3, "best_moves": 7, "best_time_seconds": 20})


func test_overwrites_existing_file_and_leaves_no_temp() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	save.record_completion(1001, 1, 9, 10.0)
	save.record_completion(1002, 1, 9, 10.0)
	assert_false(FileAccess.file_exists(PATH + ".tmp"))
	var reopened: SaveSystem = SaveSystem.new(PATH)
	reopened.load_save()
	assert_eq(reopened.completed_levels.size(), 2)


func test_damaged_file_is_kept_and_progress_starts_fresh() -> void:
	allow_engine_errors = true  # the damaged file is reported with a warning
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("{ \"coins\": 12, ")
	file.close()
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_false(save.load_save())
	assert_eq(save.coins, 0)
	assert_true(FileAccess.file_exists(PATH + ".corrupt"), "damaged save kept for recovery")


func test_malformed_entries_are_skipped() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"coins": -5,
		"completed_levels": {
			"1001": {"stars": 3, "best_moves": 7, "best_time_seconds": 10},
			"1002": {"stars": 9, "best_moves": 7, "best_time_seconds": 10},
			"abc": {"stars": 1, "best_moves": 7, "best_time_seconds": 10},
			"1003": "nope",
			"1004": {"stars": 2},
		},
		"last_daily_bonus_date": 5,
		"settings": {"sound_enabled": "yes"},
	}))
	file.close()
	var save: SaveSystem = SaveSystem.new(PATH)
	assert_true(save.load_save())
	assert_eq(save.coins, 0, "negative coins clamped")
	assert_eq(save.completed_levels.keys(), ["1001"])
	assert_eq(save.last_daily_bonus_date, "")
	assert_true(save.sound_enabled)


func test_sound_setting_persists() -> void:
	var save: SaveSystem = SaveSystem.new(PATH)
	save.set_sound_enabled(false)
	var reopened: SaveSystem = SaveSystem.new(PATH)
	reopened.load_save()
	assert_false(reopened.sound_enabled)
