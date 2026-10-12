class_name PathBuilder
extends SceneTree
## Lays every level out on the level path (level structure addendum v3) and
## writes data/levels/path.json (format: LevelCatalog):
##   godot --headless --path . --script res://tools/path_builder.gd
## Run it after the level generator or the mechanic level builder.
##
## Main path: the first FIRST_EASY levels are classic easy ones (the two
## tutorial levels first). After that the tiers are mixed by weight curves over
## the progress: easy levels turn into rare "breathers", medium leads early and
## hard takes over towards the end. Each step takes the tier that lags its
## curve the most, with a little seeded jitter, so the order is neither blocks
## nor random. Inside a tier levels always come easiest first.
## Chapters that run along the whole road (SPREADS: karakuri from main 12,
## the caravan road from main 17, the Nine Rings from main 20; user requests
## 2026-10-12) put their first level at a fixed early slot, their last a few
## levels before the end of the road, and one every so many levels in between
## (seeded gaps within the chapter's range that add up to the whole stretch, so
## no part of the road goes without them), easiest first. The great exchange bosses come at BOSS_FROM and then every
## BOSS_EVERY levels, easiest first. Other mechanic levels are spread evenly
## from MECHANICS_FROM on. On a clash a level takes the next free slot
## (karakuri are placed first and never move).
## Each mechanic level counts as a level of its own tier.
## Branch ("island", shown once main level BRANCH_AFTER is completed): every
## expert level plus the hardest BRANCH_HARD hard and BRANCH_MEDIUM medium
## levels as breathers, opening with a hard one.
## Exits with code 0 only when the path was written and validates.

const SEED: int = 20261011
const FIRST_EASY: int = 5
const BRANCH_AFTER: int = 50
const MECHANICS_FROM: int = 10
## Mechanic -> [first slot, levels left free at the end of the road, smallest
## gap, largest gap]; placed in this order. Karakuri gaps were 5-9; with the
## road at ~240 levels 24 of them only reach its end with gaps up to 10.
const SPREADS: Dictionary = {
	"covered_pegs": [12, 10, 5, 10],
	"adjacent_pegs": [17, 6, 5, 9],
	"alternation": [20, 8, 10, 15],
}
const BOSS_FROM: int = 40
const BOSS_EVERY: int = 40
const BRANCH_HARD: int = 8
const BRANCH_MEDIUM: int = 4
## Largest random boost of a tier's lag (as a share of it) when picking the
## next level; a tier that is not behind its curve gets none.
const JITTER: float = 0.6

## Weight of each tier along the main path after the first easy levels:
## [progress, weight] points, linear in between.
const MAIN_CURVES: Dictionary = {
	"easy": [[0.0, 0.45], [0.35, 0.12], [1.0, 0.1]],
	"medium": [[0.0, 0.55], [0.35, 0.55], [0.9, 0.3], [1.0, 0.15]],
	"hard": [[0.0, 0.0], [0.1, 0.0], [0.35, 0.33], [0.9, 0.6], [1.0, 0.75]],
}
const BRANCH_CURVES: Dictionary = {
	"medium": [[0.0, 0.1], [1.0, 0.1]],
	"hard": [[0.0, 0.4], [1.0, 0.1]],
	"expert": [[0.0, 0.5], [1.0, 0.8]],
}


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	var errors: Array[String] = []
	var path: Dictionary = build(Difficulty.LEVELS_DIR, errors)
	if not errors.is_empty():
		for error: String in errors:
			printerr(error)
		return false
	var file_path: String = "%s/%s" % [Difficulty.LEVELS_DIR, LevelCatalog.PATH_FILE]
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	file.store_string(to_json(path))
	file.close()
	LevelCatalog.clear_cache()
	var check: Array[String] = LevelValidator.validate_path(Difficulty.LEVELS_DIR)
	for error: String in check:
		printerr("  - %s" % error)
	print("main %d levels, branch %d levels after main %d: %s" % [path[LevelCatalog.MAIN].size(),
			path[LevelCatalog.BRANCH].size(), path["branch_after"], file_path])
	print(describe(path, Difficulty.LEVELS_DIR))
	return check.is_empty()


