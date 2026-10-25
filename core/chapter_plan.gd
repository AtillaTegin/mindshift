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
## New modes join at the end: a mode's place gives its level ids
## (RoadBuilder.id_block) and its order inside a combination's name.
const MODES: Array[String] = ["peg_capacity", "covered_pegs", "foundation", "adjacent_pegs", "stripes", "cyclic",
		"alternation", "balance", "color_swap", "trail", "chain", "mirror", "linked_pegs", "magnet",
		# ICRA World 5-9 (MindShift_ICRA_Dunya5-9_Yeni_Modlar_v1.md).
		"king", "river", "carpet", "ko", "heavy", "elements", "sum", "turns", "kintsugi", "lamp", "solitaire"]
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
			["stripes", "adjacent_pegs"], ["cyclic", "peg_capacity"], ["cyclic", "foundation"],
			# Current decisions 2026-10-16, D: karakuri comes back here (and with
			# the balance in combination III, "Gizli Yük"), never inside its
			# chapter before the player knows the other mode.
			["covered_pegs", "stripes"]]},
	{"world": 4, "kind": MODE_CHAPTER, "mode": "alternation", "first": 701, "last": 820, "ratio": 3.0},
	{"world": 4, "kind": MODE_CHAPTER, "mode": "balance", "first": 821, "last": 970, "ratio": 3.0},
	{"world": 4, "kind": COMBO_CHAPTER, "first": 971, "last": 1020, "singles": ["alternation", "balance"],
		"combos": [["alternation", "peg_capacity"], ["balance", "peg_capacity"], ["balance", "foundation"],
			["balance", "stripes"], ["balance", "covered_pegs"]]},
	# ICRA World 5-9 (2026-10-17) replaces the old World 5-7 plan; Güzgü,
	# Bağlı, Maqnit and the Final wait for a later update.
	{"world": 5, "kind": MODE_CHAPTER, "mode": "king", "first": 1021, "last": 1120, "ratio": 3.0},
	{"world": 5, "kind": MODE_CHAPTER, "mode": "river", "first": 1121, "last": 1220, "ratio": 3.0},
	{"world": 5, "kind": MODE_CHAPTER, "mode": "color_swap", "first": 1221, "last": 1370, "ratio": 3.0},
	{"world": 5, "kind": COMBO_CHAPTER, "first": 1371, "last": 1420, "singles": ["king", "river", "color_swap"],
		"combos": [["river", "peg_capacity"], ["river", "covered_pegs"], ["river", "foundation"],
			["color_swap", "adjacent_pegs"], ["color_swap", "peg_capacity"], ["king", "adjacent_pegs"], ["king", "cyclic"]]},
	{"world": 6, "kind": MODE_CHAPTER, "mode": "carpet", "first": 1421, "last": 1520, "ratio": 3.0},
	{"world": 6, "kind": MODE_CHAPTER, "mode": "ko", "first": 1521, "last": 1620, "ratio": 3.0},
	{"world": 6, "kind": MODE_CHAPTER, "mode": "chain", "first": 1621, "last": 1770, "ratio": 3.0},
	{"world": 6, "kind": COMBO_CHAPTER, "first": 1771, "last": 1820, "singles": ["carpet", "ko", "chain"],
		"combos": [["ko", "peg_capacity"], ["ko", "adjacent_pegs"], ["ko", "river"], ["chain", "peg_capacity"],
			["chain", "adjacent_pegs"], ["chain", "balance"], ["carpet", "stripes"]]},
	{"world": 7, "kind": MODE_CHAPTER, "mode": "heavy", "first": 1821, "last": 1920, "ratio": 3.0},
	{"world": 7, "kind": MODE_CHAPTER, "mode": "elements", "first": 1921, "last": 2040, "ratio": 3.0},
	{"world": 7, "kind": MODE_CHAPTER, "mode": "trail", "first": 2041, "last": 2140, "ratio": 3.0},
	{"world": 7, "kind": COMBO_CHAPTER, "first": 2141, "last": 2190, "singles": ["heavy", "elements", "trail"],
		"combos": [["elements", "cyclic"], ["elements", "adjacent_pegs"], ["elements", "peg_capacity"],
			["heavy", "peg_capacity"], ["heavy", "foundation"], ["trail", "adjacent_pegs"], ["trail", "river"]]},
	{"world": 8, "kind": MODE_CHAPTER, "mode": "sum", "first": 2191, "last": 2290, "ratio": 3.0},
	{"world": 8, "kind": MODE_CHAPTER, "mode": "turns", "first": 2291, "last": 2390, "ratio": 3.0},
	{"world": 8, "kind": MODE_CHAPTER, "mode": "kintsugi", "first": 2391, "last": 2510, "ratio": 3.0},
	{"world": 8, "kind": COMBO_CHAPTER, "first": 2511, "last": 2560, "singles": ["sum", "turns", "kintsugi"],
		"combos": [["sum", "peg_capacity"], ["sum", "adjacent_pegs"], ["sum", "foundation"], ["turns", "peg_capacity"],
			["turns", "river"], ["kintsugi", "adjacent_pegs"], ["kintsugi", "turns"]]},
	{"world": 9, "kind": MODE_CHAPTER, "mode": "lamp", "first": 2561, "last": 2680, "ratio": 3.0},
	{"world": 9, "kind": MODE_CHAPTER, "mode": "solitaire", "first": 2681, "last": 2830, "ratio": 3.0},
	{"world": 9, "kind": COMBO_CHAPTER, "first": 2831, "last": 2880, "singles": ["lamp", "solitaire"],
		"combos": [["solitaire", "stripes"], ["solitaire", "peg_capacity"], ["solitaire", "adjacent_pegs"],
			["lamp", "peg_capacity"], ["lamp", "adjacent_pegs"]]},
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
## Each world's floor (chapter waves v1.2, 5b; the user's decision of
## 2026-10-16): no level of world n takes fewer than WORLD_FLOORS[n - 1] moves
## (world 4 and later the last one), except the guided intros: the two
## tutorial levels and the first main road level of each lesson and of each
## sub-element. A band below the floor is lifted to it (band_range()).
const WORLD_FLOORS: Array[int] = [7, 14, 16, 18]
## A lifted band keeps at least this many moves between its ends.
const FLOOR_BAND_WIDTH: int = 2

