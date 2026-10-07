class_name LevelCatalog
extends RefCounted
## The shipped levels: data/levels/<tier>/<tier>_001.json, _002.json, ... with
## no gaps (the generator writes them that way and the validator checks it).
## Files are probed by name, which also works inside an exported game.

static var _counts: Dictionary = {}


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


## The first level of each tier is open; every other level opens once the one
## before it in the same tier is completed.
static func is_unlocked(tier: String, index: int, save: SaveSystem) -> bool:
	if index < 1 or index > level_count(tier):
		return false
	return index == 1 or save.is_completed(Difficulty.id_for(tier, index - 1))


## Where "Play" continues: the first unlocked, uncompleted level in tier order;
## the very first level if everything is completed. {} if no levels exist.
static func next_to_play(save: SaveSystem) -> Dictionary:
	for tier: String in Difficulty.ORDER:
		for index: int in range(1, level_count(tier) + 1):
			if not save.is_completed(Difficulty.id_for(tier, index)) and is_unlocked(tier, index, save):
				return {"tier": tier, "index": index}
	for tier: String in Difficulty.ORDER:
		if level_count(tier) > 0:
			return {"tier": tier, "index": 1}
	return {}
