class_name LevelCatalog
extends RefCounted
## The shipped levels: data/levels/<tier>/<tier>_001.json, _002.json, ... with
## no gaps (the generator writes them that way and the validator checks it).
## Files are probed by name, which also works inside an exported game.

## Bonus levels (bonus mechanics addendum) are listed in
## data/levels/bonus/index.json: { "levels": [{ "file", "id", "tab" }] }.
## They are optional extras: always open, shown at the end of their tab, and
## never counted toward unlocking a tier.
const BONUS_INDEX_FILE: String = "index.json"
const BONUS_PER_TAB: int = 2

static var _counts: Dictionary = {}
static var _bonus_entries: Array[Dictionary] = []
static var _bonus_loaded: bool = false


static func level_count(tier: String) -> int:
	if not _counts.has(tier):
		var count: int = 0
		if Difficulty.is_known(tier):
			while count < Difficulty.MAX_LEVELS_PER_TIER and FileAccess.file_exists(Difficulty.level_path(tier, count + 1)):
				count += 1
		_counts[tier] = count
	return _counts[tier]


static func clear_cache() -> void:
	_counts.clear()
	_bonus_entries.clear()
	_bonus_loaded = false


## Every bonus level in index order: [{ file, id, tab }].
static func bonus_entries() -> Array[Dictionary]:
	if not _bonus_loaded:
		var errors: Array[String] = []
		_bonus_entries = read_bonus_index(bonus_dir() + "/" + BONUS_INDEX_FILE, errors)
		for error: String in errors:
			push_error("Bonus index: %s" % error)
		_bonus_loaded = true
	return _bonus_entries


## The bonus levels shown at the end of `tier`'s tab.
static func bonus_for_tab(tier: String) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in bonus_entries():
		if entry["tab"] == tier:
			entries.append(entry)
	return entries


## The index entry of bonus level `id`, or {}.
static func bonus_entry_for_id(id: int) -> Dictionary:
	for entry: Dictionary in bonus_entries():
		if entry["id"] == id:
			return entry
	return {}


## The tier whose prices apply to `level` (hint cost): its own tier, or for a
## bonus level the tab it is shown in.
static func economy_tier(level: Level) -> String:
	if level.is_bonus():
		return bonus_entry_for_id(level.id).get("tab", Difficulty.ORDER[0])
	return level.difficulty


## Short name for the board header: "Asan · 7", or "Bonus · 2" (index order).
static func level_title(level: Level) -> String:
	if level.is_bonus():
		return "%s · %d" % [Difficulty.display_name(Difficulty.BONUS), level.id - Difficulty.BONUS_FIRST_ID + 1]
	return "%s · %d" % [Difficulty.display_name(level.difficulty), Difficulty.index_of_id(level.id)]


static func bonus_dir() -> String:
	return "%s/%s" % [Difficulty.LEVELS_DIR, Difficulty.BONUS]


## The bonus level stored in `file_name`, or null.
static func load_bonus(file_name: String) -> Level:
	var errors: Array[String] = []
	var level: Level = Level.load_file("%s/%s" % [bonus_dir(), file_name], errors)
	if level == null:
		push_error("Cannot load bonus %s: %s" % [file_name, "; ".join(errors)])
	return level


## Parses a bonus index file; problems go to `errors`. A missing file means
## "no bonus levels" and is not an error.
static func read_bonus_index(path: String, errors: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if not FileAccess.file_exists(path):
		return entries
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("levels")) != TYPE_ARRAY:
		errors.append("index must be {\"levels\": [...]}")
		return entries
	for item: Variant in data["levels"]:
		if typeof(item) != TYPE_DICTIONARY or typeof(item.get("file")) != TYPE_STRING \
				or typeof(item.get("id")) not in [TYPE_INT, TYPE_FLOAT] or not Difficulty.ORDER.has(item.get("tab")):
			errors.append("bad index entry %s" % str(item))
			continue
		entries.append({"file": item["file"], "id": int(item["id"]), "tab": item["tab"]})
	return entries


## The level, or null if it does not exist or cannot be parsed.
static func load_level(tier: String, index: int) -> Level:
	if index < 1 or index > level_count(tier):
		return null
	var errors: Array[String] = []
	var level: Level = Level.load_file(Difficulty.level_path(tier, index), errors)
	if level == null:
		push_error("Cannot load %s %d: %s" % [tier, index, "; ".join(errors)])
	return level


## The level after (tier, index): the next one in the tier, otherwise the first
## level of the next tier. Returns {"tier", "index"}, or {} after the last level.
static func next_after(tier: String, index: int) -> Dictionary:
	if index < level_count(tier):
		return {"tier": tier, "index": index + 1}
	var position: int = Difficulty.ORDER.find(tier)
	for next_position: int in range(position + 1, Difficulty.ORDER.size()):
		var next_tier: String = Difficulty.ORDER[next_position]
		if level_count(next_tier) > 0:
			return {"tier": next_tier, "index": 1}
	return {}


## A tier is open once enough levels of the tier before it are completed
## (Difficulty.UNLOCK_AFTER_COMPLETED); the first tier is always open.
static func is_tier_unlocked(tier: String, save: SaveSystem) -> bool:
	return completed_toward_unlock(tier, save) >= Difficulty.unlock_requirement(tier)


## Completed levels of the previous tier that count toward opening `tier`.
static func completed_toward_unlock(tier: String, save: SaveSystem) -> int:
	var previous: String = Difficulty.previous_tier(tier)
	return save.completed_count(previous) if not previous.is_empty() else 0


## Inside an open tier the first level is open and every other level opens once
## the one before it is completed. A level already completed always stays open,
## so progress made under older rules is never taken away.
static func is_unlocked(tier: String, index: int, save: SaveSystem) -> bool:
	if index < 1 or index > level_count(tier):
		return false
	if save.is_completed(Difficulty.id_for(tier, index)):
		return true
	return is_tier_unlocked(tier, save) and (index == 1 or save.is_completed(Difficulty.id_for(tier, index - 1)))


## Where "Play" continues: the first unlocked, uncompleted level of the hardest
## open tier that still has one, so a player who has opened a new tier moves on
## instead of being kept in the old one. The very first level if everything is
## completed; {} if no levels exist.
static func next_to_play(save: SaveSystem) -> Dictionary:
	for position: int in range(Difficulty.ORDER.size() - 1, -1, -1):
		var tier: String = Difficulty.ORDER[position]
		if not is_tier_unlocked(tier, save):
			continue
		for index: int in range(1, level_count(tier) + 1):
			if not save.is_completed(Difficulty.id_for(tier, index)) and is_unlocked(tier, index, save):
				return {"tier": tier, "index": index}
	for tier: String in Difficulty.ORDER:
		if level_count(tier) > 0:
			return {"tier": tier, "index": 1}
	return {}
