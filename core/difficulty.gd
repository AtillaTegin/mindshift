class_name Difficulty
extends RefCounted
## Difficulty tiers (spec 4.4). Hard and Expert were adjusted on 2026-10-06
## because the original rows cannot be met: 4 pegs / 6 disks never needs more
## than 17 moves, 4 pegs / 8 disks never more than 33, 5 pegs / 10 disks never
## more than 31. Move ranges were retuned by the economy/UX addendum (section
## 1.1): easy 5-11, medium 12-20, hard 21-33, expert 34+.
##
## Tiers are internal (level structure addendum v3): they drive hint prices
## and the "· Ekspert" mark on the islands, but the player never sees them.
## Since the chapter system (2026-10-15) a level's tier is only the range its
## min_moves falls in; its board comes from its band in the chapter
## (ChapterPlan.BANDS, tools/road_builder.gd).

const ORDER: Array[String] = ["easy", "medium", "hard", "expert"]
const MAX_LEVELS_PER_TIER: int = 999
const LEVELS_DIR: String = "res://data/levels"

## Inclusive ranges; max_moves -1 means no upper bound. Level ids of a tier run
## from first_id to first_id + MAX_LEVELS_PER_TIER - 1.
const TIERS: Dictionary = {
	"easy": {"min_moves": 5, "max_moves": 11, "first_id": 1001},
	"medium": {"min_moves": 12, "max_moves": 20, "first_id": 2001},
	"hard": {"min_moves": 21, "max_moves": 33, "first_id": 3001},
	"expert": {"min_moves": 34, "max_moves": -1, "first_id": 4001},
}
## Boards of classic levels, whatever their tier.
const CLASSIC_MIN_PEGS: int = 3
const CLASSIC_MAX_PEGS: int = 5
const CLASSIC_MIN_DISKS: int = 3
const CLASSIC_MAX_DISKS: int = 10

## Levels with a special mechanic (Nine Rings, covered pegs, ...) are ordinary
## path levels: their difficulty is the tier their min_moves falls in, but
## their size may differ from the classic tier sizes (the Nine Rings only
## matter on 4 pegs). They live in data/levels/mechanics/, each mode and each
## combination in its own block of ids (RoadBuilder.id_block()).
const MECHANICS: String = "mechanics"
const MECHANIC_FIRST_ID: int = 10001
const MECHANIC_MAX_LEVELS: int = 89999
const MECHANIC_MIN_PEGS: int = 3
const MECHANIC_MAX_PEGS: int = 5
const MECHANIC_MIN_DISKS: int = 3
const MECHANIC_MAX_DISKS: int = 10
## "Böyük Mübadilə" v2 levels (ColorSwapRule, mechanic "color_swap"): k white
## and k black disks on the two end pegs with B empty pegs between them. Up to
## 4 buffers (6 pegs, one row) and 8 disks: an off-path hint on 6 pegs / 8
## disks takes up to 3.2 s on a desktop, 5 pegs / 10 disks 4.6 s and 6 pegs /
## 10 disks 22 s (measured 2026-10-14), too long for an in-game hint.
const COLOR_SWAP: String = "color_swap"
## Mechanics whose boards may leave MECHANIC_MAX_PEGS / MECHANIC_MAX_DISKS:
## mechanic -> {max_pegs, max_disks}.
const MECHANIC_SIZES: Dictionary = {
	COLOR_SWAP: {"max_pegs": 6, "max_disks": 8},
	# Two 3-peg boards (MirrorRule).
	"mirror": {"max_pegs": 6, "max_disks": 10},
}


static func is_known(tier: String) -> bool:
	return TIERS.has(tier)


## The tier's settings, or an empty Dictionary for an unknown tier.
static func get_tier(tier: String) -> Dictionary:
	return TIERS.get(tier, {})


## Whether `moves` fall in `tier`'s range.
static func accepts_moves(tier: String, moves: int) -> bool:
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


static func accepts_classic_size(peg_count: int, disk_count: int) -> bool:
	return peg_count >= CLASSIC_MIN_PEGS and peg_count <= CLASSIC_MAX_PEGS \
			and disk_count >= CLASSIC_MIN_DISKS and disk_count <= CLASSIC_MAX_DISKS


static func accepts_id(tier: String, id: int) -> bool:
	var settings: Dictionary = get_tier(tier)
	return not settings.is_empty() and id >= settings["first_id"] \
			and id < settings["first_id"] + MAX_LEVELS_PER_TIER


static func is_mechanic_id(id: int) -> bool:
	return id >= MECHANIC_FIRST_ID and id < MECHANIC_FIRST_ID + MECHANIC_MAX_LEVELS


static func accepts_mechanic_size(peg_count: int, disk_count: int, mechanic: String = "") -> bool:
	var sizes: Dictionary = MECHANIC_SIZES.get(mechanic, {})
	return peg_count >= MECHANIC_MIN_PEGS and peg_count <= sizes.get("max_pegs", MECHANIC_MAX_PEGS) \
			and disk_count >= MECHANIC_MIN_DISKS and disk_count <= sizes.get("max_disks", MECHANIC_MAX_DISKS)


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
