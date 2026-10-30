extends SceneTree
## Writes the demo road (data/levels/demo_path.json, user's decision
## 2026-10-30) from the full road's levels (path.json): no level is drawn,
## each demo chapter (ChapterPlan.DEMO_CHAPTERS) picks from the full chapter
## of the same mode or world, in the full road's order:
##   20-level mode chapter: 3 base levels, 4 sub-elements x 3, 2 mixed, 2
##   classic breathers, its Böyük Sınaq; a 15-level one: 2, 4 x 2, 2, 2, 1.
##   Combination chapter: its pairs in turn (each one's first level is its
##   intro), then its Böyük Sınaq. Classic chapter: the full road's first levels.
## The first level of every sub-element and pair is the full road's first one,
## so the guided intros stay intros. `-- --stats` prints the count per chapter.
##
##   godot --headless --path . --script res://tools/demo_road.gd

const MIXED: int = 2
const BREATHS: int = 2
const SUB_ELEMENTS: int = 4


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	var errors: Array[String] = []
	var full: Dictionary = LevelCatalog.read_path("%s/%s" % [Difficulty.LEVELS_DIR, LevelCatalog.PATH_FILE], errors)
	if not errors.is_empty():
		printerr("; ".join(errors))
		return false
	var main: Array = full[LevelCatalog.MAIN]
	var levels: Array[Level] = []
	for entry: Dictionary in main:
		levels.append(Level.load_file("%s/%s" % [Difficulty.LEVELS_DIR, entry["file"]], errors))
	var picked: Array = []
	var good: bool = true
	for chapter: Dictionary in ChapterPlan.DEMO_CHAPTERS:
		var source: Dictionary = _full_chapter(chapter)
		var length: int = ChapterPlan.length_of(chapter)
		var positions: Array[int] = []  # 0-based full road positions
		match chapter["kind"]:
			ChapterPlan.CLASSIC_CHAPTER:
				for i: int in length:
					positions.append(int(source["first"]) - 1 + i)
			ChapterPlan.MODE_CHAPTER:
				positions = _mode_picks(chapter, source, levels, length)
			_:
				positions = _combo_picks(source, levels, length)
		var counts: Dictionary = {}
		for at: int in positions:
			var kind: String = _kind(levels[at], at == int(source["last"]) - 1)
			counts[kind] = counts.get(kind, 0) + 1
			picked.append(main[at])
		var status: String = "ok" if positions.size() == length else "SHORT"
		good = good and positions.size() == length
		print("demo %d-%d %s: %d/%d %s %s" % [chapter["first"], chapter["last"], chapter.get("mode", chapter["kind"]),
				positions.size(), length, str(counts), status])
	print("demo road: %d levels" % picked.size())
	var lines: PackedStringArray = PackedStringArray()
	for entry: Dictionary in picked:
		lines.append("    {\"file\": %s, \"id\": %d}" % [JSON.stringify(entry["file"]), int(entry["id"])])
	var file: FileAccess = FileAccess.open("%s/%s" % [Difficulty.LEVELS_DIR, LevelCatalog.DEMO_PATH_FILE], FileAccess.WRITE)
	file.store_string("{\n  \"main\": [\n%s\n  ],\n  \"islands\": [\n  ]\n}\n" % ",\n".join(lines))
	file.close()
	return good


## The full road's chapter a demo chapter picks from.
static func _full_chapter(chapter: Dictionary) -> Dictionary:
	for full: Dictionary in ChapterPlan.FULL_CHAPTERS:
		if full["kind"] == chapter["kind"] and full["world"] == chapter["world"] \
				and full.get("mode", "") == chapter.get("mode", ""):
			return full
	return {}


static func _kind(level: Level, big: bool) -> String:
	if big:
		return "big"
	if level.modes().is_empty():
		return "classic"
	if level.modes().size() > 1:
		return "combo"
	return ["base", "sub", "mixed"][mini(level.variants.size(), 2)]


## A mode chapter's picks, in the full road's order, its Böyük Sınaq last.
static func _mode_picks(chapter: Dictionary, source: Dictionary, levels: Array[Level], length: int) -> Array[int]:
	var mode: String = chapter["mode"]
	var first: int = int(source["first"]) - 1
	var last: int = int(source["last"]) - 1
	var each: int = 3 if length >= 20 else 2
	var bases: Array[int] = []
	var classics: Array[int] = []
	var mixed: Array[int] = []
	var subs: Dictionary = {}  # sub-element -> positions
	var order: Array[String] = []
	for at: int in range(first, last):
		var level: Level = levels[at]
		var modes: Array[String] = level.modes()
		if modes.is_empty():
			classics.append(at)
		elif modes.size() == 1 and modes[0] == mode:
			if level.variants.is_empty():
				bases.append(at)
			elif level.variants.size() == 1:
				if not subs.has(level.variants[0]):
					subs[level.variants[0]] = []
					order.append(level.variants[0])
				(subs[level.variants[0]] as Array).append(at)
			else:
				mixed.append(at)
	var chosen: Array[String] = []
	chosen.assign(order.slice(0, SUB_ELEMENTS))
	var picks: Array[int] = []
	for variant: String in chosen:
		for at: int in (subs[variant] as Array).slice(0, each):
			picks.append(at)
	# The closing mixed wave: the last mixed levels whose sub-elements were taught.
	var mixed_picks: Array[int] = []
	for k: int in range(mixed.size() - 1, -1, -1):
		var level: Level = levels[mixed[k]]
		if mixed_picks.size() < MIXED and level.variants.all(func(v: String) -> bool: return chosen.has(v)):
			mixed_picks.push_front(mixed[k])
	picks.append_array(mixed_picks)
	# Two classic breathers: one from each half of the chapter.
	var middle: int = (first + last) / 2
	var early: Array = classics.filter(func(at: int) -> bool: return at < middle)
	var late: Array = classics.filter(func(at: int) -> bool: return at >= middle)
	if not early.is_empty():
		picks.append(early[early.size() / 2])
	if not late.is_empty():
		picks.append(late[late.size() / 2])
	# Base levels fill the rest (fewer sub-elements or levels than planned).
	var base_count: int = length - 1 - picks.size()
	for at: int in bases.slice(0, maxi(base_count, 0)):
		picks.append(at)
	# Still short: more levels of the taught sub-elements.
	for variant: String in chosen:
		for at: int in (subs[variant] as Array).slice(each):
			if picks.size() < length - 1:
				picks.append(at)
	picks.sort()
	picks.append(last)
	return picks


## A combination chapter's picks: its pairs in turn, its Böyük Sınaq last.
static func _combo_picks(source: Dictionary, levels: Array[Level], length: int) -> Array[int]:
	var first: int = int(source["first"]) - 1
	var last: int = int(source["last"]) - 1
	var per_pair: Dictionary = {}
	var order: Array[String] = []
	for at: int in range(first, last):
		var modes: Array[String] = levels[at].modes()
		if modes.size() < 2:
			continue
		var key: String = ChapterPlan.combo_key(modes)
		if not per_pair.has(key):
			per_pair[key] = []
			order.append(key)
		(per_pair[key] as Array).append(at)
	var picks: Array[int] = []
	var round_index: int = 0
	while picks.size() < length - 1:
		var added: bool = false
		for key: String in order:
			if picks.size() < length - 1 and round_index < (per_pair[key] as Array).size():
				picks.append(per_pair[key][round_index])
				added = true
		if not added:
			break
		round_index += 1
	picks.sort()
	picks.append(last)
	return picks
