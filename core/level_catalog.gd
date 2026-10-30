class_name LevelCatalog
extends RefCounted
## The level path (level structure addendum v3, chapter system v1): one
## numbered road through the levels, plus islands ("Gizli Ada"): each mode
## chapter, and the classic one, ends at an island of its own that appears
## once its chapter's last main level is completed (user decision 2026-10-15:
## an island at the end of each chapter). Tiers and modes stay inside the level
## files; the player only sees numbered positions.
##
## data/levels/path.json, written by tools/road_builder.gd:
## { "main": [{ "file": "easy/easy_001.json", "id": 1001 }, ...],
##   "islands": [{ "mode": "classic", "after": 50, "levels": [{ "file": ..., "id": ... }, ...] }, ...] }
##
## Tracks: MAIN and one per island ("island_1", "island_2", ... in road
## order). A level opens once the one before it on its track is completed, an
## island's first level once its island is open, and a completed level always
## stays open. There is no other lock.

const PATH_FILE: String = "path.json"
## The demo road's path file (ChapterPlan.road_mode).
const DEMO_PATH_FILE: String = "demo_path.json"
const MAIN: String = "main"
const ISLAND_PREFIX: String = "island_"

## {main: [{file, id}], islands: [{mode, after, levels: [{file, id}]}]}.
static var _path: Dictionary = {}
## Track -> its entries [{file, id}].
static var _tracks: Dictionary = {}
## Island track -> {mode, after}.
static var _islands: Dictionary = {}
## Level id -> {track, position}.
static var _places: Dictionary = {}
## Mechanic level file -> its Level.mechanic().
static var _mechanics: Dictionary = {}
## Mechanic level file -> its Level.lesson().
static var _lessons: Dictionary = {}
## Mechanic level file -> its Level.variants.
static var _variants: Dictionary = {}
## Classic level files per tier (tools and tests).
static var _counts: Dictionary = {}


static func clear_cache() -> void:
	_path = {}
	_tracks = {}
	_islands = {}
	_places = {}
	_mechanics.clear()
	_lessons.clear()
	_variants.clear()
	_counts.clear()


## The parsed path file (see the class comment).
static func path_data() -> Dictionary:
	if _path.is_empty():
		var errors: Array[String] = []
		_path = read_path("%s/%s" % [Difficulty.LEVELS_DIR, path_file()], errors)
		for error: String in errors:
			push_error("Level path: %s" % error)
		_tracks[MAIN] = _path[MAIN]
		var islands: Array = _path["islands"]
		for i: int in islands.size():
			var track: String = "%s%d" % [ISLAND_PREFIX, i + 1]
			_tracks[track] = islands[i]["levels"]
			_islands[track] = {"mode": islands[i]["mode"], "after": islands[i]["after"]}
		for track: String in _tracks:
			var entries: Array = _tracks[track]
			for i: int in entries.size():
				_places[entries[i]["id"]] = {"track": track, "position": i + 1}
	return _path


## The path file of the road in use: path.json (full) or demo_path.json.
static func path_file() -> String:
	return DEMO_PATH_FILE if ChapterPlan.is_demo() else PATH_FILE


## Parses a path file; problems go to `errors`. The result always has both
## keys, possibly empty.
static func read_path(file_path: String, errors: Array[String]) -> Dictionary:
	var result: Dictionary = {MAIN: [] as Array[Dictionary], "islands": [] as Array[Dictionary]}
	if not FileAccess.file_exists(file_path):
		errors.append("%s not found" % file_path)
		return result
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("the path must be a JSON object")
		return result
	result[MAIN] = _read_entries(data.get(MAIN), MAIN, errors)
	if typeof(data.get("islands")) != TYPE_ARRAY:
		errors.append("\"islands\" must be a list")
		return result
	for island: Variant in data["islands"]:
		if typeof(island) != TYPE_DICTIONARY or typeof(island.get("mode")) != TYPE_STRING \
				or typeof(island.get("after")) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("bad island %s" % str(island))
			continue
		(result["islands"] as Array).append({"mode": island["mode"], "after": int(island["after"]),
				"levels": _read_entries(island.get("levels"), "island", errors)})
	return result