## "Böyük Sınaq" (Fəsil Sistemi v1.2, 3.2a): the last level of every mode and
## combination chapter (not the classic one) may be long, 34-65 moves (expert
## tier, so its hint costs 5); one per chapter, a crowned stop on the map;
## longer levels only on the islands. A mode chapter's holds every
## sub-element of the chapter that can share a level.
const BIG_TEST: Array[int] = [34, 65]


## Whether main road `position` is a chapter's Böyük Sınaq.
static func is_big_test(position: int) -> bool:
	var chapter: Dictionary = chapter_at(position)
	return not chapter.is_empty() and chapter["kind"] != CLASSIC_CHAPTER and int(chapter["last"]) == position


## Islands (section 7): each mode chapter ends at an island of
## ISLAND_LEVELS expert levels of its mode; the classic chapter's island keeps
## its old mix (expert levels with a few hard and medium breathers, opening
## with a hard one).
const ISLAND_LEVELS: int = 10
const CLASSIC_ISLAND: Dictionary = {"expert": 28, "hard": 8, "medium": 4}

## Waves inside a mode chapter (chapter waves v1, MindShift_Fesil_Daxili_
## Dalgalar_v1.md): each mode's sub-elements in the order they arrive. The
## first wave is the mode's base form ("base", no sub-element); each later
## wave brings one new sub-element; `mixed` adds a closing wave with several
## of them at once. Modes not listed keep one wave (their chapters are not
## built yet). The chapter's last level is its Böyük Sınaq (BIG_TEST).
const BASE: String = "base"
const WAVES: Dictionary = {
	"peg_capacity": {"waves": ["base", "narrow", "arch"], "mixed": false},
	"covered_pegs": {"waves": ["base", "full_hidden", "glass", "empty_box", "sealed"], "mixed": true},
	"foundation": {"waves": ["base", "key_disk", "middle_lock", "chain_lock"], "mixed": true},
	# World 3-4 (MindShift_Dunya3-4_Alt_Elementler_v1.md).
	"adjacent_pegs": {"waves": ["base", "oasis", "tunnel", "bridge", "one_way"], "mixed": true},
	"stripes": {"waves": ["base", "neutral", "colored_base", "paint", "inverse"], "mixed": true},
	"cyclic": {"waves": ["base", "back_peg", "shortcut", "center", "eight"], "mixed": true},
	"alternation": {"waves": ["base", "broken_ring", "reset_peg", "new_leader", "waiting_ring"], "mixed": true},
	"balance": {"waves": ["base", "stone", "long_arm", "three_scales", "own_limits"], "mixed": true},
	# ICRA World 5-9, section 3.
	"king": {"waves": ["base", "odd_even", "vizier", "narrow_gate", "siege"], "mixed": true},
	"river": {"waves": ["base", "stone_bridge", "ferry", "two_crossings", "reverse"], "mixed": true},
	"color_swap": {"waves": ["base", "mid_start", "mixed", "caravanserai", "three_caravans"], "mixed": true},
	"carpet": {"waves": ["base", "navel", "coloured", "buta", "twin"], "mixed": true},
	"ko": {"waves": ["base", "target_ko", "free_peg", "long_ko", "two_stones"], "mixed": true},
	"chain": {"waves": ["base", "two_chains", "breaking", "long_chain", "rubber"], "mixed": true},
	"heavy": {"waves": ["base", "cart", "reverse_weight", "fatigue", "uphill"], "mixed": true},
	"elements": {"waves": ["base", "neutral_earth", "element_base", "creation", "element_peg"], "mixed": true},
	# "Böyük iz" is not built: the largest disk never has to come back to a peg,
	# so its trail never changes a solution (measured 2026-10-18).
	"trail": {"waves": ["base", "clean_peg", "fading", "two_trails"], "mixed": true},
	# "Tək-cüt cəm" is not built: odd and even sums are met in 3-7 moves
	# (measured 2026-10-17), short even for a breather.
	"sum": {"waves": ["base", "fair", "sum_and_height", "double_peg"], "mixed": true},
	"turns": {"waves": ["base", "pass", "grey", "double_turn", "three_colours"], "mixed": true},
	"kintsugi": {"waves": ["base", "deep_crack", "two_workshops", "single_repair", "ordered_repair"], "mixed": true},
	"lamp": {"waves": ["base", "long_light", "fixed_lantern", "two_lamps", "lamp_disk"], "mixed": true},
	# "Sıra köçürmə" is not built (ICRA 3.14 allows dropping it): four waves.
	"solitaire": {"waves": ["base", "free_cell", "red_black", "run_arch", "run_narrow"], "mixed": true},
}
## Waves that hold fewer levels than an even share, because their puzzles run
## out (measured 2026-10-17: the great exchange's base form from the ends is
## one puzzle per board, and only 4 pegs / 8 disks reaches the world's floor,
## besides the intro); the other waves of the mode share the rest.
const WAVE_SIZES: Dictionary = {"color_swap": {"base": 2}}
## Sub-elements only the islands use (section 3): one per island, mixed with
## the chapter's own.
const ISLAND_VARIANTS: Dictionary = {"peg_capacity": "holed", "covered_pegs": "reclosing", "adjacent_pegs": "jump",
	"balance": "moving_stone", "river": "bonfire", "elements": "changing"}
