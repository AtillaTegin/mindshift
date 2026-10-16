class_name RoadBuilder
extends SceneTree
## Builds the level road of the chapter system (ChapterPlan) and writes every
## level file and data/levels/path.json (format: LevelCatalog):
##   godot --headless --path . --script res://tools/road_builder.gd
##   godot --headless --path . --script res://tools/road_builder.gd -- --worlds=1-2
## Without --worlds it builds BUILT_WORLDS. A run replaces every level file
## under data/levels/, then validates the whole set (LevelValidator).
##
## How a chapter is laid out (chapter plan sections 3 and 7):
## - The classic chapter: classic levels by CLASSIC_TABLE; the two tutorial
##   levels open the road unchanged (TUTORIAL_LEVELS).
## - A mode chapter opens with its mode (its tutorial level), then one classic
##   level for every `ratio` mode levels, drawn one per stratum so they never
##   bunch up or keep a strict rhythm. In the second half one level in every
##   REPEAT_EVERY is an earlier chapter's mode, those taking turns.
## - A combination chapter opens with its first combination; the others join
##   one after another, evenly spread over its first half. Then its single
##   modes and classic levels in their shares, drawn like the classic ones.
## - Mode, combination and repeat levels take the band of their slot's share
##   of the chapter; classic levels after main 100 take turns between
##   medium-hard and hard.
## - Every level of one stream (classic, a mode or a combination) and one band
##   is drawn together, spread over the band's move range, and handed to the
##   slots easiest first, so each stream climbs through its chapter.
## - Islands: the classic chapter's island keeps its old mix (expert levels,
##   a few hard and medium ones, opening with a hard one); each mode chapter's
##   island has ChapterPlan.ISLAND_LEVELS expert levels of its mode.
## Exits with code 0 only when every level was built and the set validates.

const BASE_SEED: int = 20261015
## Worlds whose chapters are built (chapter plan's order: world 1-2 first).
const BUILT_WORLDS: Array[int] = [1, 2]
## Draws per level before its board gives way to the next recipe board, and
## fitting draws compared for the move count the group has least
## (draw_group()); a draw with a count not seen yet wins at once.
const ATTEMPTS_PER_LEVEL: int = 600
const CANDIDATES: int = 3
## Waves (chapter waves v1): the closing mixed wave's length, how many levels
## of a new sub-element alone follow its intro, how far a level's window
## reaches around its target.
const MIXED_WAVE: int = 10
const DEV_LEVELS: int = 3
const WINDOW: int = 2
## Lowest move count a mode's waves start from where the band's (7) is too
## low: an unequal capacity of at least two per peg rarely matters below 9
## (measured 2026-10-16).
const MODE_FLOOR: Dictionary = {"peg_capacity": 9}
## The tutorial levels (addendum 6B) open the road exactly as they always did.
const TUTORIAL_LEVELS: Array[Dictionary] = [
	{"start": [[1], [2], [3]], "goal": [[3], [1], [2]]},
	{"start": [[2], [3], [1]], "goal": [[], [], [3, 2, 1]]},
]
const CLASSIC: String = "classic"
## File name stem of each mode's levels (data/levels/mechanics/<stem>_NNN.json);
## a combination's files join its modes' stems.
const MODE_FILES: Dictionary = {"peg_capacity": "capacity", "covered_pegs": "fog", "foundation": "foundation",
	"adjacent_pegs": "caravan", "stripes": "stripes", "cyclic": "cyclic", "alternation": "rings", "balance": "balance",
	"color_swap": "swap", "trail": "trail", "chain": "chain", "mirror": "mirror", "linked_pegs": "linked",
	"magnet": "magnet"}
## Mechanic level ids: each mode, then each combination of the whitelist,
## owns a block of ID_BLOCK ids from Difficulty.MECHANIC_FIRST_ID.
const ID_BLOCK: int = 1000
const COMBO_FIRST_BLOCK: int = 20

