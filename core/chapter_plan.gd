class_name ChapterPlan
extends RefCounted
## The chapter system (MindShift_Fesil_Sistemi_v1.md, 2026-10-15): the road is
## seven worlds of chapters. Each mode is taught in its own chapter of 100-150
## levels with classic Hanoi as breathers, and after two or three modes a
## 50-level combination chapter mixes what was learned. tools/road_builder.gd
## builds the levels slot by slot from this plan; the game itself only reads
## the finished path (LevelCatalog).
##
## User decisions (2026-10-15): the main road keeps its 33-move ceiling (each
## level takes the move range of its band, 34+ only on the islands); the
## balance tolerance shrinks only inside the range where the rule works on its
## board; the great exchange may start halfway (disks already on the buffers);
## every mode chapter ends at an island of its own (classic: after main 50).

## Kinds of chapter.
const CLASSIC_CHAPTER: String = "classic"
const MODE_CHAPTER: String = "mode"
const COMBO_CHAPTER: String = "combo"

## Every mode a chapter can teach, in road order. Each is a rule id, except
## "covered_pegs" (karakuri boxes, presentation only).
const MODES: Array[String] = ["peg_capacity", "covered_pegs", "foundation", "adjacent_pegs", "stripes", "cyclic",
		"alternation", "balance", "color_swap", "trail", "chain", "mirror", "linked_pegs", "magnet"]
const COVERED: String = "covered_pegs"

## The chapters along the main road (section 2). `first`/`last`: main road
## positions. Mode chapters: one classic level for every `ratio` mode levels
## (3:1, World 1's 2-3:1 as 2.5). Combination chapters: `combos` (section 4.3)
## and the single modes of their world (`singles`).
const CHAPTERS: Array[Dictionary] = [
	{"world": 1, "kind": CLASSIC_CHAPTER, "first": 1, "last": 50},
	{"world": 1, "kind": MODE_CHAPTER, "mode": "peg_capacity", "first": 51, "last": 100, "ratio": 2.5},
	{"world": 2, "kind": MODE_CHAPTER, "mode": "covered_pegs", "first": 101, "last": 200, "ratio": 3.0},
	{"world": 2, "kind": MODE_CHAPTER, "mode": "foundation", "first": 201, "last": 300, "ratio": 3.0},
	{"world": 2, "kind": COMBO_CHAPTER, "first": 301, "last": 350, "singles": ["covered_pegs", "foundation"],
		"combos": [["peg_capacity", "covered_pegs"], ["peg_capacity", "foundation"], ["covered_pegs", "foundation"]]},
	{"world": 3, "kind": MODE_CHAPTER, "mode": "adjacent_pegs", "first": 351, "last": 450, "ratio": 3.0},
	{"world": 3, "kind": MODE_CHAPTER, "mode": "stripes", "first": 451, "last": 550, "ratio": 3.0},
	{"world": 3, "kind": MODE_CHAPTER, "mode": "cyclic", "first": 551, "last": 650, "ratio": 3.0},
	{"world": 3, "kind": COMBO_CHAPTER, "first": 651, "last": 700, "singles": ["adjacent_pegs", "stripes", "cyclic"],
		"combos": [["adjacent_pegs", "peg_capacity"], ["adjacent_pegs", "foundation"], ["stripes", "peg_capacity"],
			["stripes", "adjacent_pegs"], ["cyclic", "peg_capacity"], ["cyclic", "foundation"]]},
	{"world": 4, "kind": MODE_CHAPTER, "mode": "alternation", "first": 701, "last": 820, "ratio": 3.0},
	{"world": 4, "kind": MODE_CHAPTER, "mode": "balance", "first": 821, "last": 970, "ratio": 3.0},
	{"world": 4, "kind": COMBO_CHAPTER, "first": 971, "last": 1020, "singles": ["alternation", "balance"],
		"combos": [["alternation", "peg_capacity"], ["balance", "peg_capacity"], ["balance", "foundation"],
			["balance", "stripes"], ["balance", "covered_pegs"]]},
	{"world": 5, "kind": MODE_CHAPTER, "mode": "color_swap", "first": 1021, "last": 1170, "ratio": 3.0},
	{"world": 5, "kind": MODE_CHAPTER, "mode": "trail", "first": 1171, "last": 1270, "ratio": 3.0},
	{"world": 5, "kind": COMBO_CHAPTER, "first": 1271, "last": 1320, "singles": ["color_swap", "trail"],
		"combos": [["color_swap", "adjacent_pegs"], ["color_swap", "cyclic"], ["color_swap", "peg_capacity"],
			["trail", "adjacent_pegs"], ["trail", "peg_capacity"]]},
	{"world": 6, "kind": MODE_CHAPTER, "mode": "chain", "first": 1321, "last": 1470, "ratio": 3.0},
	{"world": 6, "kind": MODE_CHAPTER, "mode": "mirror", "first": 1471, "last": 1570, "ratio": 3.0},
	{"world": 6, "kind": COMBO_CHAPTER, "first": 1571, "last": 1620, "singles": ["chain", "mirror"],
		"combos": [["chain", "peg_capacity"], ["chain", "adjacent_pegs"], ["chain", "balance"], ["mirror", "peg_capacity"]]},
	{"world": 7, "kind": MODE_CHAPTER, "mode": "linked_pegs", "first": 1621, "last": 1770, "ratio": 3.0},
	{"world": 7, "kind": MODE_CHAPTER, "mode": "magnet", "first": 1771, "last": 1920, "ratio": 3.0},
	{"world": 7, "kind": COMBO_CHAPTER, "first": 1921, "last": 2020, "singles": ["linked_pegs", "magnet"],
		"combos": [["linked_pegs", "foundation"], ["linked_pegs", "peg_capacity"], ["magnet", "peg_capacity"],
			["magnet", "foundation"]], "with_earlier_combos": true},
]