## Islands whose levels always hold these sub-elements of the chapter
## together (ICRA 3.1: the king's island has the king, the vizier and the
## narrow gate in one level).
## The river's island is the bonfire alone (its fords and bridges are the
## river's).
const ISLAND_SETS: Dictionary = {"king": ["vizier", "narrow_gate"], "river": []}
## Sub-elements that keep their own wave: never mixed with others, never in a
## repeat or a Böyük Sınaq (World 3-4 spec: the turned stripes and the figure
## eight are twists of their own; ICRA: the odd and even towers change the
## king's goal, the reversed river and the reversed weight turn their mode).
const SOLO: Array[String] = ["inverse", "eight", "odd_even", "reverse", "reverse_weight"]
## The most moves a level with these sub-elements reaches (measured
## 2026-10-17: a centre linked to every peg, three scales and the river's
## ferry keep solutions short); their levels' windows stop there, and they
## stay out of a Böyük Sınaq (34+) and an island.
const VARIANT_CEILINGS: Dictionary = {"center": 22, "three_scales": 20, "ferry": 22}
## The most moves the islands of these modes reach on boards whose hints stay
## within a few seconds (measured 2026-10-17: stripes and the Nine Rings on 4
## pegs / 9 disks, the scales on 4 / 7, hardly ever past 44); their island
## levels stay at most that long (still 34+).
const ISLAND_CEILINGS: Dictionary = {"stripes": 44, "alternation": 44, "balance": 44}
## Islands whose levels take any length of the expert range rather than a
## climbing one: the bonfire's stack of elephants moves in a few fixed
## lengths (measured 2026-10-17: 33-34 moves on 5 pegs / 7 disks, 65 on 5 / 8).
const ISLAND_WINDOWS: Dictionary = {"river": [34, 65]}
## Sub-elements that only help (World 3-4 spec, [kömək]): such a sub-element
## must be used, without it the level takes longer (LevelForge.variants_matter);
## every other rule-changing one must make it longer.
const HELPERS: Array[String] = ["oasis", "tunnel", "jump", "neutral", "back_peg", "shortcut", "center", "broken_ring",
	"reset_peg", "moving_stone", "stone_bridge", "ferry", "caravanserai", "free_peg", "breaking", "cart", "neutral_earth",
	"clean_peg", "pass", "grey", "two_workshops", "long_light", "fixed_lantern", "free_cell"]