static func _read_entries(items: Variant, track: String, errors: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if typeof(items) != TYPE_ARRAY:
		errors.append("\"%s\" must be a list" % track)
		return entries
	for item: Variant in items:
		if typeof(item) != TYPE_DICTIONARY or typeof(item.get("file")) != TYPE_STRING \
				or typeof(item.get("id")) not in [TYPE_INT, TYPE_FLOAT]:
			errors.append("bad %s entry %s" % [track, str(item)])
			continue
		entries.append({"file": item["file"], "id": int(item["id"])})
	return entries


## MAIN, then every island track in road order.
static func tracks() -> Array[String]:
	path_data()
	var found: Array[String] = [MAIN]
	found.append_array(island_tracks())
	return found


## The island tracks in road order ("island_1", ...).
static func island_tracks() -> Array[String]:
	path_data()
	var found: Array[String] = []
	for i: int in _islands.size():
		found.append("%s%d" % [ISLAND_PREFIX, i + 1])
	return found


static func is_island(track: String) -> bool:
	path_data()
	return _islands.has(track)


## Main road position whose completion opens island `track` (0 for no island).
static func island_after(track: String) -> int:
	path_data()
	return _islands.get(track, {}).get("after", 0)


## The mode whose expert levels island `track` holds ("classic" for the first).
static func island_mode(track: String) -> String:
	path_data()
	return _islands.get(track, {}).get("mode", "")


## The island that opens after main road `position`, or "".
static func island_at(position: int) -> String:
	for track: String in island_tracks():
		if island_after(track) == position:
			return track
	return ""


static func track_length(track: String) -> int:
	path_data()
	return (_tracks.get(track, []) as Array).size()


## Levels on every track.
static func total_levels() -> int:
	var total: int = 0
	for track: String in tracks():
		total += track_length(track)
	return total


## {file, id} of the level at `position` (1-based) on `track`, or {}.
static func entry(track: String, position: int) -> Dictionary:
	if position < 1 or position > track_length(track):
		return {}
	return _tracks[track][position - 1]


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
	_read_mechanic(track, position, file)
	return _mechanics[file]


## Level.lesson() of the level at a path position (see mechanic_at()).
static func lesson_at(track: String, position: int) -> String:
	var file: String = entry(track, position).get("file", "")
	if not file.begins_with(Difficulty.MECHANICS + "/"):
		return Level.CLASSIC
	_read_mechanic(track, position, file)
	return _lessons[file]


static func _read_mechanic(track: String, position: int, file: String) -> void:
	if _mechanics.has(file):
		return
	var level: Level = load_at(track, position)
	_mechanics[file] = level.mechanic() if level != null else Level.CLASSIC
	_lessons[file] = level.lesson() if level != null else Level.CLASSIC
	_variants[file] = level.variants.duplicate() if level != null else []


## Level.variants of the level at a path position (see mechanic_at()).
static func variants_at(track: String, position: int) -> Array:
	var file: String = entry(track, position).get("file", "")
	if not file.begins_with(Difficulty.MECHANICS + "/"):
		return []
	_read_mechanic(track, position, file)
	return _variants[file]


## Main path position of the first level with `lesson` (Level.lesson(), which
## is its mechanic() for most levels), or 0 if none has it.
static func first_main_position(lesson: String) -> int:
	for position: int in range(1, track_length(MAIN) + 1):
		if lesson_at(MAIN, position) == lesson:
			return position
	return 0


## Main path position of the first level of `lesson` that uses sub-element
## `variant` (chapter waves v1), or 0.
static func first_variant_position(lesson: String, variant: String) -> int:
	for position: int in range(1, track_length(MAIN) + 1):
		if lesson_at(MAIN, position) == lesson and variants_at(MAIN, position).has(variant):
			return position
	return 0


## Where level `level_id` sits: {track, position}, or {} if it is not on the path.
static func place_of(level_id: int) -> Dictionary:
	path_data()
	return _places.get(level_id, {})


## An island shows up (and its first level opens) once its main level is
## completed; progress made on it keeps it open.
static func is_island_open(track: String, save: SaveSystem) -> bool:
	if not is_island(track):
		return false
	return save.is_completed(level_id_at(MAIN, island_after(track))) or save.is_completed(level_id_at(track, 1))


## The open islands, in road order.
static func open_islands(save: SaveSystem) -> Array[String]:
	var found: Array[String] = []
	for track: String in island_tracks():
		if is_island_open(track, save):
			found.append(track)
	return found


static func is_unlocked(track: String, position: int, save: SaveSystem) -> bool:
	var level_id: int = level_id_at(track, position)
	if level_id == -1:
		return false
	if save.is_completed(level_id):
		return true
	if is_island(track) and not is_island_open(track, save):
		return false
	return position == 1 or save.is_completed(level_id_at(track, position - 1))


## The level after (track, position) on the same track: {track, position}, or
## {} after the last one.
static func next_after(track: String, position: int) -> Dictionary:
	if position < 1 or position >= track_length(track):
		return {}
	return {"track": track, "position": position + 1}


## The first open, uncompleted level of `track`, or 0.
static func next_on(track: String, save: SaveSystem) -> int:
	for position: int in range(1, track_length(track) + 1):
		if not save.is_completed(level_id_at(track, position)) and is_unlocked(track, position, save):
			return position
	return 0


## Where "Play" continues: the first open, uncompleted level of the main path;
## once the main path is done, of the islands in road order. The very first
## level if everything is completed; {} if there are no levels.
static func next_to_play(save: SaveSystem) -> Dictionary:
	for track: String in tracks():
		var position: int = next_on(track, save)
		if position > 0:
			return {"track": track, "position": position}
	return {"track": MAIN, "position": 1} if track_length(MAIN) > 0 else {}


## Board header: "Səviyyə 7", "Ada · 3" on an island, or "Səviyyə" for a level
## that is not on the path (tests, tools).
static func level_title(level: Level) -> String:
	var place: Dictionary = place_of(level.id)
	if place.is_empty():
		return Languages.text("LEVEL_TITLE_PLAIN")
	return Languages.text("LEVEL_TITLE_BRANCH" if is_island(place["track"]) else "LEVEL_TITLE") % place["position"]


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


## Path of a mechanic level file, e.g. mechanic_path("fog_001.json").
static func mechanic_path(file_name: String) -> String:
	return "%s/%s/%s" % [Difficulty.LEVELS_DIR, Difficulty.MECHANICS, file_name]


static func load_mechanic(file_name: String) -> Level:
	var errors: Array[String] = []
	var level: Level = Level.load_file(mechanic_path(file_name), errors)
	if level == null:
		push_error("Cannot load %s: %s" % [file_name, "; ".join(errors)])
	return level
