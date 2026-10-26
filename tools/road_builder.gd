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
const BUILT_WORLDS: Array[int] = [1, 2, 3, 4]
## Draws per level before its board gives way to the next recipe board, and
## fitting draws compared for the move count the group has least
## (draw_group()); a draw with a count not seen yet wins at once.
const ATTEMPTS_PER_LEVEL: int = 600
const CANDIDATES: int = 3
## One level's budget: past FIRST_SECONDS (or LEVEL_TRIES) the smaller boards
## get the rest of LEVEL_SECONDS (the floor stays) and the weak spot goes to the
## log. The Solver stops at the deadline mid-search (Solver.deadline_msec).
const LEVEL_SECONDS: float = 60.0
const FIRST_SECONDS: float = 40.0
const LEVEL_TRIES: int = 3000
## Attempts the last draw_one() used, for the progress log.
static var last_tries: int = 0
## `-- --trial=N`: draw only the first N wave levels of the last world, write nothing.
static var trial_limit: int = 0
## `-- --only=<selectors>` with --trial: see _trial().
static var only: String = ""
## Drawn levels go to checkpoint_path every CHECKPOINT_EVERY wave levels and after
## each band group; `-- --resume` takes them back and draws only the rest.
static var checkpoint_path: String = "res://.road_checkpoint.json"
const CHECKPOINT_EVERY: int = 10
static var resume: bool = false
static var _unsaved: int = 0
## Sub-elements that rarely make a level in a window (World 3-4, measured
## 2026-10-17: a narrow bridge or a one-way road on a line, the figure eight,
## a neutral disk or a coloured base about 1 draw in 30), and how many times
## the attempts their levels get.
const SCARCE: Dictionary = {"bridge": 4, "one_way": 3, "eight": 3, "neutral": 2, "colored_base": 2}
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
## The RECIPES entries of a stream's boards for wave intros only and for its
## chapter's Böyük Sınaq only (draw_one()).
const INTRO: String = "intro"
const BIG_TEST_BOARDS: String = "big_test"
## File name stem of each mode's levels (data/levels/mechanics/<stem>_NNN.json);
## a combination's files join its modes' stems.
const MODE_FILES: Dictionary = {"peg_capacity": "capacity", "covered_pegs": "fog", "foundation": "foundation",
	"adjacent_pegs": "caravan", "stripes": "stripes", "cyclic": "cyclic", "alternation": "rings", "balance": "balance",
	"color_swap": "swap", "trail": "trail", "chain": "chain", "mirror": "mirror", "linked_pegs": "linked",
	"magnet": "magnet", "king": "king", "river": "river", "carpet": "carpet", "ko": "ko", "heavy": "heavy",
	"elements": "elements", "sum": "sum", "turns": "turns", "kintsugi": "kintsugi", "lamp": "lamp",
	"solitaire": "solitaire"}