## Boards per stream and band, taken in turn (LevelForge's recipe boards).
## Sizes measured 2026-10-15: unequal capacity on 5 pegs searches slowly and
## stays short, so 5 pegs only with 6 disks; 4 pegs / 9 disks takes up to
## 4 s, so its experts stop at 8 disks. Karakuri on every peg only works on
## 3 pegs, and 4 pegs / 10 disks with three boxes is too rare and slow to
## draw. The foundation's experts are fast on 3 pegs (6-7 disks).
const RECIPES: Dictionary = {
	CLASSIC: {
		"easy": [{"pegs": 3, "disks": 3}],
		"easy_medium": [{"pegs": 3, "disks": 4}, {"pegs": 3, "disks": 4}, {"pegs": 4, "disks": 4}],
		"medium": [{"pegs": 3, "disks": 5}, {"pegs": 4, "disks": 6}, {"pegs": 4, "disks": 5}],
		"medium_hard": [{"pegs": 3, "disks": 6}, {"pegs": 4, "disks": 7}, {"pegs": 4, "disks": 8}],
		# 7 disks on 3 pegs now and then: the "big test" (section 3.2).
		"hard": [{"pegs": 4, "disks": 8}, {"pegs": 3, "disks": 6}, {"pegs": 4, "disks": 9}, {"pegs": 4, "disks": 8},
			{"pegs": 3, "disks": 6}, {"pegs": 4, "disks": 9}, {"pegs": 3, "disks": 7}],
		"expert": [{"pegs": 4, "disks": 9}, {"pegs": 4, "disks": 10}, {"pegs": 3, "disks": 6}],
	},
	"peg_capacity": {
		"easy_medium": [{"pegs": 4, "disks": 4, "slack": 1}, {"pegs": 4, "disks": 5, "slack": 1},
			{"pegs": 4, "disks": 4, "slack": 0}, {"pegs": 5, "disks": 6, "slack": 1}],
		"medium": [{"pegs": 4, "disks": 5, "slack": 1}, {"pegs": 4, "disks": 6, "slack": 1},
			{"pegs": 5, "disks": 6, "slack": 1}, {"pegs": 4, "disks": 6, "slack": 2}],
		"medium_hard": [{"pegs": 4, "disks": 6, "slack": 1}, {"pegs": 4, "disks": 7, "slack": 1},
			{"pegs": 4, "disks": 7, "slack": 2}],
		"hard": [{"pegs": 4, "disks": 7, "slack": 1}, {"pegs": 4, "disks": 8, "slack": 1}],
		"expert": [{"pegs": 4, "disks": 8, "slack": 1}],
	},
	"covered_pegs": {
		"easy_medium": [{"pegs": 3, "disks": 4, "covered": 1}, {"pegs": 4, "disks": 5, "covered": 1}],
		"medium": [{"pegs": 3, "disks": 5, "covered": 1}, {"pegs": 4, "disks": 6, "covered": 2},
			{"pegs": 4, "disks": 6, "covered": 1}],
		"medium_hard": [{"pegs": 4, "disks": 7, "covered": 2}, {"pegs": 3, "disks": 6, "covered": 0},
			{"pegs": 4, "disks": 8, "covered": 2}],
		"hard": [{"pegs": 4, "disks": 8, "covered": 3}, {"pegs": 3, "disks": 6, "covered": 2},
			{"pegs": 4, "disks": 8, "covered": 2}],
		# 3 pegs only: a sealed box's memory on 4 pegs / 9 disks made an off-path
		# hint take ~5 s on a desktop (measured 2026-10-16).
		"expert": [{"pegs": 3, "disks": 6, "covered": 2}, {"pegs": 3, "disks": 7, "covered": 2}],
	},
	"foundation": {
		"easy_medium": [{"pegs": 3, "disks": 4, "locked": 1, "keys": 2}, {"pegs": 4, "disks": 5, "locked": 1, "keys": 2},
			{"pegs": 3, "disks": 4, "locked": 1, "keys": 1}],
		"medium": [{"pegs": 3, "disks": 4, "locked": 1, "keys": 3}, {"pegs": 4, "disks": 5, "locked": 1, "keys": 2},
			{"pegs": 4, "disks": 6, "locked": 2, "keys": 3}],
		"medium_hard": [{"pegs": 3, "disks": 5, "locked": 1, "keys": 2}, {"pegs": 4, "disks": 6, "locked": 2, "keys": 3},
			{"pegs": 4, "disks": 7, "locked": 2, "keys": 3}],
		"hard": [{"pegs": 4, "disks": 7, "locked": 2, "keys": 3}, {"pegs": 4, "disks": 8, "locked": 2, "keys": 3},
			{"pegs": 3, "disks": 7, "locked": 2, "keys": 3}],
		"expert": [{"pegs": 3, "disks": 6, "locked": 2, "keys": 2}, {"pegs": 3, "disks": 7, "locked": 2, "keys": 3},
			{"pegs": 3, "disks": 6, "locked": 1, "keys": 3}],
	},
	"peg_capacity+covered_pegs": {
		"easy_medium": [{"pegs": 4, "disks": 5, "slack": 1, "covered": 1}],
		"medium": [{"pegs": 4, "disks": 6, "slack": 1, "covered": 1}, {"pegs": 4, "disks": 5, "slack": 1, "covered": 2}],
		"medium_hard": [{"pegs": 4, "disks": 6, "slack": 1, "covered": 2}, {"pegs": 4, "disks": 7, "slack": 1, "covered": 2}],
		"hard": [{"pegs": 4, "disks": 7, "slack": 1, "covered": 2}, {"pegs": 4, "disks": 8, "slack": 1, "covered": 2}],
		"expert": [{"pegs": 4, "disks": 8, "slack": 1, "covered": 2}, {"pegs": 4, "disks": 8, "slack": 2, "covered": 2}],
	},
	"peg_capacity+foundation": {
		"easy_medium": [{"pegs": 4, "disks": 5, "slack": 1, "locked": 1, "keys": 2}],
		"medium": [{"pegs": 4, "disks": 5, "slack": 1, "locked": 1, "keys": 2},
			{"pegs": 4, "disks": 6, "slack": 1, "locked": 2, "keys": 2}],
		"medium_hard": [{"pegs": 4, "disks": 6, "slack": 1, "locked": 2, "keys": 2},
			{"pegs": 4, "disks": 7, "slack": 1, "locked": 2, "keys": 3}],
		"hard": [{"pegs": 4, "disks": 7, "slack": 1, "locked": 2, "keys": 3}],
		"expert": [{"pegs": 4, "disks": 8, "slack": 1, "locked": 2, "keys": 3},
			{"pegs": 4, "disks": 7, "slack": 1, "locked": 2, "keys": 3}],
	},
	"covered_pegs+foundation": {
		"easy_medium": [{"pegs": 3, "disks": 4, "locked": 1, "keys": 2, "covered": 1},
			{"pegs": 4, "disks": 5, "locked": 1, "keys": 2, "covered": 1}],
		"medium": [{"pegs": 4, "disks": 6, "locked": 2, "keys": 3, "covered": 2},
			{"pegs": 4, "disks": 5, "locked": 1, "keys": 2, "covered": 2}],
		"medium_hard": [{"pegs": 4, "disks": 7, "locked": 2, "keys": 3, "covered": 2},
			{"pegs": 3, "disks": 5, "locked": 1, "keys": 2, "covered": 1}],
		"hard": [{"pegs": 4, "disks": 8, "locked": 2, "keys": 3, "covered": 2},
			{"pegs": 4, "disks": 7, "locked": 2, "keys": 3, "covered": 3}],
		"expert": [{"pegs": 3, "disks": 6, "locked": 2, "keys": 2, "covered": 2},
			{"pegs": 3, "disks": 7, "locked": 2, "keys": 3, "covered": 2}],
	},
}


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	var worlds: Array[int] = BUILT_WORLDS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--worlds="):
			worlds = parse_worlds(arg.trim_prefix("--worlds="))
	var started: int = Time.get_ticks_msec()
	var errors: Array[String] = []
	var road: Dictionary = build(worlds, errors)
	if not errors.is_empty():
		for error: String in errors:
			printerr(error)
		return false
	write(road, Difficulty.LEVELS_DIR)
	LevelCatalog.clear_cache()
	var report: Dictionary = LevelValidator.validate_directory(Difficulty.LEVELS_DIR)
	var failures: Dictionary = report["failures"]
	for path: String in failures:
		printerr("FAIL %s: %s" % [path, "; ".join(failures[path])])
	print(describe(road))
	print("%d levels in %d s" % [report["files"], (Time.get_ticks_msec() - started) / 1000])
	return failures.is_empty()


