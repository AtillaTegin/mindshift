class_name Difficulty
extends RefCounted
## Difficulty tiers (spec 4.4). Hard and Expert were adjusted on 2026-10-06
## because the original rows cannot be met: 4 pegs / 6 disks never needs more
## than 17 moves, 4 pegs / 8 disks never more than 33, 5 pegs / 10 disks never
## more than 31. Move ranges were retuned by the economy/UX addendum (section
## 1.1): easy 5-11, medium 12-20, hard 21-33, expert 34+.
##
## Tiers are internal (level structure addendum v3): they drive generation,
## the order of the level path and hint prices, but the player never sees them.

const ORDER: Array[String] = ["easy", "medium", "hard", "expert"]
const MAX_LEVELS_PER_TIER: int = 999
const LEVELS_DIR: String = "res://data/levels"

## Inclusive ranges; max_moves -1 means no upper bound. Level ids of a tier run
## from first_id to first_id + MAX_LEVELS_PER_TIER - 1. `count`: classic levels
## the generator makes by default (addendum v3, section 1: few easy levels,
## medium and hard as the body, expert as a side branch).
## Easy (level structure v4, section 1): 3-disk levels only open the road, so
## the generator draws `draw` easy levels as it always did and keeps only the
## first `small_keep` of those with `small_disks` disks; the tutorial levels and
## every 4-disk level stay the same.
const TIERS: Dictionary = {
	"easy": {"min_moves": 5, "max_moves": 11, "min_pegs": 3, "max_pegs": 3,
			"min_disks": 3, "max_disks": 4, "first_id": 1001, "count": 16,
			"draw": 22, "small_disks": 3, "small_keep": 4},
	"medium": {"min_moves": 12, "max_moves": 20, "min_pegs": 3, "max_pegs": 4,
			"min_disks": 5, "max_disks": 6, "first_id": 2001, "count": 76},
	"hard": {"min_moves": 21, "max_moves": 33, "min_pegs": 4, "max_pegs": 4,
			"min_disks": 7, "max_disks": 8, "first_id": 3001, "count": 74},
	"expert": {"min_moves": 34, "max_moves": -1, "min_pegs": 4, "max_pegs": 4,
			"min_disks": 9, "max_disks": 10, "first_id": 4001, "count": 28},
}

## Levels with a special mechanic (Nine Rings, covered pegs, ...) are ordinary
## path levels: their difficulty is the tier their min_moves falls in, but
## their size may differ from the classic tier sizes (the Nine Rings only
## matter on 4 pegs). They live in data/levels/mechanics/.
const MECHANICS: String = "mechanics"
const MECHANIC_FIRST_ID: int = 9001
const MECHANIC_MAX_LEVELS: int = 999
const MECHANIC_MIN_PEGS: int = 3
const MECHANIC_MAX_PEGS: int = 5
const MECHANIC_MIN_DISKS: int = 3
const MECHANIC_MAX_DISKS: int = 10
## "Birləşmə Tapmacası" levels (CombinationRule, mechanic "combination") grow
## with their place on the road (correction v3, replacing v2's table): a peg
## holds at most COMBINATION_MAX_CAPACITY disks, and boards grow by colours
## C (N disks of each) and so by pegs T = C + E. The empty pegs E are not
## chosen but measured: E = COMBINATION_E_MIN, the fewest with which random
## starts are solvable (tools/combination_e_min.gd). Each stage gives the
## capacity and colour ranges and the tier (hint price; easy only while
## learning). Their min_moves is the length of a known solution, not a proven
## minimum (user decision 2026-10-13), so the tier comes from the stage.
const COMBINATION: String = "combination"
const COMBINATION_MAX_CAPACITY: int = 7
const COMBINATION_MAX_PEGS: int = 12
const COMBINATION_MAX_DISKS: int = 70
const COMBINATION_STAGES: Array[Dictionary] = [
	{"name": "intro", "to": 30, "tier": "easy", "capacity": [4, 4], "colours": [2, 2]},
	{"name": "middle_1", "to": 80, "tier": "medium", "capacity": [5, 5], "colours": [3, 3]},
	{"name": "middle_2", "to": 130, "tier": "medium", "capacity": [6, 6], "colours": [3, 4]},
	{"name": "hard_1", "to": 200, "tier": "hard", "capacity": [7, 7], "colours": [4, 6]},
	{"name": "hard_2", "to": 280, "tier": "hard", "capacity": [7, 7], "colours": [6, 8]},
	{"name": "expert", "to": 100000, "tier": "expert", "capacity": [7, 7], "colours": [8, 10]},
]
## E_min by "CxN" (colours x capacity), measured 2026-10-13 with
## tools/combination_e_min.gd: the first E at which at least 6 of 8 random
## starts were solved (exhaustive search up to 12 disks, guided search with a
## budget of 40000 positions beyond).
const COMBINATION_E_MIN: Dictionary = {
	"2x4": 1, "3x4": 1, "3x5": 1, "3x6": 1, "4x6": 1, "4x7": 1, "5x7": 1, "6x7": 2, "7x7": 2, "8x7": 2, "9x7": 3,
}
## "Konkret Kombinasiya" only on small boards (correction v3, section 1).
const PATTERN_MAX_COLOURS: int = 3
const PATTERN_MAX_PEGS: int = 5