## The path for the levels under `levels_dir`: {branch_after, main, branch},
## each track a list of {file, id}. Problems go to `errors`.
static func build(levels_dir: String, errors: Array[String]) -> Dictionary:
	# Classic levels per tier and the mechanic levels, each list easiest first.
	var pools: Dictionary = {}
	for tier: String in Difficulty.ORDER:
		pools[tier] = _read_folder(levels_dir, tier, errors)
	var mechanics: Array[Dictionary] = _read_folder(levels_dir, Difficulty.MECHANICS, errors)
	if not errors.is_empty():
		return {}
	var first: Array[Dictionary] = []
	for i: int in mini(FIRST_EASY, pools["easy"].size()):
		first.append(pools["easy"].pop_front())
	# The branch takes the hardest medium and hard levels; the main path keeps the rest.
	var branch_pools: Dictionary = {
		"medium": _take_last(pools["medium"], BRANCH_MEDIUM),
		"hard": _take_last(pools["hard"], BRANCH_HARD),
		"expert": pools["expert"],
	}
	var main_pools: Dictionary = {"easy": pools["easy"], "medium": pools["medium"], "hard": pools["hard"]}
	var main_size: int = first.size() + mechanics.size() + _total(main_pools)
	if main_size < BRANCH_AFTER:
		errors.append("the main path has %d levels, the branch needs %d" % [main_size, BRANCH_AFTER])
		return {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED
	var pinned: Dictionary = _pin_mechanics(mechanics, main_size, errors)
	if not errors.is_empty():
		return {}
	var main: Array[Dictionary] = first.duplicate()
	main.append_array(_mix(main_pools, MAIN_CURVES, main_size - first.size(), pinned, first.size(), rng))
	var branch: Array[Dictionary] = []
	if not (branch_pools["hard"] as Array).is_empty():
		branch.append((branch_pools["hard"] as Array).pop_front())
	branch.append_array(_mix(branch_pools, BRANCH_CURVES, _total(branch_pools), {}, 0, rng))
	return {"branch_after": BRANCH_AFTER, LevelCatalog.MAIN: _entries(main), LevelCatalog.BRANCH: _entries(branch)}


## Fixed main path slots for the mechanic levels (1-based position -> level):
## the SPREADS chapters along the whole road, the bosses every BOSS_EVERY
## levels, the rest evenly from MECHANICS_FROM. Every group is easiest first.
static func _pin_mechanics(mechanics: Array[Dictionary], main_size: int, errors: Array[String]) -> Dictionary:
	var groups: Dictionary = {}
	for entry: Dictionary in mechanics:
		var mechanic: String = (entry["level"] as Level).mechanic()
		if not groups.has(mechanic):
			groups[mechanic] = [] as Array[Dictionary]
		(groups[mechanic] as Array).append(entry)
	var pinned: Dictionary = {}
	var bosses: Array = groups.get(Level.GREAT_EXCHANGE, [])
	groups.erase(Level.GREAT_EXCHANGE)
	var seed_offset: int = 1
	for mechanic: String in SPREADS:
		var entries: Array = groups.get(mechanic, [])
		groups.erase(mechanic)
		var spread: Array = SPREADS[mechanic]
		var first: int = spread[0]
		var gaps: Array[int] = _spread_gaps(entries.size(), main_size - spread[1] - first, spread[2], spread[3],
				SEED + seed_offset, errors)
		seed_offset += 1
		if not errors.is_empty():
			errors.append("in the %s chapter" % mechanic)
			return {}
		var position: int = first
		for i: int in entries.size():
			# The next gap counts from where this level really landed, so a clash
			# never squeezes two levels of a chapter closer than its smallest gap.
			position = _pin(pinned, position, entries[i])
			if i < gaps.size():
				position += gaps[i]
		# The bosses come right after the first chapter (whose gaps are the
		# tightest), so they keep their exact slots and the others make room.
		if seed_offset == 2:
			for i: int in bosses.size():
				_pin(pinned, BOSS_FROM + i * BOSS_EVERY, bosses[i])
	var others: Array[Dictionary] = []
	for mechanic: String in groups:
		others.append_array(groups[mechanic])
	others.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var moves_a: int = (a["level"] as Level).min_moves
		var moves_b: int = (b["level"] as Level).min_moves
		return moves_a < moves_b if moves_a != moves_b else a["id"] < b["id"])
	var span: float = float(main_size - MECHANICS_FROM) / maxf(others.size(), 1.0)
	for i: int in others.size():
		_pin(pinned, MECHANICS_FROM + roundi((i + 0.5) * span), others[i])
	for position: int in pinned:
		if position > main_size:
			errors.append("%s does not fit on a main path of %d levels" % [pinned[position]["file"], main_size])
	return pinned