## Sub-elements that cannot share a level: in a fully hidden level every box
## holds a disk, so it has no empty box (current decisions 2026-10-16, B.1).
## Three caravans (ICRA 3.3) have the pure kind's size rule only: no colour
## rule, so no mixed ends and no caravanserai with them. A twin carpet has no
## one middle peg for a navel; the target ko and two stones are two kinds of
## breathing; a chain of three is no pair to break or stretch, and no second
## chain beside it.
const CLASHES: Array[Array] = [["full_hidden", "empty_box"], ["three_caravans", "mixed"], ["three_caravans", "caravanserai"],
	["twin", "navel"], ["target_ko", "two_stones"], ["long_chain", "breaking"], ["long_chain", "rubber"],
	["long_chain", "two_chains"], ["element_peg", "changing"], ["double_turn", "three_colours"], ["two_lamps", "lamp_disk"]]
## Rules that belong to a mode as one of its sub-elements (not modes).
const SUB_RULES: Dictionary = {"sealed_box": "covered_pegs"}

## Goal variants, the "nəfəs" levels (ICRA section 4): from the main road
## position given on (once the chapter that teaches it is over), about
## BREATH_SHARE of each chapter's levels are its own mode's with another
## goal, short (BREATH_MOVES, below the world's floor too) on small boards,
## never a Böyük Sınaq. The goal comes from a goal-setting mode's rule
## (GOAL_RULES); such a level names the variant and is still a level of its
## chapter's mode (Level.modes()).
const GOAL_VARIANTS: Dictionary = {"goal_king": 1121, "goal_odd_even": 1121, "goal_silhouette": 1521, "goal_sum": 2291}
const GOAL_RULES: Dictionary = {"goal_king": "king", "goal_odd_even": "king", "goal_silhouette": "carpet", "goal_sum": "sum"}
const BREATH_SHARE: float = 0.1
const BREATH_MOVES: Array[int] = [12, 18]
## Modes that bring a goal of their own: no goal variant goes with them (ICRA
## section 4: not with the scales or the exchange; one goal per level).
const OWN_GOAL: Array[String] = ["king", "color_swap", "balance", "mirror", "carpet", "sum"]


## The goal variants a chapter starting at main road `position` may use.
static func goal_variants_at(position: int) -> Array[String]:
	var found: Array[String] = []
	for variant: String in GOAL_VARIANTS:
		if position >= int(GOAL_VARIANTS[variant]):
			found.append(variant)
	return found


## The sub-elements of `mode` in wave order (base first), chapter and island;
## any mode without a goal of its own may carry a goal variant.
static func variants_of(mode: String) -> Array[String]:
	var found: Array[String] = []
	found.assign(WAVES.get(mode, {}).get("waves", [BASE]))
	if ISLAND_VARIANTS.has(mode):
		found.append(ISLAND_VARIANTS[mode])
	if not OWN_GOAL.has(mode):
		for variant: String in GOAL_VARIANTS:
			found.append(variant)
	return found


## The mode a rule id belongs to: itself, or the mode of a sub-element rule.
static func mode_of_rule(rule_id: String) -> String:
	return SUB_RULES.get(rule_id, rule_id)


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
	# ICRA World 5-9, section 5.
	"king": ["goal"],
	"river": ["topology"],
	"carpet": ["goal"],
	"ko": ["history"],
	"heavy": ["topology"],
	"elements": ["colour"],
	"sum": ["goal"],
	"turns": ["history", "colour"],
	"kintsugi": ["local"],
	"lamp": ["history"],
	"solitaire": ["local"],
}
## Categories a combination may hold only one mode of (section 4.2, rule 1).
const EXCLUSIVE: Array[String] = ["hidden", "topology", "colour", "history", "layout", "goal", "compound"]


## The chapter that holds main road `position`, or {}.
static func chapter_at(position: int) -> Dictionary:
	for chapter: Dictionary in CHAPTERS:
		if position >= chapter["first"] and position <= chapter["last"]:
			return chapter
	return {}


## The world of main road `position`, or 0 past the plan.
static func world_at(position: int) -> int:
	return int(chapter_at(position).get("world", 0))


## The fewest moves a level of `world` may take (WORLD_FLOORS; intros aside).
static func world_floor(world: int) -> int:
	return WORLD_FLOORS[clampi(world, 1, WORLD_FLOORS.size()) - 1]


## The move range of `band` in a world whose floor is `floor_moves`: lifted
## to the floor where it lies lower, at least FLOOR_BAND_WIDTH wide.
static func band_range(band: String, floor_moves: int) -> Array[int]:
	var low: int = maxi(int(BANDS[band][0]), floor_moves)
	return [low, maxi(int(BANDS[band][1]), low + FLOOR_BAND_WIDTH)]


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