## Mechanic level ids: each mode, then each combination of the whitelist,
## owns a block of ID_BLOCK ids from Difficulty.MECHANIC_FIRST_ID; modes past
## the first COMBO_FIRST_BLOCK take the blocks from LATE_MODE_FIRST_BLOCK on.
const ID_BLOCK: int = 1000
const COMBO_FIRST_BLOCK: int = 20
const LATE_MODE_FIRST_BLOCK: int = 80

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
	# Current decisions 2026-10-16, B.4: karakuri levels on 4-5 pegs and 6-9
	# disks, but each wave's intro (INTRO boards) and the island (the waves doc:
	# "not inside the chapter"; its 34-70 moves need 3 pegs). Measured
	# 2026-10-17: 5 pegs stay short (6 disks up to 14 moves, 7 up to 16), so 5
	# pegs only with 8 disks; a sealed box on 4 pegs / 9 disks takes ~4 s a draw
	# and up to 2.3 s for an off-path hint, so sealed levels try 8 disks first
	# (draw_one()) and the Böyük Sınaq has its own boards (BIG_TEST_BOARDS).
	"covered_pegs": {
		INTRO: [{"pegs": 3, "disks": 4, "covered": 1}, {"pegs": 4, "disks": 5, "covered": 1},
			{"pegs": 3, "disks": 5, "covered": 1}],
		"easy_medium": [{"pegs": 4, "disks": 6, "covered": 1}, {"pegs": 4, "disks": 7, "covered": 1},
			{"pegs": 5, "disks": 8, "covered": 1}],
		"medium": [{"pegs": 4, "disks": 7, "covered": 2}, {"pegs": 4, "disks": 6, "covered": 2},
			{"pegs": 5, "disks": 8, "covered": 2}],
		"medium_hard": [{"pegs": 4, "disks": 8, "covered": 2}, {"pegs": 4, "disks": 7, "covered": 2},
			{"pegs": 4, "disks": 9, "covered": 2}],
		"hard": [{"pegs": 4, "disks": 8, "covered": 2}, {"pegs": 4, "disks": 9, "covered": 2}],
		BIG_TEST_BOARDS: [{"pegs": 4, "disks": 9, "covered": 2}],
		# The island: 3 pegs reach its lengths, and a sealed box on 4 pegs / 9
		# disks made an off-path hint take ~5 s (measured 2026-10-16).
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
	# World 3-4 (MindShift_Dunya3-4_Alt_Elementler_v1.md), measured 2026-10-17.
	# Base boards: an oasis or a centre adds a peg, the figure eight makes the
	# count odd, three scales take six (LevelForge.fitted()).
	# Caravan road: 4-5 stops, 5-6 disks reach every window (a tunnel stays
	# under ~26, so its levels lean on the larger boards).
	"adjacent_pegs": {
		INTRO: [{"pegs": 4, "disks": 4}, {"pegs": 4, "disks": 5}],
		"easy_medium": [{"pegs": 4, "disks": 5}, {"pegs": 5, "disks": 5}],
		"medium": [{"pegs": 4, "disks": 5}, {"pegs": 5, "disks": 5}, {"pegs": 4, "disks": 6}],
		"medium_hard": [{"pegs": 5, "disks": 5}, {"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
		"hard": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
		BIG_TEST_BOARDS: [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
		"expert": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
	},
	# Stripes: 3 pegs never change a tower, 7-8 disks on 4 pegs reach the
	# windows (5 pegs stay short); a paint peg on 8 disks takes ~4 s a draw.
	"stripes": {
		INTRO: [{"pegs": 4, "disks": 6}, {"pegs": 4, "disks": 7}],
		"easy_medium": [{"pegs": 4, "disks": 7}],
		"medium": [{"pegs": 4, "disks": 7}, {"pegs": 4, "disks": 8}],
		"medium_hard": [{"pegs": 4, "disks": 8}, {"pegs": 4, "disks": 7}],
		"hard": [{"pegs": 4, "disks": 8}],
		BIG_TEST_BOARDS: [{"pegs": 4, "disks": 8}, {"pegs": 4, "disks": 9}],
		"expert": [{"pegs": 4, "disks": 9}],
	},
	# The dial: 4-5 pegs, 5-6 disks; on 3 pegs the back step and the shortcut
	# are the same move, so 4 pegs at least.
	"cyclic": {
		INTRO: [{"pegs": 4, "disks": 4}, {"pegs": 4, "disks": 5}],
		"easy_medium": [{"pegs": 4, "disks": 5}, {"pegs": 5, "disks": 5}],
		"medium": [{"pegs": 4, "disks": 5}, {"pegs": 5, "disks": 5}],
		"medium_hard": [{"pegs": 4, "disks": 5}, {"pegs": 5, "disks": 5}, {"pegs": 4, "disks": 6}],
		"hard": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 5}, {"pegs": 5, "disks": 6}],
		BIG_TEST_BOARDS: [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
		"expert": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 5}, {"pegs": 5, "disks": 6}],
	},
	# The Nine Rings: 4 pegs (the rule matters reliably there), 6-8 disks.
	"alternation": {
		INTRO: [{"pegs": 4, "disks": 5}, {"pegs": 4, "disks": 6}],
		"easy_medium": [{"pegs": 4, "disks": 6}, {"pegs": 4, "disks": 7}],
		"medium": [{"pegs": 4, "disks": 7}, {"pegs": 4, "disks": 6}],
		"medium_hard": [{"pegs": 4, "disks": 7}, {"pegs": 4, "disks": 8}],
		"hard": [{"pegs": 4, "disks": 8}],
		BIG_TEST_BOARDS: [{"pegs": 4, "disks": 8}, {"pegs": 4, "disks": 9}],
		"expert": [{"pegs": 4, "disks": 9}, {"pegs": 4, "disks": 8}],
	},
	# The scales: 2 scales of 6-7 disks, the limit drawn in the range where the
	# rule works on the board (user decision 2026-10-15); three scales on 6
	# pegs. The goal is taken at the window's distance (LevelForge).
	"balance": {
		INTRO: [{"pegs": 4, "disks": 5, "tolerance": [3, 7]}, {"pegs": 4, "disks": 6, "tolerance": [4, 8]}],
		"easy_medium": [{"pegs": 4, "disks": 6, "tolerance": [4, 8]}, {"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
		"medium": [{"pegs": 4, "disks": 6, "tolerance": [4, 8]}, {"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
		"medium_hard": [{"pegs": 4, "disks": 7, "tolerance": [5, 9]}, {"pegs": 4, "disks": 6, "tolerance": [4, 8]}],
		"hard": [{"pegs": 4, "disks": 7, "tolerance": [5, 9]}, {"pegs": 4, "disks": 6, "tolerance": [4, 8]}],
		BIG_TEST_BOARDS: [{"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
		"expert": [{"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
	},
	# World 3-4 combinations (the chapter plan's whitelist), measured in the
	# build: each must be longer than either mode alone.
	"peg_capacity+adjacent_pegs": {
		"easy_medium": [{"pegs": 4, "disks": 5, "slack": 1}],
		"medium": [{"pegs": 4, "disks": 5, "slack": 1}, {"pegs": 4, "disks": 6, "slack": 1}],
		"medium_hard": [{"pegs": 4, "disks": 6, "slack": 1}, {"pegs": 5, "disks": 6, "slack": 1}],
		"hard": [{"pegs": 4, "disks": 6, "slack": 1}, {"pegs": 5, "disks": 6, "slack": 1}],
		"expert": [{"pegs": 4, "disks": 6, "slack": 1}, {"pegs": 5, "disks": 6, "slack": 1}],
	},
	"foundation+adjacent_pegs": {
		"easy_medium": [{"pegs": 4, "disks": 5, "locked": 1, "keys": 2}],
		"medium": [{"pegs": 4, "disks": 5, "locked": 1, "keys": 2}, {"pegs": 4, "disks": 6, "locked": 2, "keys": 2}],
		"medium_hard": [{"pegs": 4, "disks": 6, "locked": 2, "keys": 2}, {"pegs": 5, "disks": 5, "locked": 1, "keys": 2}],
		"hard": [{"pegs": 4, "disks": 6, "locked": 2, "keys": 3}, {"pegs": 5, "disks": 6, "locked": 2, "keys": 2}],
		"expert": [{"pegs": 4, "disks": 6, "locked": 2, "keys": 3}, {"pegs": 5, "disks": 6, "locked": 2, "keys": 2}],
	},
	"peg_capacity+stripes": {
		"easy_medium": [{"pegs": 4, "disks": 7, "slack": 1}],
		"medium": [{"pegs": 4, "disks": 7, "slack": 1}],
		"medium_hard": [{"pegs": 4, "disks": 7, "slack": 1}, {"pegs": 4, "disks": 8, "slack": 1}],
		"hard": [{"pegs": 4, "disks": 8, "slack": 1}],
		"expert": [{"pegs": 4, "disks": 8, "slack": 1}],
	},
	"adjacent_pegs+stripes": {
		"easy_medium": [{"pegs": 4, "disks": 5}, {"pegs": 4, "disks": 6}],
		"medium": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
		"medium_hard": [{"pegs": 4, "disks": 6}, {"pegs": 4, "disks": 7}],
		"hard": [{"pegs": 4, "disks": 7}, {"pegs": 5, "disks": 6}],
		"expert": [{"pegs": 4, "disks": 7}],
	},
	"peg_capacity+cyclic": {
		"easy_medium": [{"pegs": 4, "disks": 5, "slack": 1}],
		"medium": [{"pegs": 4, "disks": 5, "slack": 1}],
		"medium_hard": [{"pegs": 4, "disks": 5, "slack": 1}, {"pegs": 4, "disks": 6, "slack": 1}],
		"hard": [{"pegs": 4, "disks": 6, "slack": 1}],
		"expert": [{"pegs": 4, "disks": 6, "slack": 1}],
	},
	"foundation+cyclic": {
		"easy_medium": [{"pegs": 4, "disks": 5, "locked": 1, "keys": 2}],
		"medium": [{"pegs": 4, "disks": 5, "locked": 1, "keys": 2}],
		"medium_hard": [{"pegs": 4, "disks": 5, "locked": 1, "keys": 2}, {"pegs": 4, "disks": 6, "locked": 2, "keys": 2}],
		"hard": [{"pegs": 4, "disks": 6, "locked": 2, "keys": 2}],
		"expert": [{"pegs": 4, "disks": 6, "locked": 2, "keys": 3}],
	},
	"covered_pegs+stripes": {
		"easy_medium": [{"pegs": 4, "disks": 7, "covered": 1}],
		"medium": [{"pegs": 4, "disks": 7, "covered": 1}, {"pegs": 4, "disks": 8, "covered": 1}],
		"medium_hard": [{"pegs": 4, "disks": 8, "covered": 2}, {"pegs": 4, "disks": 7, "covered": 2}],
		"hard": [{"pegs": 4, "disks": 8, "covered": 2}],
		"expert": [{"pegs": 4, "disks": 8, "covered": 2}],
	},
	"peg_capacity+alternation": {
		"easy_medium": [{"pegs": 4, "disks": 6, "slack": 1}],
		"medium": [{"pegs": 4, "disks": 6, "slack": 1}, {"pegs": 4, "disks": 7, "slack": 1}],
		"medium_hard": [{"pegs": 4, "disks": 7, "slack": 1}],
		"hard": [{"pegs": 4, "disks": 7, "slack": 1}, {"pegs": 4, "disks": 8, "slack": 1}],
		"expert": [{"pegs": 4, "disks": 8, "slack": 1}],
	},
	"peg_capacity+balance": {
		"easy_medium": [{"pegs": 4, "disks": 6, "slack": 1, "tolerance": [4, 8]}],
		"medium": [{"pegs": 4, "disks": 6, "slack": 1, "tolerance": [4, 8]}, {"pegs": 4, "disks": 7, "slack": 1, "tolerance": [5, 9]}],
		"medium_hard": [{"pegs": 4, "disks": 7, "slack": 1, "tolerance": [5, 9]}],
		"hard": [{"pegs": 4, "disks": 7, "slack": 1, "tolerance": [5, 9]}],
		"expert": [{"pegs": 4, "disks": 7, "slack": 1, "tolerance": [5, 9]}],
	},
	"foundation+balance": {
		"easy_medium": [{"pegs": 4, "disks": 6, "locked": 1, "keys": 2, "tolerance": [4, 8]}],
		"medium": [{"pegs": 4, "disks": 6, "locked": 1, "keys": 2, "tolerance": [4, 8]},
			{"pegs": 4, "disks": 7, "locked": 2, "keys": 2, "tolerance": [5, 9]}],
		"medium_hard": [{"pegs": 4, "disks": 7, "locked": 2, "keys": 2, "tolerance": [5, 9]}],
		"hard": [{"pegs": 4, "disks": 7, "locked": 2, "keys": 3, "tolerance": [5, 9]}],
		"expert": [{"pegs": 4, "disks": 7, "locked": 2, "keys": 3, "tolerance": [5, 9]}],
	},
	"stripes+balance": {
		"easy_medium": [{"pegs": 4, "disks": 6, "tolerance": [4, 8]}],
		"medium": [{"pegs": 4, "disks": 6, "tolerance": [4, 8]}, {"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
		"medium_hard": [{"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
		"hard": [{"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
		"expert": [{"pegs": 4, "disks": 7, "tolerance": [5, 9]}],
	},
	"covered_pegs+balance": {
		"easy_medium": [{"pegs": 4, "disks": 6, "covered": 1, "tolerance": [4, 8]}],
		"medium": [{"pegs": 4, "disks": 6, "covered": 1, "tolerance": [4, 8]}, {"pegs": 4, "disks": 7, "covered": 2, "tolerance": [5, 9]}],
		"medium_hard": [{"pegs": 4, "disks": 7, "covered": 2, "tolerance": [5, 9]}],
		"hard": [{"pegs": 4, "disks": 7, "covered": 2, "tolerance": [5, 9]}],
		"expert": [{"pegs": 4, "disks": 7, "covered": 2, "tolerance": [5, 9]}],
	},
	# World 5 (ICRA World 5-9), measured 2026-10-17. Kral: on 4-5 pegs the
	# king gets out at once (4 pegs / 10 disks: 12-17 moves, below the world's
	# floor of 18; the vizier and the narrow gate up to ~24), on 3 pegs 6
	# disks take 12-32 moves and 7 disks 25-64, so most boards have 3 pegs.
	"king": {
		INTRO: [{"pegs": 3, "disks": 5}, {"pegs": 3, "disks": 6}],
		"easy_medium": [{"pegs": 3, "disks": 6}, {"pegs": 4, "disks": 9}],
		"medium": [{"pegs": 3, "disks": 6}, {"pegs": 4, "disks": 9}],
		"medium_hard": [{"pegs": 3, "disks": 6}, {"pegs": 3, "disks": 7}, {"pegs": 4, "disks": 9}],
		"hard": [{"pegs": 3, "disks": 7}, {"pegs": 3, "disks": 6}],
		BIG_TEST_BOARDS: [{"pegs": 3, "disks": 7}, {"pegs": 3, "disks": 8}],
		# The island (the king, the vizier and the narrow gate together): 4 pegs
		# / 9 disks 34-41 moves, 3 / 8 47-65.
		"expert": [{"pegs": 4, "disks": 9}, {"pegs": 3, "disks": 8}],
	},
	# Fil Çayı: the river lengthens a solution only where a stack moves on a
	# bank of three pegs, so 5-6 pegs (2 + 3 or 3 + 3); 5 pegs / 7 disks take
	# 13-34 moves, 6 / 7 12-34, 5 / 8 21-65; the stone bridge also works on 4
	# pegs, the ferry stays under ~22, the bonfire is 33-34 on 5 / 7 and 65 on
	# 5 / 8.
	"river": {
		INTRO: [{"pegs": 5, "disks": 6}, {"pegs": 5, "disks": 7}],
		"easy_medium": [{"pegs": 5, "disks": 7}, {"pegs": 6, "disks": 7}, {"pegs": 4, "disks": 7}],
		"medium": [{"pegs": 5, "disks": 7}, {"pegs": 6, "disks": 7}, {"pegs": 4, "disks": 7}],
		"medium_hard": [{"pegs": 5, "disks": 7}, {"pegs": 6, "disks": 7}, {"pegs": 5, "disks": 8}],
		"hard": [{"pegs": 5, "disks": 7}, {"pegs": 6, "disks": 7}, {"pegs": 5, "disks": 8}],
		BIG_TEST_BOARDS: [{"pegs": 5, "disks": 8}, {"pegs": 6, "disks": 8}],
		"expert": [{"pegs": 5, "disks": 7}, {"pegs": 6, "disks": 8}, {"pegs": 5, "disks": 8}],
	},
	# Combination IV (World 5), measured 2026-10-17. A capacity that matters
	# beside the river's or the exchange's stacks is cut from their own
	# shortest solution ("cut", LevelForge._cut_capacities): the exchange with
	# capacity then makes 26 moves on 5 pegs / 8 disks (13 of 40 draws, hints
	# up to 1.8 s), the river with capacity still only 4 of 120 draws (14-15
	# moves, below the world's floor), and the exchange on the caravan road has
	# no solution at all (two disks of one size can never pass each other on a
	# line). Places a combination cannot fill go to the chapter's other
	# combinations (_draw_bands()).
	"peg_capacity+river": {
		"medium": [{"pegs": 5, "disks": 7, "cut": true}, {"pegs": 6, "disks": 7, "cut": true}],
		"medium_hard": [{"pegs": 5, "disks": 7, "cut": true}, {"pegs": 6, "disks": 7, "cut": true}],
		"hard": [{"pegs": 5, "disks": 7, "cut": true}],
		"expert": [{"pegs": 5, "disks": 8, "cut": true}],
	},
	"covered_pegs+river": {
		"easy_medium": [{"pegs": 5, "disks": 7, "covered": 1}, {"pegs": 5, "disks": 6, "covered": 1}],
		"medium": [{"pegs": 5, "disks": 7, "covered": 1}, {"pegs": 6, "disks": 7, "covered": 1}],
		"medium_hard": [{"pegs": 5, "disks": 7, "covered": 2}, {"pegs": 6, "disks": 7, "covered": 2}],
		"hard": [{"pegs": 5, "disks": 7, "covered": 2}, {"pegs": 6, "disks": 7, "covered": 2}],
		"expert": [{"pegs": 5, "disks": 8, "covered": 2}],
	},
	"foundation+river": {
		"easy_medium": [{"pegs": 5, "disks": 6, "locked": 1, "keys": 2}],
		"medium": [{"pegs": 5, "disks": 6, "locked": 1, "keys": 2}, {"pegs": 5, "disks": 7, "locked": 1, "keys": 2}],
		"medium_hard": [{"pegs": 5, "disks": 7, "locked": 1, "keys": 2}, {"pegs": 5, "disks": 6, "locked": 2, "keys": 2}],
		"hard": [{"pegs": 5, "disks": 7, "locked": 2, "keys": 2}],
		"expert": [{"pegs": 5, "disks": 7, "locked": 2, "keys": 3}],
	},
	"adjacent_pegs+color_swap": {
		"medium": [{"pegs": 4, "disks": 6}], "medium_hard": [{"pegs": 4, "disks": 6}], "hard": [{"pegs": 4, "disks": 6}],
		"expert": [{"pegs": 4, "disks": 6}],
	},
	"peg_capacity+color_swap": {
		"medium": [{"pegs": 5, "disks": 8, "cut": true}],
		"medium_hard": [{"pegs": 5, "disks": 8, "cut": true}],
		"hard": [{"pegs": 5, "disks": 8, "cut": true}],
		"expert": [{"pegs": 5, "disks": 8, "cut": true}],
	},
	"adjacent_pegs+king": {
		"easy_medium": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
		"medium": [{"pegs": 4, "disks": 6}, {"pegs": 4, "disks": 7}, {"pegs": 5, "disks": 7}],
		"medium_hard": [{"pegs": 4, "disks": 7}, {"pegs": 5, "disks": 7}, {"pegs": 4, "disks": 8}],
		"hard": [{"pegs": 4, "disks": 7}, {"pegs": 4, "disks": 8}, {"pegs": 5, "disks": 7}],
		"expert": [{"pegs": 4, "disks": 8}, {"pegs": 4, "disks": 7}],
	},
	"cyclic+king": {
		"easy_medium": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}],
		"medium": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 6}, {"pegs": 4, "disks": 7}],
		"medium_hard": [{"pegs": 4, "disks": 7}, {"pegs": 5, "disks": 6}, {"pegs": 5, "disks": 7}],
		"hard": [{"pegs": 4, "disks": 7}, {"pegs": 5, "disks": 7}, {"pegs": 4, "disks": 8}],
		"expert": [{"pegs": 4, "disks": 7}, {"pegs": 5, "disks": 7}],
	},
	# Böyük Mübadilə: 4 pegs / 6 disks 15 (pure) to 22 moves (mixed), 5 / 8
	# 14-26 (mid-way, mixed, caravanserai), 4 / 8 28-31 pure and 32-48 mixed;
	# three caravans 5 / 9 (18-22). More buffers stay short.
	"color_swap": {
		INTRO: [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 9}],
		"easy_medium": [{"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 8}, {"pegs": 5, "disks": 9}],
		"medium": [{"pegs": 5, "disks": 8}, {"pegs": 4, "disks": 6}, {"pegs": 5, "disks": 9}],
		"medium_hard": [{"pegs": 5, "disks": 8}, {"pegs": 4, "disks": 8}, {"pegs": 5, "disks": 9}],
		"hard": [{"pegs": 4, "disks": 8}, {"pegs": 5, "disks": 8}, {"pegs": 5, "disks": 9}],
		BIG_TEST_BOARDS: [{"pegs": 4, "disks": 8}],
		"expert": [{"pegs": 4, "disks": 8}],
	},
}


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	var worlds: Array[int] = BUILT_WORLDS.duplicate()
	var keep: Array[int] = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--worlds="):
			worlds = parse_worlds(arg.trim_prefix("--worlds="))
		elif arg.begins_with("--keep="):
			keep = parse_worlds(arg.trim_prefix("--keep="))
		elif arg.begins_with("--trial="):
			trial_limit = arg.trim_prefix("--trial=").to_int()
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg == "--resume":
			resume = true
	var started: int = Time.get_ticks_msec()
	var errors: Array[String] = []
	if trial_limit > 0 and only != "":
		return _trial(worlds, keep, only, trial_limit)
	var road: Dictionary = build(worlds, errors, keep)
	if trial_limit > 0:
		print("trial: %d s" % [(Time.get_ticks_msec() - started) / 1000])
		return errors.is_empty()
	# Empty slots do not stop the writing (the work is kept); they are listed at the end.
	write(road, Difficulty.LEVELS_DIR)
	if errors.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(checkpoint_path))
	LevelCatalog.clear_cache()
	var report: Dictionary = LevelValidator.validate_directory(Difficulty.LEVELS_DIR)
	var failures: Dictionary = report["failures"]
	for path: String in failures:
		printerr("FAIL %s: %s" % [path, "; ".join(failures[path])])
	print(describe(road))
	print("%d levels in %d s" % [report["files"], (Time.get_ticks_msec() - started) / 1000])
	if not errors.is_empty():
		print("EMPTY SLOTS (%d), left out of the road:" % errors.size())
		for error: String in errors:
			printerr(error)
	return failures.is_empty() and errors.is_empty()


## `-- --trial=N --only=<selector>`: N levels of the last world's slots that
## `selector` names, each timed, nothing written. Selectors: a wave slot's
## name ("balance[own_limits,three_scales]"), "big_test:<mode>",
## "island:<mode>", "combo" (the world's combination chapter, its
## combinations spread to its Böyük Sınaq). Several: comma-free, joined by ";".
func _trial(worlds: Array[int], keep: Array[int], selectors: String, count: int) -> bool:
	var world: int = worlds.max()
	var plan: Dictionary = layout(worlds)
	var errors: Array[String] = []
	var used: Dictionary = {}
	var earlier: Array[int] = keep.filter(func(w: int) -> bool: return w != world)
	for kept: int in earlier:
		_keep_world(plan, kept, used, errors)
	var tracks: Array = [plan["main"]]
	for island: Dictionary in plan["islands"]:
		tracks.append(island["slots"])
	var good: bool = true
	for selector: String in selectors.split(";"):
		var picked: Array = []  # [track, index]
		for t: int in tracks.size():
			for i: int in (tracks[t] as Array).size():
				var slot: Dictionary = tracks[t][i]
				if slot["world"] == world and not slot.has("fixed") and _trial_match(plan, t, slot, selector):
					picked.append([t, i])
		if selector == "combo" and picked.size() > count:
			var spread: Array = []
			for k: int in count:
				spread.append(picked[(picked.size() - 1) * (k + 1) / count])
			picked = spread
		picked = picked.slice(0, count)
		var longest: float = 0.0
		for entry: Array in picked:
			var slot: Dictionary = (tracks[entry[0]][entry[1]] as Dictionary).duplicate(true)
			var started: int = Time.get_ticks_msec()
			var draft: Dictionary
			if slot.has("low"):
				draft = draw_one(slot, BASE_SEED + entry[0] * 10000 + entry[1], used)
				if draft.is_empty():
					draft = _draw_stepped(slot, entry[0], entry[1], used)
			else:
				var found: Array[Dictionary] = draw_group(slot["modes"], slot["band"], 1,
						BASE_SEED + entry[0] * 10000 + entry[1], used, [] as Array[String], slot["floor"])
				draft = found[0] if not found.is_empty() else {}
			var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
			longest = maxf(longest, seconds)
			if draft.is_empty():
				good = false
			else:
				used[draft["key"]] = true
			print("  %s: %s %s · %.1f san" % [selector, _slot_name(slot),
					("%d gediş" % draft["moves"]) if not draft.is_empty() else "TAPILMADI", seconds])
		print("trial %s: %d levels, max %.1f s" % [selector, picked.size(), longest])
	return good


static func _trial_match(plan: Dictionary, track: int, slot: Dictionary, selector: String) -> bool:
	if selector.begins_with("slot:"):
		# "slot:<track>/<slot number>" as the build's error lines print them.
		var tracks: Array = [plan["main"]]
		for island: Dictionary in plan["islands"]:
			tracks.append(island["slots"])
		var wanted: PackedStringArray = selector.trim_prefix("slot:").split("/")
		var list: Array = tracks[wanted[0].to_int()]
		return slot.has("low") and list.find(slot) == wanted[1].to_int() - 1
	if selector.begins_with("island:"):
		return track > 0 and plan["islands"][track - 1]["mode"] == selector.trim_prefix("island:")
	if track > 0:
		return false
	if selector.begins_with("big_test:"):
		return slot.get("wave", "") == "big_test" and stream_of(slot["modes"]) == selector.trim_prefix("big_test:")
	if selector == "combo":
		return (slot["modes"] as Array).size() > 1
	return slot.has("low") and _slot_name(slot) == selector


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
## World by world (the waves of its main road and islands, then its bands), so
## a world's levels only depend on the worlds before it: building a later world
## never changes an earlier one. The worlds in `keep` are read back from the
## level files instead of drawn again (the same levels, much faster:
## `-- --worlds=1-3 --keep=1-2`).
static func build(worlds: Array[int], errors: Array[String], keep: Array[int] = []) -> Dictionary:
	var plan: Dictionary = layout(worlds)
	var used: Dictionary = {}
	var main: Array = plan["main"]
	var tracks: Array = [main]
	for island: Dictionary in plan["islands"]:
		tracks.append(island["slots"])
	# The tutorial levels first, so nothing else repeats them.
	for slot: Dictionary in main:
		if slot.has("fixed"):
			slot["draft"] = _tutorial_draft(slot["fixed"])
			used[slot["draft"]["key"]] = true
	var ordered: Array[int] = worlds.duplicate()
	ordered.sort()
	if resume:
		_load_checkpoint(tracks, worlds, used)
	for world: int in ordered:
		if keep.has(world):
			_keep_world(plan, world, used, errors)
			continue
		_draw_waves(tracks, world, used, errors)
		if trial_limit > 0:
			return {"trial": true}
		_draw_bands(tracks, world, used, errors)
	return _number(plan, ordered)


## Every drawn slot of `tracks` (not kept or fixed ones) to checkpoint_path, keyed
## "track/index", for the run's `worlds`.
static func _save_checkpoint(tracks: Array) -> void:
	_unsaved = 0
	var slots: Dictionary = {}
	for t: int in tracks.size():
		for i: int in (tracks[t] as Array).size():
			var slot: Dictionary = tracks[t][i]
			if not slot.has("draft") or slot.has("fixed") or slot.get("kept", false):
				continue
			var draft: Dictionary = slot["draft"]
			var path: Array = []
			for move: Move in draft["path"]:
				path.append(move.to_array())
			slots["%d/%d" % [t, i]] = {"modes": slot["modes"], "variants": slot.get("variants", []),
				"draft": {"start": (draft["start"] as PuzzleState).to_array(), "goal": (draft["goal"] as PuzzleState).to_array(),
				"rule_ids": draft["rule_ids"], "params": draft["params"], "covered": draft["covered"],
				"glass": draft.get("glass", []), "variants": draft.get("variants", []), "path": path,
				"moves": draft["moves"], "key": draft["key"]}}
	var file: FileAccess = FileAccess.open(checkpoint_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"slots": slots}))
	print("  checkpoint: %d levels" % slots.size())


static func _load_checkpoint(tracks: Array, worlds: Array[int], used: Dictionary) -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
	if typeof(data) != TYPE_DICTIONARY:
		print("  resume: no checkpoint")
		return
	var count: int = 0
	var saved: Dictionary = data["slots"]
	for ref: String in saved:
		var t: int = ref.get_slice("/", 0).to_int()
		var i: int = ref.get_slice("/", 1).to_int()
		if t >= tracks.size() or i >= (tracks[t] as Array).size():
			continue
		var slot: Dictionary = tracks[t][i]
		if not worlds.has(int(slot["world"])):
			continue
		var entry: Dictionary = saved[ref]
		var stored: Dictionary = entry["draft"]
		var draft: Dictionary = {"start": PuzzleState.from_array(stored["start"]), "goal": PuzzleState.from_array(stored["goal"]),
			"params": Level._whole_numbers_as_ints(stored["params"]), "moves": int(stored["moves"]), "key": stored["key"]}
		for name: String in ["rule_ids", "variants"]:
			var names: Array[String] = []
			names.assign(stored[name])
			draft[name] = names
		for name: String in ["covered", "glass"]:
			var numbers: Array[int] = []
			numbers.assign(Level._whole_numbers_as_ints(stored[name]))
			draft[name] = numbers
		var path: Array[Move] = []
		for pair: Variant in stored["path"]:
			path.append(Move.from_array(pair))
		draft["path"] = path
		(slot["modes"] as Array).assign(entry["modes"])
		if slot.has("variants"):
			(slot["variants"] as Array).assign(entry["variants"])
		slot["draft"] = draft
		used[draft["key"]] = true
		count += 1
	print("  resume: %d levels from the checkpoint" % count)


## The slots of `world` take their levels from the level files of the road as
## it stands (the path's entries in the same places).
static func _keep_world(plan: Dictionary, world: int, used: Dictionary, errors: Array[String]) -> void:
	var path: Dictionary = LevelCatalog.read_path("%s/%s" % [Difficulty.LEVELS_DIR, LevelCatalog.PATH_FILE], errors)
	if path.is_empty():
		return
	var pairs: Array = []
	for i: int in (plan["main"] as Array).size():
		if i < (path[LevelCatalog.MAIN] as Array).size():
			pairs.append([plan["main"][i], path[LevelCatalog.MAIN][i]])
	for k: int in (plan["islands"] as Array).size():
		if k < (path["islands"] as Array).size():
			for i: int in (plan["islands"][k]["slots"] as Array).size():
				pairs.append([plan["islands"][k]["slots"][i], path["islands"][k]["levels"][i]])
	var kept: int = 0
	for pair: Array in pairs:
		var slot: Dictionary = pair[0]
		if slot["world"] != world or slot.has("fixed"):
			continue
		var level: Level = Level.load_file("%s/%s" % [Difficulty.LEVELS_DIR, pair[1]["file"]], errors)
		if level == null:
			continue
		var key: String = LevelForge.puzzle_key(level.start, level.goal, level.rule_ids, level.rule_params)
		slot["draft"] = {"start": level.start, "goal": level.goal, "rule_ids": level.rule_ids, "params": level.rule_params,
				"covered": level.covered_pegs, "glass": level.glass_disks, "variants": level.variants,
				"path": level.solution_path, "moves": level.min_moves, "key": key}
		slot["kept"] = true
		used[key] = true
		kept += 1
	print("  world %d: %d levels kept from the files" % [world, kept])


## The band slots of `world`, by stream and band (one group per world), in
## road order; each group gets its levels at once.
static func _draw_bands(tracks: Array, world: int, used: Dictionary, errors: Array[String]) -> void:
	var groups: Dictionary = {}
	var order: Array[String] = []
	for track: Array in tracks:
		for slot: Dictionary in track:
			if slot.has("fixed") or slot.has("low") or slot["world"] != world or slot.has("draft"):
				continue
			var group: String = "%s/%s/w%d" % [stream_of(slot["modes"]), slot["band"], world]
			if not groups.has(group):
				groups[group] = []
				order.append(group)
			(groups[group] as Array).append(slot)
	for group: String in order:
		var slots: Array = groups[group]
		var first: Dictionary = slots[0]
		var started: int = Time.get_ticks_msec()
		var group_errors: Array[String] = []
		var drafts: Array[Dictionary] = draw_group(first["modes"], first["band"], slots.size(),
				BASE_SEED + group.hash() % 100000, used, group_errors, first["floor"])
		print("  %s: %d levels in %.1f s" % [group, drafts.size(), (Time.get_ticks_msec() - started) / 1000.0])
		for i: int in drafts.size():
			slots[i]["draft"] = drafts[i]
		# A combination that gives too few levels (ICRA section 5: the rule is
		# not loosened, the combination stays on the list and is reported)
		# leaves its places to the chapter's other combinations.
		var missing: Array = slots.slice(drafts.size())
		for alternative: Array in first.get("alternatives", []):
			if missing.is_empty():
				break
			var more: Array[Dictionary] = draw_group(alternative, first["band"], missing.size(),
					BASE_SEED + (group + stream_of(alternative)).hash() % 100000, used, [] as Array[String], first["floor"])
			print("  %s: %d of its %d places to %s" % [group, more.size(), missing.size(), stream_of(alternative)])
			for i: int in more.size():
				(missing[i] as Dictionary)["modes"] = alternative.duplicate()
				(missing[i] as Dictionary)["draft"] = more[i]
			missing = missing.slice(more.size())
		if not missing.is_empty():
			errors.append_array(group_errors)
			errors.append("%s: only %d of %d levels found" % [group, slots.size() - missing.size(), slots.size()])
		_save_checkpoint(tracks)


## Fallbacks for a wave slot nothing was found for. An island slot tries the
## ISLAND_STEPS windows below its own; a main road slot slides its window down
## step by step (MAIN_STEP, never under MAIN_LOW_LIMIT); then, for a lone
## sub-element, another one of the same chapter in the original window.
const ISLAND_STEPS: Array = [[35, 37], [28, 34]]
const MAIN_LOW_LIMIT: int = 18
const MAIN_STEP: int = 2


static func _draw_stepped(slot: Dictionary, t: int, i: int, used: Dictionary) -> Dictionary:
	var seed_value: int = BASE_SEED + t * 10000 + i
	var original_low: int = slot["low"]
	var original_high: int = slot["high"]
	var windows: Array = []
	if t > 0:
		for window: Array in ISLAND_STEPS:
			if window[1] < original_high:
				windows.append(window)
	else:
		var low: int = original_low
		var high: int = original_high
		while true:
			high -= MAIN_STEP
			if low > MAIN_LOW_LIMIT:
				low = maxi(low - MAIN_STEP, MAIN_LOW_LIMIT)
			if high < low + WINDOW:
				break
			windows.append([low, high])
	for window: Array in windows:
		slot["low"] = window[0]
		slot["high"] = window[1]
		var draft: Dictionary = draw_one(slot, seed_value, used)
		if not draft.is_empty():
			print("    track %d slot %d: found in step %d-%d (was %d-%d)" % [t, i + 1, window[0], window[1], original_low, original_high])
			return draft
	slot["low"] = original_low
	slot["high"] = original_high
	var variants: Array = slot.get("variants", [])
	var original_extra: Dictionary = slot["extra"]
	if t == 0 and variants.size() == 1 and (slot["modes"] as Array).size() == 1:
		var mode: String = slot["modes"][0]
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		for other: String in _sharable(mode):
			if variants.has(other):
				continue
			var swapped: Array[String] = [other]
			slot["variants"] = swapped
			slot["extra"] = _wave_extra(mode, swapped, slot["t"], rng)
			var draft: Dictionary = draw_one(slot, seed_value, used)
			if not draft.is_empty():
				print("    track %d slot %d: sub-element %s instead of %s" % [t, i + 1, other, str(variants)])
				return draft
		slot["variants"] = variants
		slot["extra"] = original_extra
	return {}


## The wave levels of `world` (a window of their own each), in road order:
## its main road slots, then its islands'.
static func _slot_name(slot: Dictionary) -> String:
	var name: String = stream_of(slot["modes"])
	var variants: Array = slot.get("variants", [])
	return name if variants.is_empty() else "%s[%s]" % [name, ",".join(variants)]


static func _wave_total(tracks: Array, world: int) -> int:
	var total: int = 0
	for track: Array in tracks:
		for slot: Dictionary in track:
			if slot.has("low") and slot["world"] == world:
				total += 1
	return total


static func _draw_waves(tracks: Array, world: int, used: Dictionary, errors: Array[String]) -> void:
	for t: int in tracks.size():
		var started: int = Time.get_ticks_msec()
		var count: int = 0
		for i: int in (tracks[t] as Array).size():
			var slot: Dictionary = tracks[t][i]
			if not slot.has("low") or slot["world"] != world:
				continue
			if slot.has("draft"):
				count += 1
				continue
			if trial_limit > 0 and count >= trial_limit:
				return
			var level_start: int = Time.get_ticks_msec()
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
				draft = _draw_stepped(slot, t, i, used)
			if draft.is_empty():
				errors.append("track %d slot %d: no %s level %s with %d-%d moves" % [t, i + 1, stream_of(slot["modes"]),
						str(slot["variants"]), slot["low"], slot["high"]])
				continue
			used[draft["key"]] = true
			slot["draft"] = draft
			count += 1
			print("  W%d %s %d/%d · cəhd %d · %d san" % [world, _slot_name(slot), count, _wave_total(tracks, world),
					last_tries, (Time.get_ticks_msec() - level_start) / 1000])
			_unsaved += 1
			if _unsaved >= CHECKPOINT_EVERY and trial_limit == 0:
				_save_checkpoint(tracks)
		if count > 0 and trial_limit == 0:
			_save_checkpoint(tracks)
		if count > 0:
			print("  world %d track %d: %d wave levels in %.1f s" % [world, t, count, (Time.get_ticks_msec() - started) / 1000.0])


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
		# Every slot learns its world (band slots its floor too; wave slots have
		# their windows).
		var slots: Array = main.slice(first_new)
		for island: Dictionary in islands.slice(islands_before):
			island["world"] = chapter["world"]
			slots.append_array(island["slots"])
		for slot: Dictionary in slots:
			slot["world"] = chapter["world"]
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
	var goals: Array[String] = []
	if not ChapterPlan.OWN_GOAL.has(chapter["mode"]):
		goals = ChapterPlan.goal_variants_at(first)
	var breath_count: int = 0 if goals.is_empty() else roundi(length * ChapterPlan.BREATH_SHARE)
	var items: Array[Dictionary] = wave_items(chapter["mode"], length - classic_count - repeat_count - breath_count, rng,
			least)
	var last: int = items.size() - 1
	# Repeats spread over the second half of the mode levels (never after the last).
	var repeats: Dictionary = {}
	for r: int in repeat_count:
		var at: int = items.size() / 2 + int((last - items.size() / 2) * (r + 0.5) / repeat_count)
		var mode: String = earlier[earlier.size() - 1 - r % earlier.size()]
		repeats[at] = _repeat_item(mode, items[at], rng, least)
	# Goal variants (ICRA section 4) spread over the chapter after its first wave.
	var breaths: Dictionary = {}
	for b: int in breath_count:
		var at: int = mini(int(last * (0.15 + 0.8 * (b + 0.5) / breath_count)), last - 1)
		while breaths.has(at):
			at += 1
		breaths[at] = _breath_item(chapter["mode"], goals[b % goals.size()], items[at])
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
		if breaths.has(at):
			slots.append(breaths[at])
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
	# A wave with few puzzles of its own keeps at most its own count
	# (ChapterPlan.WAVE_SIZES); the others share the rest.
	var limits: Dictionary = ChapterPlan.WAVE_SIZES.get(mode, {})
	var sizes: Array[int] = []
	var open_waves: int = 0
	var rest: int = body
	for variant: String in waves:
		if limits.has(variant):
			sizes.append(mini(int(limits[variant]), rest))
			rest -= sizes[-1]
		else:
			sizes.append(-1)
			open_waves += 1
	var share: int = 0
	for k: int in waves.size():
		if sizes[k] == -1:
			sizes[k] = rest / maxi(open_waves, 1) + (1 if share < rest % maxi(open_waves, 1) else 0)
			share += 1
	for k: int in waves.size():
		var variant: String = waves[k]
		var size: int = sizes[k]
		for j: int in size:
			var t: float = float(j) / maxf(size - 1, 1.0)
			var variants: Array[String] = []
			if variant != ChapterPlan.BASE:
				variants.append(variant)
				# Mixed with what came before once the new sub-element is known
				# (a twist of its own, ChapterPlan.SOLO, stays alone).
				if j > DEV_LEVELS and not ChapterPlan.SOLO.has(variant):
					variants.append_array(_pick_variants(taught, 1 if j < size - 1 else 2, variants, rng))
			var extra: Dictionary = _wave_extra(mode, variants, t, rng)
			if variant == ChapterPlan.BASE and mode == ChapterPlan.COVERED:
				extra["covered"] = 1 if j < size / 2 else 2  # one box first, two by the wave's end
			var span: Array[int] = _capped(_wave_window(k, sections, t, j == 0, floors), variants, floors[1], j == 0)
			items.append({"modes": [mode], "variants": variants, "extra": extra, "low": span[0], "high": span[1], "t": t,
					"wave": variant, "intro": j == 0})
		if variant != ChapterPlan.BASE and not ChapterPlan.SOLO.has(variant):
			taught.append(variant)
	for j: int in mixed_size:
		var t: float = float(j) / maxf(mixed_size - 1, 1.0)
		var variants: Array[String] = _pick_variants(taught, 2 + (1 if j >= mixed_size / 2 and taught.size() > 2 else 0), [], rng)
		var span: Array[int] = _capped(_wave_window(sections - 1, sections, t, false, floors), variants, floors[1], false)
		items.append({"modes": [mode], "variants": variants, "extra": _wave_extra(mode, variants, t, rng),
				"low": span[0], "high": span[1], "t": t, "wave": "mixed"})
	# The Böyük Sınaq: every sub-element that can share a level, in wave order
	# but the helping ones last (a draw that cannot reach its length drops the
	# last first); not the twists of their own nor those that stay short.
	var all: Array[String] = []
	for variant: String in waves:
		if variant == ChapterPlan.BASE or ChapterPlan.SOLO.has(variant) or ChapterPlan.VARIANT_CEILINGS.has(variant):
			continue
		if _pick_variants([variant], 1, all, rng).size() == 1:
			all.append(variant)
	var ordered: Array[String] = []
	for helping: bool in [false, true]:
		for variant: String in all:
			if ChapterPlan.HELPERS.has(variant) == helping:
				ordered.append(variant)
	all = ordered
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


## `span` held under the ceiling of a sub-element in `variants`
## (ChapterPlan.VARIANT_CEILINGS): at most the ceiling, never below the
## world's floor `least` but for an intro.
static func _capped(span: Array[int], variants: Array, least: int, intro: bool) -> Array[int]:
	var ceiling: int = 1000
	for variant: String in variants:
		ceiling = mini(ceiling, ChapterPlan.VARIANT_CEILINGS.get(variant, 1000))
	if span[1] <= ceiling:
		return span
	var high: int = maxi(ceiling, least)
	var low: int = mini(span[0], high - 2 * WINDOW)
	return [low if intro else maxi(low, least), high]


## Board settings a level's sub-elements need: boxes for the karakuri, how
## many locks a chain has.
static func _wave_extra(mode: String, variants: Array[String], t: float, rng: RandomNumberGenerator) -> Dictionary:
	var extra: Dictionary = {"variants": variants}
	if mode == ChapterPlan.COVERED:
		extra["covered"] = 1 if variants.has("full_hidden") or variants.has("sealed") or rng.randf() < 0.5 else 2
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
	var pool: Array = _sharable(mode)
	var variants: Array[String] = _pick_variants(pool, rng.randi_range(0, 2), [], rng)
	var low: int = maxi(item["low"], least)
	return {"modes": [mode], "variants": variants, "extra": _wave_extra(mode, variants, item["t"], rng),
			"low": low, "high": maxi(item["high"], low + WINDOW), "t": item["t"], "band": item["band"]}


## A goal variant's level (ICRA section 4) of `mode` at the place of `item`:
## the chapter's mode with the goal of the variant's carrying rule, short
## (ChapterPlan.BREATH_MOVES) on the stream's small boards; it keeps the
## stream (recipes, ids) of `mode`.
static func _breath_item(mode: String, variant: String, item: Dictionary) -> Dictionary:
	var modes: Array[String] = [mode, ChapterPlan.GOAL_RULES[variant]]
	var variants: Array[String] = [variant]
	var span: Array[int] = ChapterPlan.BREATH_MOVES
	return {"modes": modes, "stream": mode, "variants": variants, "extra": {"variants": variants}, "low": span[0],
			"high": span[1], "t": item["t"], "band": band_of_moves((span[0] + span[1]) / 2), "breath": true}


## The island of a mode chapter: ISLAND_LEVELS expert levels, each with the
## island's own sub-element (if the mode has one) and one or two of the
## chapter's, longer and longer; or the chapter's set that always goes
## together there (ChapterPlan.ISLAND_SETS).
static func _mode_island(mode: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool: Array = _sharable(mode)
	var slots: Array[Dictionary] = []
	for i: int in ChapterPlan.ISLAND_LEVELS:
		var variants: Array[String] = []
		if ChapterPlan.ISLAND_VARIANTS.has(mode):
			variants.append(ChapterPlan.ISLAND_VARIANTS[mode])
			# The movable stone is a weight stone first.
			if variants.has("moving_stone"):
				variants.append("stone")
		if ChapterPlan.ISLAND_SETS.has(mode):
			variants.append_array(ChapterPlan.ISLAND_SETS[mode])
		else:
			variants.append_array(_pick_variants(pool, rng.randi_range(1, 2), variants, rng))
		var extra: Dictionary = _wave_extra(mode, variants, float(i) / ChapterPlan.ISLAND_LEVELS, rng)
		var low: int = ChapterPlan.BANDS["expert"][0] + i
		var high: int = low + 10 + i
		if ChapterPlan.ISLAND_CEILINGS.has(mode):
			high = mini(high, ChapterPlan.ISLAND_CEILINGS[mode])
			low = mini(low, high - 6)
		if ChapterPlan.ISLAND_WINDOWS.has(mode):
			low = ChapterPlan.ISLAND_WINDOWS[mode][0]
			high = ChapterPlan.ISLAND_WINDOWS[mode][1]
		slots.append({"modes": [mode], "variants": variants, "extra": extra, "low": low, "high": high,
				"t": 1.0, "band": "expert"})
	return slots


## The sub-elements of `mode` a repeat or an island may carry: not the twists
## of their own (ChapterPlan.SOLO) nor those that stay short
## (ChapterPlan.VARIANT_CEILINGS).
static func _sharable(mode: String) -> Array:
	var pool: Array = []
	for variant: String in ChapterPlan.WAVES.get(mode, {}).get("waves", []):
		if variant != ChapterPlan.BASE and not ChapterPlan.SOLO.has(variant) and not ChapterPlan.VARIANT_CEILINGS.has(variant):
			pool.append(variant)
	return pool


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
	# Goal variants (ICRA section 4) in some of the single modes' places.
	var goals: Array[String] = ChapterPlan.goal_variants_at(first)
	var hosts: Array = (chapter["singles"] as Array).filter(func(mode: String) -> bool:
		return not ChapterPlan.OWN_GOAL.has(mode))
	if not goals.is_empty() and not hosts.is_empty():
		var single_places: Array = range(length).filter(func(index: int) -> bool: return kinds[index] == "single")
		for index: int in _strata(single_places, mini(roundi(length * ChapterPlan.BREATH_SHARE), single_places.size()), rng):
			kinds[index] = "breath"
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
	var counters: Dictionary = {CLASSIC: 0, "single": 0, "combo": 0, "breath": 0}
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
			"breath":
				var turn: int = counters["breath"]
				slots.append(_breath_item(hosts[turn % hosts.size()], goals[turn % goals.size()],
						{"t": float(index) / length}))
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
				# The chapter's other combinations, newest first, take its places
				# if it gives too few levels (_draw_bands()).
				var others: Array = []
				for i: int in range(combos.size() - 1, -1, -1):
					if i != pick:
						others.append(combos[i])
				slots.append({"modes": modes, "band": band, "alternatives": others})
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
			Solver.deadline_msec = Time.get_ticks_msec() + int(LEVEL_SECONDS * 1000.0)
			var candidates: int = 0
			for attempt: int in ATTEMPTS_PER_LEVEL:
				var draft: Dictionary = LevelForge.attempt(modes, board, low, high, used, rng)
				if draft.is_empty():
					if Solver.past_deadline():
						break
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
		Solver.deadline_msec = 0
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
## with the slot's settings on top; {} if none gives one. A wave's intro takes
## its stream's INTRO boards first where it has some (smaller boards that the
## rest of the chapter does not use), a Böyük Sınaq its BIG_TEST_BOARDS
## instead of its band's. A sealed box tries the smaller boards first (its
## memory makes 9 disks slow to search).
static func draw_one(slot: Dictionary, seed_value: int, used: Dictionary) -> Dictionary:
	var recipe: Dictionary = RECIPES.get(slot.get("stream", stream_of(slot["modes"])), {})
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var order: Array[String] = ["easy_medium", "medium", "medium_hard", "hard", "expert"]
	var at: int = order.find(slot["band"])
	var bands: Array[String] = [slot["band"]]
	if (slot.get("intro", false) or slot.get("breath", false)) and recipe.has(INTRO):
		bands.push_front(INTRO)
	if slot.get("wave", "") == "big_test" and recipe.has(BIG_TEST_BOARDS):
		bands = [BIG_TEST_BOARDS]
	for near: int in [at - 1, at + 1]:
		if near >= 0 and near < order.size():
			bands.append(order[near])
	var sealed: bool = (slot.get("variants", []) as Array).has("sealed")
	var attempts: int = ATTEMPTS_PER_LEVEL / 2
	for variant: String in slot.get("variants", []):
		attempts = maxi(attempts, ATTEMPTS_PER_LEVEL / 2 * int(SCARCE.get(variant, 1)))
	last_tries = 0
	var weak: String = ""
	var level_end: int = Time.get_ticks_msec() + int(LEVEL_SECONDS * 1000.0)
	Solver.deadline_msec = Time.get_ticks_msec() + int(FIRST_SECONDS * 1000.0)
	var rounds: Array = []
	for band: String in bands:
		rounds.append(recipe.get(band, []).duplicate())
	for pass_index: int in 2:
		var over: bool = false
		for boards: Array in rounds:
			var offset: int = rng.randi_range(0, maxi(boards.size() - 1, 0))
			if sealed or pass_index == 1:
				offset = 0
				boards.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["disks"] < b["disks"])
			for turn: int in boards.size():
				var board: Dictionary = (boards[(offset + turn) % boards.size()] as Dictionary).duplicate()
				board.merge(slot.get("extra", {}), true)
				for attempt: int in attempts:
					last_tries += 1
					var draft: Dictionary = LevelForge.attempt(slot["modes"], board, slot["low"], slot["high"], used, rng)
					if not draft.is_empty():
						Solver.deadline_msec = 0
						if weak != "":
							print("    zəif: %s (%d-%d, %s)" % [weak, slot["low"], slot["high"], stream_of(slot["modes"])])
						return draft
					if last_tries > LEVEL_TRIES or Solver.past_deadline():
						if pass_index == 0:
							weak = "cəhd %d" % last_tries if last_tries > LEVEL_TRIES else "vaxt %d san" % int(FIRST_SECONDS)
						over = true
						break
				if over:
					break
			if over:
				break
		if not over or pass_index == 1:
			break
		# Second pass: every board, the smaller ones first (the floor stays).
		var every: Array = []
		for boards: Array in rounds:
			every.append_array(boards)
		rounds = [every]
		weak += ", lövhə kiçildi"
		last_tries = 0
		Solver.deadline_msec = level_end
	Solver.deadline_msec = 0
	print("    limit: %s %d-%d, səviyyə tapılmadı" % [_slot_name(slot), slot["low"], slot["high"]])
	return {}


static func _tutorial_draft(index: int) -> Dictionary:
	var start: PuzzleState = PuzzleState.from_array(TUTORIAL_LEVELS[index]["start"])
	var goal: PuzzleState = PuzzleState.from_array(TUTORIAL_LEVELS[index]["goal"])
	var result: Dictionary = Solver.solve(start, goal, RuleSet.classic(), LevelForge.MAX_STATES)
	var rule_ids: Array[String] = [ClassicHanoiRule.ID]
	return {"start": start, "goal": goal, "rule_ids": rule_ids, "params": {}, "covered": [] as Array[int],
			"path": result["path"], "moves": result["min_moves"], "key": LevelForge.puzzle_key(start, goal, rule_ids, {})}


## Levels with ids and files: classic levels number up per tier, mechanic
## levels per stream (each in its own id block), world by world (its main road
## in order, then its islands), so a later world never renumbers an earlier
## one's levels (saves keep their ids).
static func _number(plan: Dictionary, worlds: Array[int]) -> Dictionary:
	var tier_counts: Dictionary = {}
	var stream_counts: Dictionary = {}
	var files: Dictionary = {}
	var make: Callable = func(slot: Dictionary) -> Level:
		var draft: Dictionary = slot["draft"]
		var tier: String = Difficulty.tier_for_moves(draft["moves"])
		var stream: String = slot.get("stream", stream_of(slot["modes"]))
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
	for world: int in worlds:
		for slot: Dictionary in plan["main"]:
			if slot["world"] == world and slot.has("draft"):
				slot["level"] = make.call(slot)
		for island: Dictionary in plan["islands"]:
			if island["world"] == world:
				for slot: Dictionary in island["slots"]:
					if slot.has("draft"):
						slot["level"] = make.call(slot)
	# A slot nothing was found for is left out of the road (main() lists it).
	var main: Array[Level] = []
	for slot: Dictionary in plan["main"]:
		if slot.has("level"):
			main.append(slot["level"])
	var islands: Array[Dictionary] = []
	for island: Dictionary in plan["islands"]:
		var levels: Array[Level] = []
		for slot: Dictionary in island["slots"]:
			if slot.has("level"):
				levels.append(slot["level"])
		islands.append({"mode": island["mode"], "after": island["after"], "levels": levels})
	return {"main": main, "islands": islands, "files": files}


## First id of a mechanic stream's block.
static func id_block(stream: String) -> int:
	var index: int = ChapterPlan.MODES.find(stream)
	if index >= COMBO_FIRST_BLOCK:
		index = LATE_MODE_FIRST_BLOCK + index - COMBO_FIRST_BLOCK
	elif index == -1:
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