## "1-2" or "1,3" -> [1, 2] / [1, 3].
static func parse_worlds(text: String) -> Array[int]:
	var worlds: Array[int] = []
	for part: String in text.split(","):
		if part.contains("-"):
			for world: int in range(part.get_slice("-", 0).to_int(), part.get_slice("-", 1).to_int() + 1):
				worlds.append(world)
		else:
			worlds.append(part.to_int())
	return worlds


## Every level of `worlds`' chapters: {main: [Level], islands: [{mode, after,
## levels: [Level]}], files: {Level id: file}}. Problems go to `errors`.
static func build(worlds: Array[int], errors: Array[String]) -> Dictionary:
	var plan: Dictionary = layout(worlds)
	var used: Dictionary = {}
	var main: Array = plan["main"]
	var tracks: Array = [main]
	for island: Dictionary in plan["islands"]:
		tracks.append(island["slots"])
	# Groups of one stream and band, in road order; each gets its levels at once.
	var groups: Dictionary = {}
	var order: Array[String] = []
	for track: Array in tracks:
		for slot: Dictionary in track:
			if slot.has("fixed") or slot.has("low"):
				continue
			var group: String = "%s/%s" % [stream_of(slot["modes"]), slot["band"]]
			# A band lifted to its world's floor is a group of its own.
			if ChapterPlan.band_range(slot["band"], slot["floor"])[0] != int(ChapterPlan.BANDS[slot["band"]][0]):
				group += "@%d" % slot["floor"]
			if not groups.has(group):
				groups[group] = []
				order.append(group)
			(groups[group] as Array).append(slot)
	# The tutorial levels first, so nothing else repeats them.
	for slot: Dictionary in main:
		if slot.has("fixed"):
			slot["draft"] = _tutorial_draft(slot["fixed"])
			used[slot["draft"]["key"]] = true
	# Wave levels (a window of their own each), in road order.
	for t: int in tracks.size():
		var started: int = Time.get_ticks_msec()
		var count: int = 0
		for i: int in (tracks[t] as Array).size():
			var slot: Dictionary = tracks[t][i]
			if not slot.has("low"):
				continue
			var draft: Dictionary = draw_one(slot, BASE_SEED + t * 10000 + i, used)
			# Too many sub-elements for the window: the later ones go, one by one
			# (the first is the one the wave teaches).
			while draft.is_empty() and (slot["variants"] as Array).size() > 1:
				var fewer: Array[String] = []
				fewer.assign((slot["variants"] as Array).slice(0, -1))
				print("  track %d slot %d: %s too much for %d-%d, now %s" % [t, i + 1, str(slot["variants"]), slot["low"],
						slot["high"], str(fewer)])
				slot["variants"] = fewer
				slot["extra"]["variants"] = fewer
				draft = draw_one(slot, BASE_SEED + t * 10000 + i, used)
			# A combination chapter's Böyük Sınaq tries its other combinations.
			for other: Array in slot.get("fallback_modes", []):
				if not draft.is_empty():
					break
				print("  track %d slot %d: no %s level with %d-%d moves, trying %s" % [t, i + 1, stream_of(slot["modes"]),
						slot["low"], slot["high"], stream_of(other)])
				slot["modes"].assign(other)
				draft = draw_one(slot, BASE_SEED + t * 10000 + i, used)
			if draft.is_empty():
				errors.append("track %d slot %d: no %s level %s with %d-%d moves" % [t, i + 1, stream_of(slot["modes"]),
						str(slot["variants"]), slot["low"], slot["high"]])
				continue
			used[draft["key"]] = true
			slot["draft"] = draft
			count += 1
		if count > 0:
			print("  track %d: %d wave levels in %.1f s" % [t, count, (Time.get_ticks_msec() - started) / 1000.0])
	for group: String in order:
		var slots: Array = groups[group]
		var first: Dictionary = slots[0]
		var started: int = Time.get_ticks_msec()
		var drafts: Array[Dictionary] = draw_group(first["modes"], first["band"], slots.size(),
				BASE_SEED + group.hash() % 100000, used, errors, first["floor"])
		print("  %s: %d levels in %.1f s" % [group, drafts.size(), (Time.get_ticks_msec() - started) / 1000.0])
		if drafts.size() < slots.size():
			errors.append("%s: only %d of %d levels found" % [group, drafts.size(), slots.size()])
			continue
		for i: int in slots.size():
			slots[i]["draft"] = drafts[i]
	if not errors.is_empty():
		return {}
	return _number(plan)


