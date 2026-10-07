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