## Combination chapters: shares of combinations, single modes and classic
## levels (section 3.4).
const COMBO_SHARE: float = 0.5
const SINGLE_SHARE: float = 0.3
## Section 3.3b: in the second half of a mode chapter one level in every
## REPEAT_EVERY is an earlier chapter's mode.
const REPEAT_EVERY: int = 10

## Difficulty bands: [fewest, most moves]. A chapter climbs through BAND_ORDER
## (section 3.2), ending each band at its share of the chapter (BAND_ENDS).
## "easy" only opens the road, "expert" lives on the islands.
const BANDS: Dictionary = {
	"easy": [5, 7],
	"easy_medium": [7, 12],
	"medium": [12, 18],
	"medium_hard": [18, 25],
	"hard": [25, 33],
	"expert": [34, 70],
}
const BAND_ORDER: Array[String] = ["easy_medium", "medium", "medium_hard", "hard"]
const BAND_ENDS: Array[float] = [0.15, 0.45, 0.75, 1.0]
## Classic levels 1-100 (section 3.1): band by main road position (last
## position of each band).
const CLASSIC_TABLE: Array[Array] = [[5, "easy"], [20, "easy_medium"], [45, "medium"], [75, "medium_hard"],
		[100, "hard"]]
## Classic levels inside later chapters take turns between these bands.
const LATER_CLASSIC_BANDS: Array[String] = ["medium_hard", "hard"]

## Islands (section 7): each mode chapter ends at an island of
## ISLAND_LEVELS expert levels of its mode; the classic chapter's island keeps
## its old mix (expert levels with a few hard and medium breathers, opening
## with a hard one).
const ISLAND_LEVELS: int = 10
const CLASSIC_ISLAND: Dictionary = {"expert": 28, "hard": 8, "medium": 4}

## Mode categories (section 4.1).
const CATEGORIES: Dictionary = {
	"peg_capacity": ["local"], "foundation": ["local"],
	"covered_pegs": ["hidden"],
	"adjacent_pegs": ["topology"], "linked_pegs": ["topology"],
	"cyclic": ["topology", "layout"],
	"stripes": ["colour"], "magnet": ["colour"],
	"color_swap": ["colour", "goal"],
	"alternation": ["history"], "trail": ["history"],
	"balance": ["layout", "goal"],
	"mirror": ["layout", "goal"],
	"chain": ["compound"],
}
## Categories a combination may hold only one mode of (section 4.2, rule 1).
const EXCLUSIVE: Array[String] = ["hidden", "topology", "colour", "history", "layout", "goal", "compound"]


## The chapter that holds main road `position`, or {}.
static func chapter_at(position: int) -> Dictionary:
	for chapter: Dictionary in CHAPTERS:
		if position >= chapter["first"] and position <= chapter["last"]:
			return chapter
	return {}


## The chapters of `worlds` (world numbers), in road order.
static func chapters_of(worlds: Array[int]) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for chapter: Dictionary in CHAPTERS:
		if worlds.has(int(chapter["world"])):
			found.append(chapter)
	return found


static func length_of(chapter: Dictionary) -> int:
	return int(chapter["last"]) - int(chapter["first"]) + 1


## The band of the slot `index` (0-based) of a chapter of `length` slots.
static func band_for(index: int, length: int) -> String:
	var share: float = (index + 0.5) / float(length)
	for i: int in BAND_ENDS.size():
		if share <= BAND_ENDS[i]:
			return BAND_ORDER[i]
	return BAND_ORDER[-1]


## The band of a classic level at main road `position` 1-100 (CLASSIC_TABLE),
## or "" past it.
static func classic_band(position: int) -> String:
	for row: Array in CLASSIC_TABLE:
		if position <= row[0]:
			return row[1]
	return ""


## Modes taught by the chapters before main road `position`, oldest first.
static func modes_before(position: int) -> Array[String]:
	var found: Array[String] = []
	for chapter: Dictionary in CHAPTERS:
		if int(chapter["last"]) < position and chapter["kind"] == MODE_CHAPTER:
			found.append(chapter["mode"])
	return found


## The canonical name of a combination: its modes in MODES order, joined by "+".
static func combo_key(modes: Array) -> String:
	var sorted: Array[String] = []
	for mode: String in MODES:
		if modes.has(mode):
			sorted.append(mode)
	return "+".join(sorted)


## Whether `modes` (two or three) may form a combination (section 4.2): at
## most one mode of each exclusive category, karakuri never with a history
## mode or the chain, the mirror only with unequal capacity.
static func is_combo_allowed(modes: Array) -> bool:
	var seen: Dictionary = {}
	for mode: String in modes:
		if not CATEGORIES.has(mode):
			return false
		for category: String in CATEGORIES[mode]:
			if EXCLUSIVE.has(category) and seen.has(category):
				return false
			seen[category] = true
	if modes.has(COVERED) and (seen.has("history") or modes.has("chain")):
		return false
	if modes.has("mirror"):
		for mode: String in modes:
			if mode != "mirror" and mode != "peg_capacity":
				return false
	return true


## Every two-mode combination the plan lists (section 4.3), canonical keys.
static func whitelist() -> Array[String]:
	var keys: Array[String] = []
	for chapter: Dictionary in CHAPTERS:
		for combo: Array in chapter.get("combos", []):
			var key: String = combo_key(combo)
			if not keys.has(key):
				keys.append(key)
	return keys