## The road's slots for `worlds`: {main: [slot], islands: [{mode, after,
## slots}]}. A slot: {modes, band} (modes empty for classic), "fixed" for a
## tutorial level.
static func layout(worlds: Array[int]) -> Dictionary:
	var main: Array[Dictionary] = []
	var islands: Array[Dictionary] = []
	for chapter: Dictionary in ChapterPlan.chapters_of(worlds):
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = BASE_SEED + int(chapter["first"])
		var first_new: int = main.size()
		var islands_before: int = islands.size()
		match chapter["kind"]:
			ChapterPlan.CLASSIC_CHAPTER:
				main.append_array(_classic_chapter(chapter))
				islands.append({"mode": Level.CLASSIC, "after": chapter["last"], "slots": _classic_island()})
			ChapterPlan.MODE_CHAPTER:
				main.append_array(_mode_chapter(chapter, rng))
				islands.append({"mode": chapter["mode"], "after": chapter["last"], "slots": _mode_island(chapter["mode"], rng)})
			ChapterPlan.COMBO_CHAPTER:
				main.append_array(_combo_chapter(chapter, rng))
		# Band slots learn their world's floor (wave slots have their windows).
		var slots: Array = main.slice(first_new)
		for island: Dictionary in islands.slice(islands_before):
			slots.append_array(island["slots"])
		for slot: Dictionary in slots:
			slot["floor"] = ChapterPlan.world_floor(chapter["world"])
	return {"main": main, "islands": islands}


static func _classic_chapter(chapter: Dictionary) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for position: int in range(int(chapter["first"]), int(chapter["last"]) + 1):
		var slot: Dictionary = {"modes": [], "band": ChapterPlan.classic_band(position)}
		if position <= TUTORIAL_LEVELS.size():
			slot["fixed"] = position - 1
		slots.append(slot)
	return slots


## Old island mix: CLASSIC_ISLAND levels, a hard one first, the breathers
## (hard and medium) spread evenly between the expert ones.
static func _classic_island() -> Array[Dictionary]:
	var counts: Dictionary = ChapterPlan.CLASSIC_ISLAND.duplicate()
	var total: int = 0
	for band: String in counts:
		total += counts[band]
	var slots: Array[Dictionary] = [{"modes": [], "band": "hard"}]
	counts["hard"] -= 1
	var placed: Dictionary = {}
	for i: int in range(1, total):
		var best: String = ""
		var best_lag: float = -INF
		for band: String in ["expert", "hard", "medium"]:
			var lag: float = counts[band] * float(i) / float(total - 1) - placed.get(band, 0)
			if placed.get(band, 0) < counts[band] and lag > best_lag:
				best_lag = lag
				best = band
		placed[best] = placed.get(best, 0) + 1
		slots.append({"modes": [], "band": best})
	return slots


