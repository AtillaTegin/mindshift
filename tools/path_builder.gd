class_name PathBuilder
extends SceneTree
## Lays every level out on the level path (level structure addenda v3 and v4)
## and writes data/levels/path.json (format: LevelCatalog):
##   godot --headless --path . --script res://tools/path_builder.gd
## Run it after the level generator or the mechanic level builder.
##
## Main path (v4, user decisions 2026-10-13):
## - The first FIRST_EASY levels are the 3-disk easy ones (the two tutorial
##   levels first). Easy levels are for learning only: the 4-disk ones lead
##   into medium early on, and after EASY_UNTIL no easy level comes at all
##   (classic or mechanic).
## - Which slots hold a mechanic level: none before the first chapter; up to
##   EASY_UNTIL just enough for every easy mechanic level (the chapters' first,
##   learning levels); from MIX_FROM to MIX_UNTIL classic and mechanic levels
##   take turns about 1:1 (one mechanic slot drawn in every stratum of about
##   two slots, so neither strictly alternating nor blocks); after that the
##   rest thin out evenly to the end of the road.
## - Chapters (CHAPTER_STARTS) put their first level at a fixed slot; each
##   mechanic slot after that takes the chapter that lags its own even spread
##   the most, so every chapter runs, easiest first, to the end of the road.
##   The great exchange is a chapter like the others since its v2 addendum
##   (its old rare bosses are gone); it starts at the first boss's slot.
## - Classic slots mix the tiers by weight curves over the progress: easy only
##   at the start, medium leads, then medium and hard mixed with hard growing.
##   Each step takes the tier that lags its curve the most, with a little seeded
##   jitter. Inside a tier levels always come easiest first.
## Each mechanic level counts as a level of its own tier.
## Branch ("island", shown once main level BRANCH_AFTER is completed): every
## expert level plus the hardest BRANCH_HARD hard and BRANCH_MEDIUM medium
## levels as breathers, opening with a hard one.
## Exits with code 0 only when the path was written and validates.

const SEED: int = 20261011
const FIRST_EASY: int = 4
const BRANCH_AFTER: int = 50
## No easy level after this main path position (v4 section 1).
const EASY_UNTIL: int = 50
## First slot of each chapter (user requests 2026-10-12 and 2026-10-13).
const CHAPTER_STARTS: Dictionary = {"covered_pegs": 12, "adjacent_pegs": 17, "alternation": 20, "color_swap": 40}
## The about 1:1 mix of classic and mechanic levels (v4 section 3).
const MIX_FROM: int = 51
const MIX_UNTIL: int = 200
const MIX_SHARE: float = 0.5
const BRANCH_HARD: int = 8
const BRANCH_MEDIUM: int = 4
## Largest random boost of a tier's lag (as a share of it) when picking the
## next level; a tier that is not behind its curve gets none.
const JITTER: float = 0.6

