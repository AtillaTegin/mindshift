class_name LevelCatalog
extends RefCounted
## The level path (level structure addendum v3): one numbered road through the
## levels, plus a side branch, the "island", that appears once main level
## `branch_after` is completed. Tiers and mechanics stay inside the level
## files; the player only sees numbered positions on the path.
##
## data/levels/path.json, written by tools/path_builder.gd:
## { "branch_after": 50,
##   "main": [{ "file": "easy/easy_001.json", "id": 1001 }, ...],
##   "branch": [{ "file": "hard/hard_067.json", "id": 3067 }, ...] }
##
## A level opens once the one before it on its track is completed, and a
## completed level always stays open. There is no other lock.

const PATH_FILE: String = "path.json"
const MAIN: String = "main"
const BRANCH: String = "branch"
const TRACKS: Array[String] = [MAIN, BRANCH]

static var _path: Dictionary = {}
## Level id -> {track, position}.
static var _places: Dictionary = {}
## Mechanic level file -> its Level.mechanic().
static var _mechanics: Dictionary = {}
## Classic level files per tier (tools and tests).
static var _counts: Dictionary = {}


static func clear_cache() -> void:
	_path = {}
	_places = {}
	_mechanics.clear()
	_counts.clear()


## The parsed path file (see the class comment); both tracks always exist.
static func path_data() -> Dictionary:
	if _path.is_empty():
		var errors: Array[String] = []
		_path = read_path("%s/%s" % [Difficulty.LEVELS_DIR, PATH_FILE], errors)
		for error: String in errors:
			push_error("Level path: %s" % error)
		for track: String in TRACKS:
			var entries: Array = _path[track]
			for i: int in entries.size():
				_places[entries[i]["id"]] = {"track": track, "position": i + 1}
	return _path


## Parses a path file; problems go to `errors`. The result always has
## "branch_after" and both tracks, possibly empty.
static func read_path(file_path: String, errors: Array[String]) -> Dictionary:
	var result: Dictionary = {"branch_after": 0, MAIN: [] as Array[Dictionary], BRANCH: [] as Array[Dictionary]}
	if not FileAccess.file_exists(file_path):
		errors.append("%s not found" % file_path)
		return result
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("the path must be a JSON object")
		return result
	var after: Variant = data.get("branch_after")
	if typeof(after) in [TYPE_INT, TYPE_FLOAT] and after == floorf(after):
		result["branch_after"] = int(after)
	else:
		errors.append("\"branch_after\" must be an integer")
	for track: String in TRACKS:
		if typeof(data.get(track)) != TYPE_ARRAY:
			errors.append("\"%s\" must be a list" % track)
			continue
		for item: Variant in data[track]:
			if typeof(item) != TYPE_DICTIONARY or typeof(item.get("file")) != TYPE_STRING \
					or typeof(item.get("id")) not in [TYPE_INT, TYPE_FLOAT]:
				errors.append("bad %s entry %s" % [track, str(item)])
				continue
			(result[track] as Array).append({"file": item["file"], "id": int(item["id"])})
	return result


static func track_length(track: String) -> int:
	return (path_data().get(track, []) as Array).size()


## Main path position whose completion opens the branch.
static func branch_after() -> int:
	return path_data()["branch_after"]


## Levels on both tracks.
static func total_levels() -> int:
	return track_length(MAIN) + track_length(BRANCH)


## {file, id} of the level at `position` (1-based) on `track`, or {}.
static func entry(track: String, position: int) -> Dictionary:
	if position < 1 or position > track_length(track):
		return {}
	return path_data()[track][position - 1]


static func level_id_at(track: String, position: int) -> int:
	return entry(track, position).get("id", -1)


## The level at `position` on `track`, or null if there is none or it cannot be read.
static func load_at(track: String, position: int) -> Level:
	var place: Dictionary = entry(track, position)
	if place.is_empty():
		return null
	var errors: Array[String] = []
	var level: Level = Level.load_file("%s/%s" % [Difficulty.LEVELS_DIR, place["file"]], errors)
	if level == null:
		push_error("Cannot load %s %d: %s" % [track, position, "; ".join(errors)])
	return level