## A mode chapter in waves (chapter waves v1): the mode's levels wave by wave
## (wave_items()), one classic level for every `ratio` of them right after a
## hard one, and in the second half one earlier chapter's mode in every
## REPEAT_EVERY levels (newest chapter first). Every mode and repeat level gets
## its own move window; classic levels keep their bands.
static func _mode_chapter(chapter: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var length: int = ChapterPlan.length_of(chapter)
	var first: int = chapter["first"]
	var classic_count: int = roundi(length / (float(chapter["ratio"]) + 1.0))
	var earlier: Array[String] = ChapterPlan.modes_before(first)
	var repeat_count: int = 0 if earlier.is_empty() else ceili((length - length / 2) / float(ChapterPlan.REPEAT_EVERY))
	var least: int = ChapterPlan.world_floor(chapter["world"])
	var items: Array[Dictionary] = wave_items(chapter["mode"], length - classic_count - repeat_count, rng, least)
	var last: int = items.size() - 1
	# Repeats spread over the second half of the mode levels (never after the last).
	var repeats: Dictionary = {}
	for r: int in repeat_count:
		var at: int = items.size() / 2 + int((last - items.size() / 2) * (r + 0.5) / repeat_count)
		var mode: String = earlier[earlier.size() - 1 - r % earlier.size()]
		repeats[at] = _repeat_item(mode, items[at], rng, least)
	# Classic levels right after a hard level (the end of a wave's climb), spaced evenly.
	var classics: Dictionary = {}
	var spacing: float = float(last) / classic_count
	var previous: int = -2
	for c: int in classic_count:
		var ideal: float = (c + 0.6) * spacing
		var best: int = -1
		for at: int in range(maxi(int(ideal - spacing * 0.5), previous + 2), mini(int(ideal + spacing * 0.5) + 1, last)):
			if best == -1 or float(items[at]["t"]) >= float(items[best]["t"]):
				best = at
		if best == -1:
			best = mini(previous + 2, last - 1)
		while classics.has(best):
			best += 1
		classics[best] = true
		previous = best
	var slots: Array[Dictionary] = []
	var classic_index: int = 0
	for at: int in items.size():
		slots.append(items[at])
		if repeats.has(at):
			slots.append(repeats[at])
		if classics.has(at):
			slots.append({"modes": [], "band": _classic_band(first + slots.size(), classic_index)})
			classic_index += 1
	return slots


## A chapter's `count` levels of `mode` in waves (ChapterPlan.WAVES): wave 1
## the base form, each later wave one new sub-element, then (if the mode has
## one) a mixed wave of MIXED_WAVE levels, and last the chapter's Böyük Sınaq
## (ChapterPlan.BIG_TEST moves, every sub-element that can share a level). Inside a
## wave: an intro with only the new sub-element on an easier board, a few
## levels of it alone, then mixed with the earlier ones, up to the wave's
## hardest. Each level: {modes, variants, extra (board settings), low, high,
## band, t (its place in its wave, 0-1)}. The windows climb in a sawtooth:
## each wave starts a little below where the last one ended. They start at the
## mode's floor or the world's (`least`, ChapterPlan.world_floor), and only
## the intros, exempt from the world's, may reach below it.
static func wave_items(mode: String, count: int, rng: RandomNumberGenerator, least: int = 0) -> Array[Dictionary]:
	var plan: Dictionary = ChapterPlan.WAVES.get(mode, {"waves": [ChapterPlan.BASE], "mixed": false})
	var waves: Array = plan["waves"]
	var mixed_size: int = MIXED_WAVE if plan["mixed"] else 0
	var body: int = count - 1 - mixed_size
	var sections: int = waves.size() + (1 if plan["mixed"] else 0)
	var mode_floor: int = MODE_FLOOR.get(mode, ChapterPlan.BANDS["easy_medium"][0])
	var floors: Array[int] = [maxi(mode_floor, least), maxi(mode_floor - 2, least), mode_floor]
	var items: Array[Dictionary] = []
	var taught: Array[String] = []
	for k: int in waves.size():
		var variant: String = waves[k]
		var size: int = body / waves.size() + (1 if k < body % waves.size() else 0)
		for j: int in size:
			var t: float = float(j) / maxf(size - 1, 1.0)
			var variants: Array[String] = []
			if variant != ChapterPlan.BASE:
				variants.append(variant)
				# Mixed with what came before once the new sub-element is known.
				if j > DEV_LEVELS:
					variants.append_array(_pick_variants(taught, 1 if j < size - 1 else 2, variants, rng))
			var extra: Dictionary = _wave_extra(mode, variants, t, rng)
			if variant == ChapterPlan.BASE and mode == ChapterPlan.COVERED:
				extra["covered"] = 1 if j < size / 2 else 2  # one box first, two by the wave's end
			var span: Array[int] = _wave_window(k, sections, t, j == 0, floors)
			items.append({"modes": [mode], "variants": variants, "extra": extra, "low": span[0], "high": span[1], "t": t,
					"wave": variant})
		if variant != ChapterPlan.BASE:
			taught.append(variant)
	for j: int in mixed_size:
		var t: float = float(j) / maxf(mixed_size - 1, 1.0)
		var variants: Array[String] = _pick_variants(taught, 2 + (1 if j >= mixed_size / 2 and taught.size() > 2 else 0), [], rng)
		var span: Array[int] = _wave_window(sections - 1, sections, t, false, floors)
		items.append({"modes": [mode], "variants": variants, "extra": _wave_extra(mode, variants, t, rng),
				"low": span[0], "high": span[1], "t": t, "wave": "mixed"})
	# The Böyük Sınaq: every sub-element that can share a level, in wave order.
	var all: Array[String] = []
	for variant: String in waves:
		if variant != ChapterPlan.BASE and _pick_variants([variant], 1, all, rng).size() == 1:
			all.append(variant)
	items.append({"modes": [mode], "variants": all, "extra": _wave_extra(mode, all, 1.0, rng),
			"low": ChapterPlan.BIG_TEST[0], "high": ChapterPlan.BIG_TEST[1], "t": 1.0, "wave": "big_test"})
	for item: Dictionary in items:
		item["band"] = band_of_moves((int(item["low"]) + int(item["high"])) / 2)
	return items


## Move window of a level at `t` (0-1) through wave `k` of `sections`, the
## waves climbing from floors[0] to the hard band's top, no window below
## floors[1]; an intro sits a step lower, on an easier board, down to the
## mode's own floor (floors[2]) less two.
static func _wave_window(k: int, sections: int, t: float, intro: bool, floors: Array[int]) -> Array[int]:
	var low: float = floors[0]
	var high: float = ChapterPlan.BANDS["hard"][1]
	var step: float = (high - low) / (sections + 0.5)
	var end: float = low + step * (k + 1)
	var begin: float = low if k == 0 else end - step * 1.5
	var target: int = roundi(begin + (end - begin) * t)
	if intro:
		return [maxi(floors[2] - 2, roundi(begin) - 4), maxi(roundi(begin), floors[2] + 1)]
	return [maxi(floors[1], target - WINDOW), mini(target + WINDOW, roundi(high))]


## Board settings a level's sub-elements need: boxes for the karakuri, how
## many locks a chain has.
static func _wave_extra(mode: String, variants: Array[String], t: float, rng: RandomNumberGenerator) -> Dictionary:
	var extra: Dictionary = {"variants": variants}
	if mode == ChapterPlan.COVERED:
		extra["covered"] = 1 if variants.has("count_board") or variants.has("sealed") or rng.randf() < 0.5 else 2
	if variants.has("chain_lock"):
		extra["stages"] = 3 if t >= 0.75 and variants.size() > 1 else 2
	return extra


## Up to `count` sub-elements from `pool` that do not clash with `with` or
## each other (ChapterPlan.CLASHES), drawn at random.
static func _pick_variants(pool: Array, count: int, with: Array, rng: RandomNumberGenerator) -> Array[String]:
	var picked: Array[String] = []
	for variant: String in LevelForge._shuffled(pool, rng):
		if picked.size() >= count or with.has(variant):
			continue
		var clash: bool = false
		for pair: Array in ChapterPlan.CLASHES:
			for other: String in picked + with:
				clash = clash or (pair.has(variant) and pair.has(other) and variant != other)
		if not clash:
			picked.append(variant)
	return picked


## An earlier chapter's mode coming back (section 3.3b) at the place of
## `item`: its window (never below the world's floor `least`: a repeat is no
## intro), with up to two of that mode's sub-elements.
static func _repeat_item(mode: String, item: Dictionary, rng: RandomNumberGenerator, least: int = 0) -> Dictionary:
	var pool: Array = []
	for variant: String in ChapterPlan.WAVES.get(mode, {}).get("waves", []):
		if variant != ChapterPlan.BASE:
			pool.append(variant)
	var variants: Array[String] = _pick_variants(pool, rng.randi_range(0, 2), [], rng)
	var low: int = maxi(item["low"], least)
	return {"modes": [mode], "variants": variants, "extra": _wave_extra(mode, variants, item["t"], rng),
			"low": low, "high": maxi(item["high"], low + WINDOW), "t": item["t"], "band": item["band"]}


## The island of a mode chapter: ISLAND_LEVELS expert levels, each with the
## island's own sub-element (if the mode has one) and one or two of the
## chapter's, longer and longer.
static func _mode_island(mode: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array = []
	for variant: String in ChapterPlan.WAVES.get(mode, {}).get("waves", []):
		if variant != ChapterPlan.BASE:
			pool.append(variant)
	var slots: Array[Dictionary] = []
	for i: int in ChapterPlan.ISLAND_LEVELS:
		var variants: Array[String] = []
		if ChapterPlan.ISLAND_VARIANTS.has(mode):
			variants.append(ChapterPlan.ISLAND_VARIANTS[mode])
		variants.append_array(_pick_variants(pool, rng.randi_range(1, 2), variants, rng))
		var extra: Dictionary = _wave_extra(mode, variants, float(i) / ChapterPlan.ISLAND_LEVELS, rng)
		var low: int = ChapterPlan.BANDS["expert"][0] + i
		slots.append({"modes": [mode], "variants": variants, "extra": extra, "low": low, "high": low + 10 + i,
				"t": 1.0, "band": "expert"})
	return slots


## The band whose move range holds `moves`.
static func band_of_moves(moves: int) -> String:
	for band: String in ["easy_medium", "medium", "medium_hard", "hard", "expert"]:
		if moves <= ChapterPlan.BANDS[band][1]:
			return band
	return "expert"


static func _combo_chapter(chapter: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var length: int = ChapterPlan.length_of(chapter)
	var first: int = chapter["first"]
	var combos: Array = chapter["combos"].duplicate()
	if chapter.get("with_earlier_combos", false):
		for key: String in ChapterPlan.whitelist():
			var modes: Array = Array(key.split("+"))
			if not combos.any(func(combo: Array) -> bool: return ChapterPlan.combo_key(combo) == key):
				combos.append(modes)
	var classic_count: int = roundi(length * (1.0 - ChapterPlan.COMBO_SHARE - ChapterPlan.SINGLE_SHARE))
	var single_count: int = roundi(length * ChapterPlan.SINGLE_SHARE)
	var kinds: Array[String] = []
	kinds.resize(length)
	kinds.fill("combo")
	# The first and the last slot are combinations (the last its Böyük Sınaq).
	for index: int in _strata(range(1, length - 1), classic_count, rng):
		kinds[index] = CLASSIC
	var rest: Array = []
	for index: int in range(1, length - 1):
		if kinds[index] == "combo":
			rest.append(index)
	for index: int in _strata(rest, single_count, rng):
		kinds[index] = "single"
	var combo_slots: int = kinds.count("combo")
	# The combinations join one by one over the first half of the combination slots.
	var opens: Array[int] = []
	for i: int in combos.size():
		opens.append(i * combo_slots / (2 * combos.size()))
	var singles: Array = chapter["singles"]
	var combo_used: Array[int] = []
	combo_used.resize(combos.size())
	combo_used.fill(0)
	var slots: Array[Dictionary] = []
	var counters: Dictionary = {CLASSIC: 0, "single": 0, "combo": 0}
	for index: int in length:
		var band: String = ChapterPlan.band_for(index, length)
		if index == length - 1:
			# The Böyük Sınaq: the newest combination, the others if it cannot reach the range.
			var order: Array = combos.duplicate()
			order.reverse()
			var modes: Array[String] = []
			modes.assign(order.pop_front())
			slots.append({"modes": modes, "variants": [] as Array[String], "extra": {}, "low": ChapterPlan.BIG_TEST[0],
					"high": ChapterPlan.BIG_TEST[1], "t": 1.0, "band": "expert", "wave": "big_test", "fallback_modes": order})
			break
		match kinds[index]:
			CLASSIC:
				slots.append({"modes": [], "band": _classic_band(first + index, counters[CLASSIC])})
			"single":
				slots.append({"modes": [singles[counters["single"] % singles.size()]], "band": band})
			_:
				# A combination that just opened comes now; otherwise the one used least.
				var pick: int = -1
				for i: int in combos.size():
					if opens[i] == counters["combo"] and combo_used[i] == 0:
						pick = i
				if pick == -1:
					for i: int in combos.size():
						if opens[i] <= counters["combo"] and (pick == -1 or combo_used[i] < combo_used[pick]):
							pick = i
				combo_used[pick] += 1
				var modes: Array[String] = []
				modes.assign(combos[pick])
				slots.append({"modes": modes, "band": band})
		counters[kinds[index]] += 1
	return slots


## Band of the `index`-th classic level of a later chapter at main `position`.
static func _classic_band(position: int, index: int) -> String:
	var band: String = ChapterPlan.classic_band(position)
	if not band.is_empty():
		return band
	return ChapterPlan.LATER_CLASSIC_BANDS[index % ChapterPlan.LATER_CLASSIC_BANDS.size()]


## `count` of `items`, one drawn in each of `count` equal strata (seeded).
static func _strata(items: Array, count: int, rng: RandomNumberGenerator) -> Array:
	var picked: Array = []
	if count <= 0:
		return picked
	for i: int in count:
		var low: int = i * items.size() / count
		var high: int = (i + 1) * items.size() / count - 1
		picked.append(items[rng.randi_range(low, maxi(high, low))])
	return picked


## "classic", a mode, or a combination's key.
static func stream_of(modes: Array) -> String:
	return CLASSIC if modes.is_empty() else ChapterPlan.combo_key(modes)


## `count` levels of `modes` in `band`, easiest first, their move counts
## spread over the band (lifted to `floor_moves`, ChapterPlan.band_range):
## for each level up to CANDIDATES fitting draws, and the one whose move count
## the group has least so far wins (ties: the longer). A lifted band falls
## back on the next band's boards when its own give nothing. Fewer if the
## recipe boards run dry (with an error).
static func draw_group(modes: Array, band: String, count: int, seed_value: int, used: Dictionary,
		errors: Array[String], floor_moves: int = 0) -> Array[Dictionary]:
	var stream: String = stream_of(modes)
	var recipe: Dictionary = RECIPES.get(stream, {})
	var boards: Array = recipe.get(band, []).duplicate()
	var own: int = boards.size()
	var drafts: Array[Dictionary] = []
	if boards.is_empty():
		errors.append("no recipe for %s in band %s" % [stream, band])
		return drafts
	var span: Array[int] = ChapterPlan.band_range(band, floor_moves)
	var low: int = span[0]
	var high: int = span[1]
	var order: Array[String] = ["easy", "easy_medium", "medium", "medium_hard", "hard", "expert"]
	if low != int(ChapterPlan.BANDS[band][0]) and order.find(band) + 1 < order.size():
		boards.append_array(recipe.get(order[order.find(band) + 1], []))
	var per_moves: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in count:
		var found: Dictionary = {}
		for turn: int in boards.size():
			var board: Dictionary = boards[(i + turn) % own] if turn < own else boards[turn]
			var candidates: int = 0
			for attempt: int in ATTEMPTS_PER_LEVEL:
				var draft: Dictionary = LevelForge.attempt(modes, board, low, high, used, rng)
				if draft.is_empty():
					continue
				candidates += 1
				var seen: int = per_moves.get(draft["moves"], 0)
				var best_seen: int = per_moves.get(found.get("moves", -1), 0)
				if found.is_empty() or seen < best_seen or (seen == best_seen and draft["moves"] > found["moves"]):
					found = draft
				if candidates >= CANDIDATES or seen == 0:
					break
			if not found.is_empty():
				break
		if found.is_empty():
			errors.append("%s/%s: no level %d of %d on any recipe board" % [stream, band, i + 1, count])
			break
		used[found["key"]] = true
		per_moves[found["moves"]] = per_moves.get(found["moves"], 0) + 1
		drafts.append(found)
	drafts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["moves"] < b["moves"])
	return drafts


## One wave level for `slot` ({modes, variants, extra, low, high, band}): the
## recipe boards of its band first, then of the bands next to it, each board
## with the slot's settings on top; {} if none gives one.
static func draw_one(slot: Dictionary, seed_value: int, used: Dictionary) -> Dictionary:
	var recipe: Dictionary = RECIPES.get(stream_of(slot["modes"]), {})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var order: Array[String] = ["easy_medium", "medium", "medium_hard", "hard", "expert"]
	var at: int = order.find(slot["band"])
	var bands: Array[String] = [slot["band"]]
	for near: int in [at - 1, at + 1]:
		if near >= 0 and near < order.size():
			bands.append(order[near])
	for band: String in bands:
		var boards: Array = recipe.get(band, [])
		var offset: int = rng.randi_range(0, maxi(boards.size() - 1, 0))
		for turn: int in boards.size():
			var board: Dictionary = (boards[(offset + turn) % boards.size()] as Dictionary).duplicate()
			board.merge(slot.get("extra", {}), true)
			for attempt: int in ATTEMPTS_PER_LEVEL / 2:
				var draft: Dictionary = LevelForge.attempt(slot["modes"], board, slot["low"], slot["high"], used, rng)
				if not draft.is_empty():
					return draft
	return {}


static func _tutorial_draft(index: int) -> Dictionary:
	var start: PuzzleState = PuzzleState.from_array(TUTORIAL_LEVELS[index]["start"])
	var goal: PuzzleState = PuzzleState.from_array(TUTORIAL_LEVELS[index]["goal"])
	var result: Dictionary = Solver.solve(start, goal, RuleSet.classic(), LevelForge.MAX_STATES)
	var rule_ids: Array[String] = [ClassicHanoiRule.ID]
	return {"start": start, "goal": goal, "rule_ids": rule_ids, "params": {}, "covered": [] as Array[int],
			"path": result["path"], "moves": result["min_moves"], "key": LevelForge.puzzle_key(start, goal, rule_ids, {})}


## Levels with ids and files, in road order: classic levels number up per
## tier, mechanic levels per stream (each in its own id block).
static func _number(plan: Dictionary) -> Dictionary:
	var tier_counts: Dictionary = {}
	var stream_counts: Dictionary = {}
	var files: Dictionary = {}
	var make: Callable = func(slot: Dictionary) -> Level:
		var draft: Dictionary = slot["draft"]
		var tier: String = Difficulty.tier_for_moves(draft["moves"])
		var stream: String = stream_of(slot["modes"])
		var id: int
		var file: String
		if stream == CLASSIC:
			tier_counts[tier] = tier_counts.get(tier, 0) + 1
			id = Difficulty.id_for(tier, tier_counts[tier])
			file = "%s/%s" % [tier, Difficulty.level_file_name(tier, tier_counts[tier])]
		else:
			stream_counts[stream] = stream_counts.get(stream, 0) + 1
			id = id_block(stream) + stream_counts[stream] - 1
			file = "%s/%s_%03d.json" % [Difficulty.MECHANICS, file_stem(stream), stream_counts[stream]]
		var level: Level = Level.create(id, tier, draft["start"], draft["goal"], draft["rule_ids"], draft["path"],
				draft["params"])
		level.covered_pegs.assign(draft["covered"])
		level.variants.assign(draft.get("variants", []))
		level.glass_disks.assign(draft.get("glass", []))
		files[id] = file
		return level
	var main: Array[Level] = []
	for slot: Dictionary in plan["main"]:
		main.append(make.call(slot))
	var islands: Array[Dictionary] = []
	for island: Dictionary in plan["islands"]:
		var levels: Array[Level] = []
		for slot: Dictionary in island["slots"]:
			levels.append(make.call(slot))
		islands.append({"mode": island["mode"], "after": island["after"], "levels": levels})
	return {"main": main, "islands": islands, "files": files}


## First id of a mechanic stream's block.
static func id_block(stream: String) -> int:
	var index: int = ChapterPlan.MODES.find(stream)
	if index == -1:
		index = COMBO_FIRST_BLOCK + ChapterPlan.whitelist().find(stream)
	return Difficulty.MECHANIC_FIRST_ID + index * ID_BLOCK


static func file_stem(stream: String) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for mode: String in stream.split("+"):
		parts.append(MODE_FILES[mode])
	return "_".join(parts)


## Replaces every level file under `levels_dir` and its path file.
static func write(road: Dictionary, levels_dir: String) -> void:
	for folder: String in DirAccess.get_directories_at(levels_dir):
		for file_name: String in DirAccess.get_files_at("%s/%s" % [levels_dir, folder]):
			if file_name.ends_with(".json"):
				DirAccess.remove_absolute("%s/%s/%s" % [levels_dir, folder, file_name])
	var files: Dictionary = road["files"]
	var all: Array[Level] = []
	all.append_array(road["main"])
	for island: Dictionary in road["islands"]:
		all.append_array(island["levels"])
	for level: Level in all:
		var path: String = "%s/%s" % [levels_dir, files[level.id]]
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		level.save_file(path)
	var file: FileAccess = FileAccess.open("%s/%s" % [levels_dir, LevelCatalog.PATH_FILE], FileAccess.WRITE)
	file.store_string(to_json(road))
	file.close()


## The path file: one entry per line, so it stays readable and diffs well.
static func to_json(road: Dictionary) -> String:
	var files: Dictionary = road["files"]
	var entries: Callable = func(levels: Array) -> String:
		var lines: PackedStringArray = PackedStringArray()
		for level: Level in levels:
			lines.append("    {\"file\": %s, \"id\": %d}" % [JSON.stringify(files[level.id]), level.id])
		return ",\n".join(lines)
	var islands: PackedStringArray = PackedStringArray()
	for island: Dictionary in road["islands"]:
		islands.append("    {\"mode\": %s, \"after\": %d, \"levels\": [\n  %s\n    ]}" % [JSON.stringify(island["mode"]),
				island["after"], entries.call(island["levels"]).replace("\n", "\n  ")])
	return "{\n  \"main\": [\n%s\n  ],\n  \"islands\": [\n%s\n  ]\n}\n" % [entries.call(road["main"]), ",\n".join(islands)]


## Status per world (chapter plan, "Sıra tövsiyəsi"): levels, bands, streams.
static func describe(road: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var main: Array = road["main"]
	for chapter: Dictionary in ChapterPlan.CHAPTERS:
		if int(chapter["first"]) > main.size():
			break
		var streams: Dictionary = {}
		var moves: Array[int] = []
		for position: int in range(int(chapter["first"]), int(chapter["last"]) + 1):
			var level: Level = main[position - 1]
			var stream: String = stream_of(level.modes())
			streams[stream] = streams.get(stream, 0) + 1
			moves.append(level.min_moves)
		lines.append("world %d, main %d-%d %s: %s, moves %d..%d" % [chapter["world"], chapter["first"], chapter["last"],
				chapter.get("mode", chapter["kind"]), str(streams), moves.min(), moves.max()])
	for island: Dictionary in road["islands"]:
		var tiers: Dictionary = {}
		for level: Level in island["levels"]:
			tiers[level.difficulty] = tiers.get(level.difficulty, 0) + 1
		lines.append("island after main %d (%s): %s" % [island["after"], island["mode"], str(tiers)])
	return "\n".join(lines)