## Weight of each tier over the classic slots after the first easy levels:
## [progress, weight] points, linear in between.
const MAIN_CURVES: Dictionary = {
	"easy": [[0.0, 0.7], [0.1, 0.35], [0.16, 0.0], [1.0, 0.0]],
	"medium": [[0.0, 0.3], [0.15, 0.6], [0.45, 0.5], [0.8, 0.3], [1.0, 0.2]],
	"hard": [[0.0, 0.0], [0.12, 0.0], [0.3, 0.25], [0.6, 0.5], [1.0, 0.8]],
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
		pools[tier] = read_folder(levels_dir, tier, errors)
	var mechanics: Array[Dictionary] = read_folder(levels_dir, Difficulty.MECHANICS, errors)
	if not errors.is_empty():
		return {}
	return build_from(pools, mechanics, errors)


## The path for these classic pools (tier -> entries, easiest first) and
## mechanic entries ({file, id, level}); `pools` is used up.
static func build_from(pools: Dictionary, mechanics: Array[Dictionary], errors: Array[String]) -> Dictionary:
	# The small easy levels open the road (the first ones are the tutorial).
	var first: Array[Dictionary] = []
	var small_disks: int = Difficulty.get_tier("easy").get("small_disks", 0)
	for entry: Dictionary in (pools["easy"] as Array).duplicate():
		if first.size() < FIRST_EASY and (entry["level"] as Level).get_disk_count() == small_disks:
			first.append(entry)
			(pools["easy"] as Array).erase(entry)
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
	var pinned: Dictionary = _place_mechanics(mechanics, main_size, rng, errors)
	if not errors.is_empty():
		return {}
	var main: Array[Dictionary] = first.duplicate()
	main.append_array(_mix(main_pools, MAIN_CURVES, main_size - first.size(), pinned, first.size(), rng))
	var branch: Array[Dictionary] = []
	if not (branch_pools["hard"] as Array).is_empty():
		branch.append((branch_pools["hard"] as Array).pop_front())
	branch.append_array(_mix(branch_pools, BRANCH_CURVES, _total(branch_pools), {}, 0, rng))
	return {"branch_after": BRANCH_AFTER, LevelCatalog.MAIN: _entries(main), LevelCatalog.BRANCH: _entries(branch)}


## Main path slots of the mechanic levels (1-based position -> level), see the
## class comment: fixed slots for each chapter's first level, then the other
## mechanic slots part by part, then the chapters onto them.
static func _place_mechanics(mechanics: Array[Dictionary], main_size: int, rng: RandomNumberGenerator,
		errors: Array[String]) -> Dictionary:
	var chapters: Dictionary = {}
	for entry: Dictionary in mechanics:
		var mechanic: String = (entry["level"] as Level).mechanic()
		if CHAPTER_STARTS.has(mechanic):
			if not chapters.has(mechanic):
				chapters[mechanic] = [] as Array[Dictionary]
			(chapters[mechanic] as Array).append(entry)
		else:
			errors.append("%s: the %s chapter has no slot in CHAPTER_STARTS" % [entry["file"], mechanic])
	if not errors.is_empty():
		return {}
	# Every chapter easiest first, whatever order they came in.
	var by_length: Callable = func(a: Dictionary, b: Dictionary) -> bool:
		var moves_a: int = (a["level"] as Level).min_moves
		var moves_b: int = (b["level"] as Level).min_moves
		return moves_a < moves_b if moves_a != moves_b else a["id"] < b["id"]
	for mechanic: String in chapters:
		(chapters[mechanic] as Array).sort_custom(by_length)
	var pinned: Dictionary = {}
	var starts: Dictionary = {}
	for mechanic: String in chapters:
		var start: int = CHAPTER_STARTS[mechanic]
		pinned[start] = (chapters[mechanic] as Array).pop_front()
		starts[mechanic] = start
	var easy_left: int = 0
	for mechanic: String in chapters:
		for entry: Dictionary in chapters[mechanic]:
			easy_left += 1 if (entry["level"] as Level).difficulty == "easy" else 0
	# Mechanic slots of each part of the road, counting the fixed ones in it.
	var first_chapter: int = main_size
	for mechanic: String in starts:
		first_chapter = mini(first_chapter, starts[mechanic])
	var early: int = _fixed_in(pinned, first_chapter, EASY_UNTIL) + easy_left
	var mixed: int = roundi(MIX_SHARE * (MIX_UNTIL - MIX_FROM + 1))
	var parts: Array[Array] = [[first_chapter, EASY_UNTIL, early], [MIX_FROM, MIX_UNTIL, mixed],
			[MIX_UNTIL + 1, main_size, mechanics.size() - early - mixed]]
	var slots: Array[int] = []
	for part: Array in parts:
		var picked: Array[int] = _draw_slots(pinned, part[0], part[1], part[2], rng)
		if picked.size() + _fixed_in(pinned, part[0], part[1]) != part[2]:
			errors.append("main %d-%d cannot hold %d mechanic levels" % part)
			return {}
		slots.append_array(picked)
	slots.sort()
	# Up to EASY_UNTIL only the chapters' easy (learning) levels; later every
	# chapter spreads its other levels evenly over the remaining slots.
	var placed: Dictionary = {}
	var late_slots: int = 0
	for slot: int in slots:
		late_slots += 1 if slot > EASY_UNTIL else 0
	var remaining: Dictionary = {}
	var late_index: int = 0
	for slot: int in slots:
		var best: String = ""
		var best_lag: float = -INF
		for mechanic: String in chapters:
			var entries: Array = chapters[mechanic]
			if entries.is_empty() or starts[mechanic] > slot:
				continue
			var lag: float
			if slot <= EASY_UNTIL:
				if (entries[0]["level"] as Level).difficulty != "easy":
					continue
				var easy_total: int = placed.get(mechanic, 0) + _easy_count(entries)
				lag = easy_total * float(slot - starts[mechanic] + 1) / float(EASY_UNTIL - starts[mechanic] + 1) \
						- placed.get(mechanic, 0)
			else:
				if not remaining.has(mechanic):
					remaining[mechanic] = entries.size()
				lag = remaining[mechanic] * float(late_index + 1) / float(late_slots) \
						- (remaining[mechanic] - entries.size())
			if lag > best_lag:
				best_lag = lag
				best = mechanic
		if best.is_empty():
			var left: Dictionary = {}
			for mechanic: String in chapters:
				var entries: Array = chapters[mechanic]
				left[mechanic] = "%d, next %s" % [entries.size(), (entries[0]["level"] as Level).difficulty if not entries.is_empty() else "-"]
			errors.append("no chapter level fits main %d (left: %s)" % [slot, str(left)])
			return {}
		pinned[slot] = (chapters[best] as Array).pop_front()
		placed[best] = placed.get(best, 0) + 1
		late_index += 1 if slot > EASY_UNTIL else 0
	for mechanic: String in chapters:
		if not (chapters[mechanic] as Array).is_empty():
			errors.append("%d %s levels found no slot" % [(chapters[mechanic] as Array).size(), mechanic])
	for position: int in pinned:
		if position > main_size:
			errors.append("%s does not fit on a main path of %d levels" % [pinned[position]["file"], main_size])
		elif position > EASY_UNTIL and (pinned[position]["level"] as Level).difficulty == "easy":
			errors.append("easy level %s landed at main %d" % [pinned[position]["file"], position])
	return pinned


## `count` mechanic slots in main `from`-`to` beyond the fixed ones there: the
## free positions are cut into that many equal strata and one slot is drawn in
## each (seeded), so they spread evenly without a strict rhythm.
static func _draw_slots(pinned: Dictionary, from: int, to: int, count: int, rng: RandomNumberGenerator) -> Array[int]:
	var free: Array[int] = []
	for position: int in range(from, to + 1):
		if not pinned.has(position):
			free.append(position)
	var wanted: int = count - _fixed_in(pinned, from, to)
	var picked: Array[int] = []
	if wanted <= 0 or wanted > free.size():
		return picked
	for i: int in wanted:
		var low: int = i * free.size() / wanted
		var high: int = (i + 1) * free.size() / wanted - 1
		picked.append(free[rng.randi_range(low, high)])
	return picked


static func _fixed_in(pinned: Dictionary, from: int, to: int) -> int:
	var count: int = 0
	for position: int in pinned:
		count += 1 if position >= from and position <= to else 0
	return count


static func _easy_count(entries: Array) -> int:
	var count: int = 0
	for entry: Dictionary in entries:
		count += 1 if (entry["level"] as Level).difficulty == "easy" else 0
	return count

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
static func read_folder(levels_dir: String, folder: String, errors: Array[String]) -> Array[Dictionary]:
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