## The measured E_min for `colours` x `capacity`, or 0 if it was not measured.
static func combination_empty(colours: int, capacity: int) -> int:
	return COMBINATION_E_MIN.get("%dx%d" % [colours, capacity], 0)


## Whether a board of `colours` and `pegs` may have a pattern goal.
static func allows_pattern(colours: int, pegs: int) -> bool:
	return colours <= PATTERN_MAX_COLOURS and pegs <= PATTERN_MAX_PEGS


## The combination stage of main path position `position`.
static func combination_stage(position: int) -> Dictionary:
	for stage: Dictionary in COMBINATION_STAGES:
		if position <= stage["to"]:
			return stage
	return COMBINATION_STAGES[-1]


static func is_known(tier: String) -> bool:
	return TIERS.has(tier)


## The tier's settings, or an empty Dictionary for an unknown tier.
static func get_tier(tier: String) -> Dictionary:
	return TIERS.get(tier, {})


## Classic levels of `tier` the generator makes by default.
static func default_count(tier: String) -> int:
	return int(get_tier(tier).get("count", 0))


## Levels the generator draws for `tier` before LevelGenerator.keep_small().
static func draw_count(tier: String) -> int:
	return int(get_tier(tier).get("draw", default_count(tier)))


## Whether `moves` fall in `tier`'s range. A combination level (`mechanic`
## COMBINATION) takes its tier from its stage on the road, whatever its length
## (LevelValidator.validate_path checks the stage).
static func accepts_moves(tier: String, moves: int, mechanic: String = "") -> bool:
	if mechanic == COMBINATION:
		return is_known(tier) and moves >= 1
	var settings: Dictionary = get_tier(tier)
	if settings.is_empty() or moves < settings["min_moves"]:
		return false
	return settings["max_moves"] == -1 or moves <= settings["max_moves"]


## The tier whose move range holds `moves`, or "" below the easiest tier.
static func tier_for_moves(moves: int) -> String:
	for tier: String in ORDER:
		if accepts_moves(tier, moves):
			return tier
	return ""


static func accepts_size(tier: String, peg_count: int, disk_count: int) -> bool:
	var settings: Dictionary = get_tier(tier)
	return not settings.is_empty() \
			and peg_count >= settings["min_pegs"] and peg_count <= settings["max_pegs"] \
			and disk_count >= settings["min_disks"] and disk_count <= settings["max_disks"]


static func accepts_id(tier: String, id: int) -> bool:
	var settings: Dictionary = get_tier(tier)
	return not settings.is_empty() and id >= settings["first_id"] \
			and id < settings["first_id"] + MAX_LEVELS_PER_TIER


static func is_mechanic_id(id: int) -> bool:
	return id >= MECHANIC_FIRST_ID and id < MECHANIC_FIRST_ID + MECHANIC_MAX_LEVELS


static func accepts_mechanic_size(peg_count: int, disk_count: int, mechanic: String = "") -> bool:
	var max_pegs: int = COMBINATION_MAX_PEGS if mechanic == COMBINATION else MECHANIC_MAX_PEGS
	var max_disks: int = COMBINATION_MAX_DISKS if mechanic == COMBINATION else MECHANIC_MAX_DISKS
	return peg_count >= MECHANIC_MIN_PEGS and peg_count <= max_pegs \
			and disk_count >= MECHANIC_MIN_DISKS and disk_count <= max_disks


## Tier of a classic level id, or "" if the id belongs to no tier (mechanic ids included).
static func tier_of_id(id: int) -> String:
	for tier: String in ORDER:
		if accepts_id(tier, id):
			return tier
	return ""


## 1-based position of a level inside its tier (also its file number).
static func index_of_id(id: int) -> int:
	var tier: String = tier_of_id(id)
	return id - int(TIERS[tier]["first_id"]) + 1 if not tier.is_empty() else -1


static func id_for(tier: String, index: int) -> int:
	return int(TIERS[tier]["first_id"]) + index - 1


## File name of the `index`-th level (1-based) of a tier, e.g. "easy_007.json".
static func level_file_name(tier: String, index: int) -> String:
	return "%s_%03d.json" % [tier, index]


static func level_path(tier: String, index: int, levels_dir: String = LEVELS_DIR) -> String:
	return "%s/%s/%s" % [levels_dir, tier, level_file_name(tier, index)]


## Human-readable move range, e.g. "5-11" or "34+".
static func describe_moves(tier: String) -> String:
	var settings: Dictionary = get_tier(tier)
	if settings["max_moves"] == -1:
		return "%d+" % settings["min_moves"]
	return "%d-%d" % [settings["min_moves"], settings["max_moves"]]