## Puts `entry` at `position`, or at the nearest free slot (after first, then
## before, one step further each time), so a clash moves it as little as possible.
## Returns the slot it got.
static func _pin(pinned: Dictionary, position: int, entry: Dictionary) -> int:
	var step: int = 0
	while true:
		for slot: int in [position + step, position - step]:
			if slot > FIRST_EASY and not pinned.has(slot):
				pinned[slot] = entry
				return slot
		step += 1
	return position


## `count - 1` gaps between `gap_min` and `gap_max` that add up to `span`: every
## gap starts at the minimum and the rest is handed out one level at a time to
## random gaps (seeded).
static func _spread_gaps(count: int, span: int, gap_min: int, gap_max: int, seed_value: int,
		errors: Array[String]) -> Array[int]:
	var gaps: Array[int] = []
	if count < 2:
		return gaps
	for i: int in count - 1:
		gaps.append(gap_min)
	var rest: int = span - gap_min * (count - 1)
	if rest < 0 or rest > (gap_max - gap_min) * (count - 1):
		errors.append("%d levels do not fit %d-%d levels apart in a stretch of %d" % [count, gap_min, gap_max, span])
		return gaps
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	while rest > 0:
		var i: int = rng.randi_range(0, gaps.size() - 1)
		if gaps[i] < gap_max:
			gaps[i] += 1
			rest -= 1
	return gaps

## `count` levels from `pools`, following `curves`. `pinned` maps 1-based track
## positions (counted from the start of the whole track; `offset` positions
## are already filled) to a fixed level.
static func _mix(pools: Dictionary, curves: Dictionary, count: int, pinned: Dictionary, offset: int,
		rng: RandomNumberGenerator) -> Array[Dictionary]:
	var free_slots: int = count
	for position: int in pinned:
		if position > offset and position <= offset + count:
			free_slots -= 1
	# Each tier's target share up to slot k follows its curve, scaled so that the
	# whole pool is used by the last slot.
	var totals: Dictionary = {}
	for tier: String in pools:
		var total: float = 0.0
		for k: int in free_slots:
			total += _weight(curves[tier], _progress(k, free_slots))
		totals[tier] = total
	var placed: Dictionary = {}
	var running: Dictionary = {}
	for tier: String in pools:
		placed[tier] = 0
		running[tier] = 0.0
	var result: Array[Dictionary] = []
	var slot: int = 0
	for position: int in range(offset + 1, offset + count + 1):
		if pinned.has(position):
			result.append(pinned[position])
			continue
		# A tier whose curve is at zero here (hard right after the start) is only
		# a last resort, even when the others are ahead of their targets.
		var best_tier: String = ""
		var best_lag: float = -INF
		var fallback_tier: String = ""
		var fallback_lag: float = -INF
		for tier: String in pools:
			var weight: float = _weight(curves[tier], _progress(slot, free_slots))
			running[tier] += weight
			if (pools[tier] as Array).is_empty():
				continue
			var target: float = running[tier] / totals[tier] * (placed[tier] + (pools[tier] as Array).size()) if totals[tier] > 0.0 else 0.0
			var lag: float = target - placed[tier]
			lag *= 1.0 + rng.randf() * JITTER if lag > 0.0 else 1.0
			if weight > 0.0 and lag > best_lag:
				best_lag = lag
				best_tier = tier
			if lag > fallback_lag:
				fallback_lag = lag
				fallback_tier = tier
		if best_tier.is_empty():
			best_tier = fallback_tier
		result.append((pools[best_tier] as Array).pop_front())
		placed[best_tier] += 1
		slot += 1
	return result