## Level.mechanic() of the level at a path position, without reading classic
## files: tier folders only hold classic levels (LevelValidator checks it).
static func mechanic_at(track: String, position: int) -> String:
	var file: String = entry(track, position).get("file", "")
	if not file.begins_with(Difficulty.MECHANICS + "/"):
		return Level.CLASSIC
	if not _mechanics.has(file):
		var level: Level = load_at(track, position)
		_mechanics[file] = level.mechanic() if level != null else Level.CLASSIC
	return _mechanics[file]


## Main path position of the first level with `mechanic` (Level.mechanic()),
## or 0 if none has it.
static func first_main_position(mechanic: String) -> int:
	for position: int in range(1, track_length(MAIN) + 1):
		if mechanic_at(MAIN, position) == mechanic:
			return position
	return 0


## Where level `level_id` sits: {track, position}, or {} if it is not on the path.
static func place_of(level_id: int) -> Dictionary:
	path_data()
	return _places.get(level_id, {})


## The island shows up (and its first level opens) once main level
## branch_after() is completed; progress made on it keeps it open.
static func is_branch_open(save: SaveSystem) -> bool:
	return save.is_completed(level_id_at(MAIN, branch_after())) or save.is_completed(level_id_at(BRANCH, 1))


static func is_unlocked(track: String, position: int, save: SaveSystem) -> bool:
	var level_id: int = level_id_at(track, position)
	if level_id == -1:
		return false
	if save.is_completed(level_id):
		return true
	if track == BRANCH and not is_branch_open(save):
		return false
	return position == 1 or save.is_completed(level_id_at(track, position - 1))


## The level after (track, position) on the same track: {track, position}, or
## {} after the last one.
static func next_after(track: String, position: int) -> Dictionary:
	if position < 1 or position >= track_length(track):
		return {}
	return {"track": track, "position": position + 1}


## Where "Play" continues: the first open, uncompleted level of the main path;
## once the main path is done, of the island. The very first level if
## everything is completed; {} if there are no levels.
static func next_to_play(save: SaveSystem) -> Dictionary:
	for track: String in TRACKS:
		for position: int in range(1, track_length(track) + 1):
			if not save.is_completed(level_id_at(track, position)) and is_unlocked(track, position, save):
				return {"track": track, "position": position}
	return {"track": MAIN, "position": 1} if track_length(MAIN) > 0 else {}


## Board header: "Səviyyə 7", "Ada · 3" on the island, or "Səviyyə" for a level
## that is not on the path (tests, tools).
static func level_title(level: Level) -> String:
	var place: Dictionary = place_of(level.id)
	if place.is_empty():
		return Languages.text("LEVEL_TITLE_PLAIN")
	return Languages.text("LEVEL_TITLE_BRANCH" if place["track"] == BRANCH else "LEVEL_TITLE") % place["position"]


## Classic level files of one tier (data/levels/<tier>/<tier>_NNN.json, no
## gaps); used by tools and tests, the game itself goes by the path.
static func level_count(tier: String) -> int:
	if not _counts.has(tier):
		var count: int = 0
		if Difficulty.is_known(tier):
			while count < Difficulty.MAX_LEVELS_PER_TIER and FileAccess.file_exists(Difficulty.level_path(tier, count + 1)):
				count += 1
		_counts[tier] = count
	return _counts[tier]


## The `index`-th classic level of `tier`, or null.
static func load_level(tier: String, index: int) -> Level:
	if index < 1 or index > level_count(tier):
		return null
	var errors: Array[String] = []
	var level: Level = Level.load_file(Difficulty.level_path(tier, index), errors)
	if level == null:
		push_error("Cannot load %s %d: %s" % [tier, index, "; ".join(errors)])
	return level


## Path of a mechanic level file, e.g. mechanic_path("frozen_01.json").
static func mechanic_path(file_name: String) -> String:
	return "%s/%s/%s" % [Difficulty.LEVELS_DIR, Difficulty.MECHANICS, file_name]


static func load_mechanic(file_name: String) -> Level:
	var errors: Array[String] = []
	var level: Level = Level.load_file(mechanic_path(file_name), errors)
	if level == null:
		push_error("Cannot load %s: %s" % [file_name, "; ".join(errors)])
	return level
