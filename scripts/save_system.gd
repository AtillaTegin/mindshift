class_name SaveSystem
extends RefCounted
## Player progress in a local JSON file (spec 4.9). Every change is written
## straight away, via a temp file and a rename, so quitting or crashing never
## loses a finished level or leaves a half-written save.
##
## File format:
## { "version": 1, "coins": 120,
##   "completed_levels": { "1001": { "stars": 3, "best_moves": 7, "best_time_seconds": 95 } },
##   "last_daily_bonus_date": "2026-10-06" or null,
##   "settings": { "sound_enabled": true, "theme": "light", "language": "az" },
##   "daily": { "date": "2026-10-09", "free_undos_used": 1, "ads_watched": 0 },
##   "unlimited_hints_until": 0 }
## (settings.theme/language, daily and unlimited_hints_until were added later;
## older saves without them still load.)

const DEFAULT_PATH: String = "user://save.json"
const VERSION: int = 1

var path: String
var coins: int = 0
## Level id (as String, the JSON key) -> { stars, best_moves, best_time_seconds }.
var completed_levels: Dictionary = {}
## "YYYY-MM-DD", or "" when no bonus was ever claimed.
var last_daily_bonus_date: String = ""
var sound_enabled: bool = true
## "light" or "dark" (ThemeManager modes).
var theme: String = "light"
## Language code, e.g. "az" (see Languages).
var language: String = "az"
## Day the daily counters below belong to ("YYYY-MM-DD"); EconomySystem resets
## them when the day changes.
var daily_date: String = ""
var free_undos_used: int = 0
var ads_watched: int = 0
## Unix time (seconds) until which hints are free; 0 = never bought.
var unlimited_hints_until: int = 0


## In --script runs (tests, tools) a user:// path is moved into the test
## sandbox, so they can never write the player's real save folder.
func _init(p_path: String = DEFAULT_PATH) -> void:
	path = StoragePaths.resolve(p_path)


## Loads the file. A missing file means a fresh start. A damaged file is kept
## as <path>.corrupt (never silently thrown away) and progress starts fresh.
## Returns true if an existing save was read.
func load_save() -> bool:
	_reset()
	if not FileAccess.file_exists(path):
		return false
	var json: JSON = JSON.new()
	var parsed: bool = json.parse(FileAccess.get_file_as_string(path)) == OK
	var data: Variant = json.data if parsed else null
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file %s is damaged; keeping it as %s.corrupt" % [path, path])
		DirAccess.copy_absolute(path, path + ".corrupt")
		return false
	_read(data)
	return true


## Writes the whole save; returns false if the file could not be written.
func write() -> bool:
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write save %s: %s" % [temp_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(to_dict(), "  ") + "\n")
	file.close()
	var error: Error = DirAccess.rename_absolute(temp_path, path)
	if error != OK:
		push_error("Cannot replace save %s: %s" % [path, error_string(error)])
		return false
	return true


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"coins": coins,
		"completed_levels": completed_levels.duplicate(true),
		"last_daily_bonus_date": last_daily_bonus_date if not last_daily_bonus_date.is_empty() else null,
		"settings": {"sound_enabled": sound_enabled, "theme": theme, "language": language},
		"daily": {"date": daily_date, "free_undos_used": free_undos_used, "ads_watched": ads_watched},
		"unlimited_hints_until": unlimited_hints_until,
	}


func is_completed(level_id: int) -> bool:
	return completed_levels.has(str(level_id))


## The level's record, or an empty Dictionary if it was never completed.
func get_record(level_id: int) -> Dictionary:
	return completed_levels.get(str(level_id), {})


func get_stars(level_id: int) -> int:
	return int(get_record(level_id).get("stars", 0))


## Completed levels of one difficulty tier, counted from completed_levels.
func completed_count(tier: String) -> int:
	var count: int = 0
	for key: String in completed_levels:
		if Difficulty.tier_of_id(key.to_int()) == tier:
			count += 1
	return count


func get_total_stars() -> int:
	var total: int = 0
	for record: Dictionary in completed_levels.values():
		total += int(record["stars"])
	return total


## Records a finished level, keeping the best stars, moves and time (each on
## its own), and writes the save. Returns true if anything improved. Seconds
## are rounded down, like the stopwatch the player saw.
func record_completion(level_id: int, stars: int, moves: int, seconds: float) -> bool:
	var whole_seconds: int = maxi(floori(seconds), 0)
	var key: String = str(level_id)
	var record: Dictionary = completed_levels.get(key, {})
	var improved: bool = record.is_empty()
	if record.is_empty():
		record = {"stars": stars, "best_moves": moves, "best_time_seconds": whole_seconds}
	else:
		if stars > int(record["stars"]):
			record["stars"] = stars
			improved = true
		if moves < int(record["best_moves"]):
			record["best_moves"] = moves
			improved = true
		if whole_seconds < int(record["best_time_seconds"]):
			record["best_time_seconds"] = whole_seconds
			improved = true
	completed_levels[key] = record
	write()
	return improved


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	write()


func set_theme(mode: String) -> void:
	theme = mode
	write()


func set_language(code: String) -> void:
	language = code
	write()


func _reset() -> void:
	coins = 0
	completed_levels = {}
	last_daily_bonus_date = ""
	sound_enabled = true
	theme = "light"
	language = "az"
	daily_date = ""
	free_undos_used = 0
	ads_watched = 0
	unlimited_hints_until = 0


## Reads what it can; malformed entries are skipped rather than failing the load.
func _read(data: Dictionary) -> void:
	coins = maxi(_as_int(data.get("coins"), 0), 0)
	var levels: Variant = data.get("completed_levels")
	if typeof(levels) == TYPE_DICTIONARY:
		for key: Variant in levels:
			var entry: Variant = levels[key]
			if typeof(key) != TYPE_STRING or not (key as String).is_valid_int() or typeof(entry) != TYPE_DICTIONARY:
				continue
			var stars: int = _as_int(entry.get("stars"), -1)
			var moves: int = _as_int(entry.get("best_moves"), -1)
			var seconds: int = _as_int(entry.get("best_time_seconds"), -1)
			if stars < 1 or stars > 3 or moves < 0 or seconds < 0:
				continue
			completed_levels[key] = {"stars": stars, "best_moves": moves, "best_time_seconds": seconds}
	var bonus_date: Variant = data.get("last_daily_bonus_date")
	if typeof(bonus_date) == TYPE_STRING:
		last_daily_bonus_date = bonus_date
	var settings: Variant = data.get("settings")
	if typeof(settings) == TYPE_DICTIONARY:
		if typeof(settings.get("sound_enabled")) == TYPE_BOOL:
			sound_enabled = settings["sound_enabled"]
		if typeof(settings.get("theme")) == TYPE_STRING:
			theme = settings["theme"]
		if typeof(settings.get("language")) == TYPE_STRING:
			language = settings["language"]
	var daily: Variant = data.get("daily")
	if typeof(daily) == TYPE_DICTIONARY and typeof(daily.get("date")) == TYPE_STRING:
		daily_date = daily["date"]
		free_undos_used = maxi(_as_int(daily.get("free_undos_used"), 0), 0)
		ads_watched = maxi(_as_int(daily.get("ads_watched"), 0), 0)
	unlimited_hints_until = maxi(_as_int(data.get("unlimited_hints_until"), 0), 0)


static func _as_int(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT:
		return value
	if typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value):
		return int(value)
	return fallback