static func _progress(slot: int, slots: int) -> float:
	return (slot + 0.5) / maxf(slots, 1.0)


## Linear interpolation over [progress, weight] points.
static func _weight(curve: Array, progress: float) -> float:
	for i: int in range(1, curve.size()):
		if progress <= curve[i][0]:
			var span: float = curve[i][0] - curve[i - 1][0]
			var t: float = (progress - curve[i - 1][0]) / span if span > 0.0 else 1.0
			return lerpf(curve[i - 1][1], curve[i][1], t)
	return curve[-1][1]


## Every level in `levels_dir/folder`, easiest first: [{file, id, level}].
static func _read_folder(levels_dir: String, folder: String, errors: Array[String]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var dir_path: String = "%s/%s" % [levels_dir, folder]
	if not DirAccess.dir_exists_absolute(dir_path):
		return entries
	for file_name: String in DirAccess.get_files_at(dir_path):
		if not file_name.ends_with(".json"):
			continue
		var level_errors: Array[String] = []
		var level: Level = Level.load_file("%s/%s" % [dir_path, file_name], level_errors)
		if level == null:
			errors.append("%s/%s: %s" % [folder, file_name, "; ".join(level_errors)])
			continue
		entries.append({"file": "%s/%s" % [folder, file_name], "id": level.id, "level": level})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var moves_a: int = (a["level"] as Level).min_moves
		var moves_b: int = (b["level"] as Level).min_moves
		return moves_a < moves_b if moves_a != moves_b else a["id"] < b["id"])
	return entries


static func _take_last(pool: Array, count: int) -> Array[Dictionary]:
	var taken: Array[Dictionary] = []
	for i: int in mini(count, pool.size()):
		taken.push_front(pool.pop_back())
	return taken


static func _total(pools: Dictionary) -> int:
	var total: int = 0
	for tier: String in pools:
		total += (pools[tier] as Array).size()
	return total


static func _entries(levels: Array[Dictionary]) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in levels:
		entries.append({"file": entry["file"], "id": entry["id"]})
	return entries


## One entry per line, so the file stays readable and diffs well.
static func to_json(path: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append("{\n  \"branch_after\": %d" % path["branch_after"])
	for track: String in LevelCatalog.TRACKS:
		var lines: PackedStringArray = PackedStringArray()
		for entry: Dictionary in path[track]:
			lines.append("    {\"file\": %s, \"id\": %d}" % [JSON.stringify(entry["file"]), entry["id"]])
		parts.append("  %s: [\n%s\n  ]" % [JSON.stringify(track), ",\n".join(lines)])
	return ",\n".join(parts) + "\n}\n"


## The tiers along each track in blocks of ten (E/M/H/X, mechanics in lower case).
static func describe(path: Dictionary, levels_dir: String) -> String:
	var letters: Dictionary = {"easy": "E", "medium": "M", "hard": "H", "expert": "X"}
	var lines: PackedStringArray = PackedStringArray()
	for track: String in LevelCatalog.TRACKS:
		var text: String = ""
		var counts: Dictionary = {}
		var entries: Array = path[track]
		for i: int in entries.size():
			var errors: Array[String] = []
			var level: Level = Level.load_file("%s/%s" % [levels_dir, entries[i]["file"]], errors)
			var letter: String = letters[level.difficulty]
			counts[level.difficulty] = counts.get(level.difficulty, 0) + 1
			text += letter if level.mechanic() == Level.CLASSIC else letter.to_lower()
			if i % 10 == 9:
				text += " "
		lines.append("%s %s\n  %s" % [track, str(counts), text])
	return "\n".join(lines)
