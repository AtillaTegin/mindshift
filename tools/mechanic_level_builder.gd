class_name MechanicLevelBuilder
extends SceneTree
## Builds the levels with a special mechanic (Nine Rings alternation, karakuri
## boxes on covered pegs, the caravan road, the "Böyük Mübadilə" great
## exchange, the "Birləşmə Tapmacası" combination puzzles) into
## data/levels/mechanics/:
##   godot --headless --path . --script res://tools/mechanic_level_builder.gd
##   ... -- --only=fog_20.json   (rebuild one file; ids and seeds stay the same)
##   ... -- --only=caravan_*     (every file starting with "caravan_")
## They are ordinary path levels (level structure addendum v3): each gets the
## difficulty its min_moves falls in, and tools/path_builder.gd places them on
## the path. Puzzles come from a fixed-seed search; the Solver proves every
## min_moves and LevelValidator checks every file it writes.
## Exits with code 0 only when every level was built and validated.

const MECHANICS_DIR: String = Difficulty.LEVELS_DIR + "/" + Difficulty.MECHANICS
const BASE_SEED: int = 20261009
const MAX_ATTEMPTS: int = 8000

## Start/goal pairs of the classic levels; a mechanic level never repeats one.
static var _classic_pairs: Dictionary = {}

## Nine Rings (alternation rule) levels, from easy to hard, all on 4 pegs: on
## 3 pegs the classic shortest solution already alternates around disk 1, so
## the rule rarely adds a move (measured 2026-10-12). Move ranges are targets
## for the search; `attempts` bounds it (one 4 peg / 7 disk alternation search
## takes about 0.4 s).
const RINGS_SPECS: Array[Dictionary] = [
	{"file": "rings_01.json", "pegs": 4, "disks": 5, "min": 8, "max": 11, "attempts": 600},
	{"file": "rings_02.json", "pegs": 4, "disks": 6, "min": 12, "max": 16, "attempts": 600},
	{"file": "rings_03.json", "pegs": 4, "disks": 7, "min": 17, "max": 21, "attempts": 300},
	{"file": "rings_04.json", "pegs": 4, "disks": 7, "min": 21, "max": 24, "attempts": 300},
]

## Covered-peg (karakuri box) levels, from easy to hard: the first ones are
## small (3 disks, one box), later ones grow to 8 disks and two boxes (user
## request 2026-10-12: ~20 of them, starting right after the tutorial and
## getting harder step by step; then four more for the end of the road, at
## least as hard as the hardest; three boxes with 30+ moves were not found in
## 8000 tries, every box has to be used in the first moves). `covered`: how
## many pegs start as boxes; `attempts` overrides the search budget.
const FOG_SPECS: Array[Dictionary] = [
	{"file": "fog_01.json", "pegs": 3, "disks": 3, "min": 5, "max": 7, "covered": 1},
	{"file": "fog_02.json", "pegs": 3, "disks": 3, "min": 6, "max": 7, "covered": 1},
	{"file": "fog_03.json", "pegs": 3, "disks": 4, "min": 7, "max": 10, "covered": 1},
	{"file": "fog_04.json", "pegs": 3, "disks": 4, "min": 9, "max": 11, "covered": 1},
	{"file": "fog_05.json", "pegs": 3, "disks": 5, "min": 12, "max": 14, "covered": 1},
	{"file": "fog_06.json", "pegs": 3, "disks": 5, "min": 13, "max": 16, "covered": 1},
	{"file": "fog_07.json", "pegs": 4, "disks": 6, "min": 12, "max": 15, "covered": 1},
	{"file": "fog_08.json", "pegs": 3, "disks": 5, "min": 15, "max": 18, "covered": 1},
	{"file": "fog_09.json", "pegs": 4, "disks": 6, "min": 14, "max": 17, "covered": 2},
	{"file": "fog_10.json", "pegs": 3, "disks": 5, "min": 17, "max": 20, "covered": 1},
	{"file": "fog_11.json", "pegs": 4, "disks": 7, "min": 16, "max": 20, "covered": 2},
	{"file": "fog_12.json", "pegs": 4, "disks": 7, "min": 18, "max": 21, "covered": 2},
	{"file": "fog_13.json", "pegs": 4, "disks": 7, "min": 20, "max": 23, "covered": 2},
	{"file": "fog_14.json", "pegs": 4, "disks": 7, "min": 21, "max": 24, "covered": 2},
	{"file": "fog_15.json", "pegs": 4, "disks": 8, "min": 22, "max": 25, "covered": 2},
	{"file": "fog_16.json", "pegs": 4, "disks": 8, "min": 24, "max": 27, "covered": 2},
	{"file": "fog_17.json", "pegs": 4, "disks": 8, "min": 26, "max": 29, "covered": 2},
	{"file": "fog_18.json", "pegs": 4, "disks": 8, "min": 28, "max": 31, "covered": 2},
	{"file": "fog_19.json", "pegs": 4, "disks": 8, "min": 30, "max": 33, "covered": 2},
	{"file": "fog_20.json", "pegs": 4, "disks": 8, "min": 29, "max": 33, "covered": 2},
	{"file": "fog_21.json", "pegs": 4, "disks": 8, "min": 30, "max": 33, "covered": 2, "attempts": 6000},
	{"file": "fog_22.json", "pegs": 4, "disks": 8, "min": 30, "max": 33, "covered": 2, "attempts": 6000},
	{"file": "fog_23.json", "pegs": 4, "disks": 8, "min": 30, "max": 33, "covered": 2, "attempts": 6000},
	{"file": "fog_24.json", "pegs": 4, "disks": 8, "min": 30, "max": 33, "covered": 2, "attempts": 6000},
]


## More Nine Rings levels (user request 2026-10-12: ~20-25 along the whole
## road, easy to hard like the karakuri). Built after the old bosses' ids so
## the ids of every earlier level stay the same; the path sorts them by length
## anyway.
## 4 pegs only (the rule matters reliably there) and at most 7 disks, so an
## in-game hint search stays near half a second on a desktop; that caps them
## at about 27 moves (4 pegs / 5 disks stop at 13).
const RINGS_LATER_SPECS: Array[Dictionary] = [
	{"file": "rings_05.json", "pegs": 4, "disks": 3, "min": 5, "max": 7, "attempts": 600},
	{"file": "rings_06.json", "pegs": 4, "disks": 4, "min": 7, "max": 9, "attempts": 600},
	{"file": "rings_07.json", "pegs": 4, "disks": 4, "min": 8, "max": 10, "attempts": 600},
	{"file": "rings_08.json", "pegs": 4, "disks": 5, "min": 12, "max": 13, "attempts": 600},
	{"file": "rings_09.json", "pegs": 4, "disks": 5, "min": 13, "max": 15, "attempts": 600},
	{"file": "rings_10.json", "pegs": 4, "disks": 6, "min": 14, "max": 16, "attempts": 600},
	{"file": "rings_11.json", "pegs": 4, "disks": 6, "min": 15, "max": 17, "attempts": 600},
	{"file": "rings_12.json", "pegs": 4, "disks": 6, "min": 17, "max": 18, "attempts": 600},
	{"file": "rings_13.json", "pegs": 4, "disks": 6, "min": 18, "max": 19, "attempts": 600},
	{"file": "rings_14.json", "pegs": 4, "disks": 6, "min": 19, "max": 20, "attempts": 600},
	{"file": "rings_15.json", "pegs": 4, "disks": 7, "min": 21, "max": 22, "attempts": 300},
	{"file": "rings_16.json", "pegs": 4, "disks": 7, "min": 22, "max": 23, "attempts": 300},
	{"file": "rings_17.json", "pegs": 4, "disks": 7, "min": 23, "max": 24, "attempts": 300},
	{"file": "rings_18.json", "pegs": 4, "disks": 7, "min": 24, "max": 26, "attempts": 300},
	{"file": "rings_19.json", "pegs": 4, "disks": 7, "min": 25, "max": 27, "attempts": 300},
	{"file": "rings_20.json", "pegs": 4, "disks": 7, "min": 26, "max": 28, "attempts": 400},
	{"file": "rings_21.json", "pegs": 4, "disks": 7, "min": 26, "max": 28, "attempts": 600},
	{"file": "rings_22.json", "pegs": 4, "disks": 7, "min": 26, "max": 28, "attempts": 600},
]

## Caravan road levels (caravan road addendum, section 1: a disk only moves to
## a neighbouring peg), from easy to hard. Sizes measured 2026-10-12: on 3 pegs
## the road gets long fast (5 disks: median 99 moves), so 3 pegs keep 3-4
## disks; 4-5 pegs take 3-6. All stay within the main road's 33 moves.
const CARAVAN_SPECS: Array[Dictionary] = [
	{"file": "caravan_01.json", "pegs": 4, "disks": 3, "min": 5, "max": 7},
	{"file": "caravan_02.json", "pegs": 4, "disks": 3, "min": 6, "max": 8},
	{"file": "caravan_03.json", "pegs": 3, "disks": 3, "min": 7, "max": 9},
	{"file": "caravan_04.json", "pegs": 5, "disks": 3, "min": 7, "max": 10},
	{"file": "caravan_05.json", "pegs": 4, "disks": 3, "min": 8, "max": 11},
	{"file": "caravan_06.json", "pegs": 3, "disks": 3, "min": 9, "max": 11},
	{"file": "caravan_07.json", "pegs": 4, "disks": 4, "min": 12, "max": 14},
	{"file": "caravan_08.json", "pegs": 3, "disks": 3, "min": 12, "max": 15},
	{"file": "caravan_09.json", "pegs": 5, "disks": 4, "min": 12, "max": 15},
	{"file": "caravan_10.json", "pegs": 4, "disks": 4, "min": 14, "max": 17},
	{"file": "caravan_11.json", "pegs": 3, "disks": 3, "min": 15, "max": 19},
	{"file": "caravan_12.json", "pegs": 4, "disks": 5, "min": 15, "max": 18},
	{"file": "caravan_13.json", "pegs": 5, "disks": 4, "min": 16, "max": 19},
	{"file": "caravan_14.json", "pegs": 4, "disks": 5, "min": 17, "max": 20},
	{"file": "caravan_15.json", "pegs": 3, "disks": 4, "min": 17, "max": 20},
	{"file": "caravan_16.json", "pegs": 5, "disks": 5, "min": 18, "max": 20},
	{"file": "caravan_17.json", "pegs": 4, "disks": 5, "min": 21, "max": 23},
	{"file": "caravan_18.json", "pegs": 3, "disks": 4, "min": 21, "max": 24},
	{"file": "caravan_19.json", "pegs": 5, "disks": 5, "min": 21, "max": 24},
	{"file": "caravan_20.json", "pegs": 4, "disks": 6, "min": 22, "max": 25},
	{"file": "caravan_21.json", "pegs": 4, "disks": 5, "min": 23, "max": 26},
	{"file": "caravan_22.json", "pegs": 3, "disks": 4, "min": 24, "max": 27},
	{"file": "caravan_23.json", "pegs": 5, "disks": 5, "min": 24, "max": 28},
	{"file": "caravan_24.json", "pegs": 4, "disks": 6, "min": 25, "max": 28},
	{"file": "caravan_25.json", "pegs": 5, "disks": 6, "min": 26, "max": 29},
	{"file": "caravan_26.json", "pegs": 4, "disks": 6, "min": 27, "max": 30},
	{"file": "caravan_27.json", "pegs": 3, "disks": 4, "min": 28, "max": 31},
	{"file": "caravan_28.json", "pegs": 5, "disks": 6, "min": 28, "max": 31},
	{"file": "caravan_29.json", "pegs": 4, "disks": 6, "min": 30, "max": 33},
	{"file": "caravan_30.json", "pegs": 4, "disks": 6, "min": 31, "max": 33},
]

## Ids 9059-9063 belonged to the five great exchange bosses, removed by the
## great exchange v2 addendum; they stay unused so later ids keep their values.
const RETIRED_BOSS_IDS: int = 5

## "Böyük Mübadilə" v2 (addendum 2026-10-13 and the user's decision on its two
## kinds, ColorSwapRule): k white and k black disks, one of each size 1..k per
## colour, on the two end pegs with `buffers` empty pegs between them; the goal
## is every black disk on the left end and every white one on the right.
## - "pure" ("Təmiz Dəyişmə"): whites on the left, blacks on the right, size
##   rule only: the two stacks swap. One puzzle per board.
## - "mixed" ("Qarışıq-Ayırma"): each end holds one disk of each size with the
##   colours mixed; size rule plus "colours never touch". One puzzle per colour
##   pattern; the largest pair always starts on the wrong ends (otherwise it is
##   a smaller board on a fixed base), unsolvable patterns are dropped.
## Boards measured 2026-10-14 with the Solver: one buffer is unsolvable, so at
## least 2; up to 33 moves (the main road) and at most 8 disks, so an off-path
## hint stays within about twice the slowest expert one (6 pegs / 8 disks:
## 0.4-3.2 s on a desktop; 5 pegs / 10 disks took 4.6 s and 6 pegs / 10 disks
## 22 s). More pure k = 2 boards would only repeat the 7-move swap, 4 buffers
## / 3 disks (11 moves) would be one more easy level, so they are left out.
## Levels go easiest first (pure first on a tie) and take the tier of their
## min_moves.
const SWAP_BOARDS: Array[Dictionary] = [
	{"kind": "pure", "buffers": 2, "k": 2},
	{"kind": "pure", "buffers": 2, "k": 3},
	{"kind": "pure", "buffers": 2, "k": 4},
	{"kind": "pure", "buffers": 3, "k": 3},
	{"kind": "pure", "buffers": 3, "k": 4},
	{"kind": "pure", "buffers": 4, "k": 4},
	{"kind": "mixed", "buffers": 3, "k": 2},
	{"kind": "mixed", "buffers": 2, "k": 3},
	{"kind": "mixed", "buffers": 3, "k": 3},
	{"kind": "mixed", "buffers": 4, "k": 3},
	{"kind": "mixed", "buffers": 3, "k": 4},
	{"kind": "mixed", "buffers": 4, "k": 4},
]
const SWAP_MIN_MOVES: int = 5
const SWAP_MAX_MOVES: int = 33

## Ids 9082-9111 belonged to the 30 "Birləşmə Tapmacası" levels, archived with
## Water Sort (new mechanics specification v1, section 0: archive/water_sort/);
## they stay unused. The great exchange keeps a block of SWAP_ID_BLOCK ids
## after them, so it may grow to 40 levels without moving later ids.
const RETIRED_COMBO_IDS: int = 30
const SWAP_ID_BLOCK: int = 40

## Pilot levels of the new mechanics (new mechanics specification v1, sections
## 1-6, 8 and 9; 3-4 each, user decision 2026-10-15: on the main road, in the
## slots the archived combination puzzles left). Every one is classic Hanoi
## plus its mechanic's rule, between a random start and a random goal (half of
## them a full tower), and the rule must make it longer than plain Hanoi; the
## longest candidate in range wins (ties: first found). Sizes come from
## measuring random boards (2026-10-15):
## - peg_capacity: on 3 pegs a capacity never changes a solution (moving the
##   largest disk needs all the others on the third peg anyway), so 4 pegs.
## - foundation: `locked` largest disks, `keys` smallest ones whose goal pegs
##   open the lock (FoundationRule; targets taken from the goal).
## - balance: start and goal are drawn from every position within the
##   tolerance (random boards are almost never balanced).
## - stripes: random alternating positions (a tower alternates anyway).
## - chain: 4 pegs (on 3 the pair is nearly always stuck); the solution must
##   use the compound move.
## - mirror: `boards` [first, second] disks on two 3-peg boards.
## - trail: the disk may not return to either of the last two pegs it stood
##   on ("recent": 2). With its whole history (the specification's own words)
##   the rule changed 0-6 of 100 random boards, and only slightly; it either
##   allowed the classic solution or left none. The specification left that
##   choice to the builder (section 3: "son N qülləni xatırla"). 3 pegs only:
##   on 4 pegs the remembered pegs multiply the positions (a 4 peg / 6 disk
##   search ran for minutes).
const PILOT_SPECS: Array[Dictionary] = [
	{"file": "capacity_01.json", "mechanic": "peg_capacity", "pegs": 4, "disks": 5, "min": 7, "max": 11,
			"params": {"capacities": [5, 2, 2, 5]}, "attempts": 6000},
	{"file": "capacity_02.json", "mechanic": "peg_capacity", "pegs": 4, "disks": 6, "min": 13, "max": 17,
			"params": {"capacities": [6, 2, 3, 6]}},
	{"file": "capacity_03.json", "mechanic": "peg_capacity", "pegs": 4, "disks": 7, "min": 18, "max": 24,
			"params": {"capacities": [7, 3, 2, 7]}},
	{"file": "capacity_04.json", "mechanic": "peg_capacity", "pegs": 4, "disks": 7, "min": 24, "max": 30,
			"params": {"capacities": [7, 2, 2, 7]}},
	{"file": "foundation_01.json", "mechanic": "foundation", "pegs": 3, "disks": 4, "min": 8, "max": 11, "locked": 1, "keys": 2},
	{"file": "foundation_02.json", "mechanic": "foundation", "pegs": 3, "disks": 5, "min": 16, "max": 20, "locked": 1, "keys": 2},
	{"file": "foundation_03.json", "mechanic": "foundation", "pegs": 4, "disks": 6, "min": 17, "max": 21, "locked": 2, "keys": 3},
	{"file": "foundation_04.json", "mechanic": "foundation", "pegs": 4, "disks": 7, "min": 21, "max": 26, "locked": 2, "keys": 3},
	{"file": "balance_01.json", "mechanic": "balance", "pegs": 4, "disks": 5, "min": 12, "max": 16, "params": {"tolerance": 6}},
	{"file": "balance_02.json", "mechanic": "balance", "pegs": 4, "disks": 6, "min": 14, "max": 20, "params": {"tolerance": 7}},
	{"file": "balance_03.json", "mechanic": "balance", "pegs": 4, "disks": 6, "min": 16, "max": 24, "params": {"tolerance": 6}},
	{"file": "balance_04.json", "mechanic": "balance", "pegs": 4, "disks": 7, "min": 20, "max": 30, "params": {"tolerance": 7}},
	{"file": "cyclic_01.json", "mechanic": "cyclic", "pegs": 3, "disks": 3, "min": 8, "max": 11},
	{"file": "cyclic_02.json", "mechanic": "cyclic", "pegs": 3, "disks": 4, "min": 15, "max": 20},
	{"file": "cyclic_03.json", "mechanic": "cyclic", "pegs": 4, "disks": 4, "min": 18, "max": 24},
	{"file": "cyclic_04.json", "mechanic": "cyclic", "pegs": 4, "disks": 5, "min": 26, "max": 33},
	{"file": "stripes_01.json", "mechanic": "stripes", "pegs": 4, "disks": 5, "min": 7, "max": 11, "attempts": 4000},
	{"file": "stripes_02.json", "mechanic": "stripes", "pegs": 4, "disks": 6, "min": 13, "max": 16, "attempts": 4000},
	{"file": "stripes_03.json", "mechanic": "stripes", "pegs": 4, "disks": 7, "min": 17, "max": 22, "attempts": 4000},
	{"file": "stripes_04.json", "mechanic": "stripes", "pegs": 3, "disks": 5, "min": 28, "max": 33, "attempts": 4000},
	{"file": "chain_01.json", "mechanic": "chain", "pegs": 4, "disks": 5, "min": 12, "max": 14, "params": {"disks": [2, 4]}},
	{"file": "chain_02.json", "mechanic": "chain", "pegs": 4, "disks": 6, "min": 14, "max": 18, "params": {"disks": [2, 5]}},
	{"file": "chain_03.json", "mechanic": "chain", "pegs": 4, "disks": 6, "min": 17, "max": 22, "params": {"disks": [1, 4]}},
	{"file": "chain_04.json", "mechanic": "chain", "pegs": 4, "disks": 7, "min": 20, "max": 26, "params": {"disks": [3, 6]}},
	{"file": "mirror_01.json", "mechanic": "mirror", "pegs": 6, "boards": [3, 3], "min": 12, "max": 14},
	{"file": "mirror_02.json", "mechanic": "mirror", "pegs": 6, "boards": [3, 4], "min": 16, "max": 21},
	{"file": "mirror_03.json", "mechanic": "mirror", "pegs": 6, "boards": [4, 4], "min": 22, "max": 27},
	{"file": "mirror_04.json", "mechanic": "mirror", "pegs": 6, "boards": [4, 5], "min": 28, "max": 33},
	{"file": "trail_01.json", "mechanic": "trail", "pegs": 3, "disks": 4, "min": 12, "max": 16, "params": {"disk": 1, "recent": 2}},
	{"file": "trail_02.json", "mechanic": "trail", "pegs": 3, "disks": 5, "min": 17, "max": 22, "params": {"disk": 1, "recent": 2}},
	{"file": "trail_03.json", "mechanic": "trail", "pegs": 3, "disks": 5, "min": 20, "max": 26, "params": {"disk": 2, "recent": 2}},
	{"file": "trail_04.json", "mechanic": "trail", "pegs": 3, "disks": 6, "min": 26, "max": 33, "params": {"disk": 1, "recent": 2}},
]
## Balanced positions by "pegs/disks/tolerance" (read once per run).
static var _balanced: Dictionary = {}


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	DirAccess.make_dir_recursive_absolute(MECHANICS_DIR)
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
	var ok: bool = true
	var next_id: int = Difficulty.MECHANIC_FIRST_ID
	for i: int in RINGS_SPECS.size():
		var spec: Dictionary = RINGS_SPECS[i]
		if _selected(only, spec["file"]):
			ok = _write(build_rings(spec, next_id, BASE_SEED + i), spec) and ok
		next_id += 1
	for i: int in FOG_SPECS.size():
		var spec: Dictionary = FOG_SPECS[i]
		if _selected(only, spec["file"]):
			ok = _write(build_fog(spec, next_id, BASE_SEED + 100 + i), spec) and ok
		next_id += 1
	for i: int in CARAVAN_SPECS.size():
		var spec: Dictionary = CARAVAN_SPECS[i]
		if _selected(only, spec["file"]):
			ok = _write(build_caravan(spec, next_id, BASE_SEED + 200 + i), spec) and ok
		next_id += 1
	next_id += RETIRED_BOSS_IDS
	for i: int in RINGS_LATER_SPECS.size():
		var spec: Dictionary = RINGS_LATER_SPECS[i]
		if _selected(only, spec["file"]):
			ok = _write(build_rings(spec, next_id, BASE_SEED + 300 + i), spec) and ok
		next_id += 1
	next_id += RETIRED_COMBO_IDS
	var built: int = next_id - Difficulty.MECHANIC_FIRST_ID - RETIRED_BOSS_IDS - RETIRED_COMBO_IDS
	if only.is_empty() or only.begins_with("swap_"):
		var swaps: Array[Level] = build_color_swaps(next_id)
		ok = not swaps.is_empty() and swaps.size() <= SWAP_ID_BLOCK and ok
		built += swaps.size()
		for i: int in swaps.size():
			var spec: Dictionary = {"file": "swap_%02d.json" % (i + 1)}
			if _selected(only, spec["file"]):
				ok = _write(swaps[i], spec) and ok
		if not only.ends_with(".json"):
			_remove_extra_swaps(swaps.size())
	next_id += SWAP_ID_BLOCK
	for i: int in PILOT_SPECS.size():
		var spec: Dictionary = PILOT_SPECS[i]
		if _selected(only, spec["file"]):
			ok = _write(build_pilot(spec, next_id, BASE_SEED + 500 + i), spec) and ok
		next_id += 1
		built += 1
	print("mechanics: %s" % ("%d levels" % built if only.is_empty() else only))
	return ok


## A pilot level of a new mechanic (PILOT_SPECS): classic Hanoi plus the
## mechanic's rule, longer than plain Hanoi; the longest candidate in range
## wins (ties: first found).
static func build_pilot(spec: Dictionary, id: int, seed_value: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var mechanic: String = spec["mechanic"]
	var rule_ids: Array[String] = ["classic_hanoi", mechanic]
	var best: Dictionary = {}
	for attempt: int in spec.get("attempts", MAX_ATTEMPTS / 4):
		var pair: Array[PuzzleState] = _pilot_pair(spec, rng)
		var start: PuzzleState = pair[0]
		var goal: PuzzleState = pair[1]
		if goal.equals(start) or classic_pairs().has(LevelValidator.pair_key(start, goal)):
			continue
		var params: Dictionary = {}
		var own: Dictionary = _pilot_params(spec, goal)
		if not own.is_empty():
			params[mechanic] = own
		var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
		if not rules.is_state_valid(start) or not rules.is_state_valid(goal):
			continue
		if rules.uses_memory() and mechanic == FoundationRule.ID and rules.memory_of(start) != 0:
			continue  # the lock must be closed at the start
		var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
		var moves: int = result["min_moves"]
		if not result["solvable"] or moves < spec["min"] or moves > spec["max"]:
			continue
		if not best.is_empty() and moves <= best["moves"]:
			continue
		if Solver.solve(start, goal, RuleSet.classic())["min_moves"] >= moves:
			continue  # the rule must matter
		var path: Array[Move] = result["path"]
		if mechanic == ChainRule.ID and not path.any(func(move: Move) -> bool: return move.is_compound()):
			continue  # the chain must move
		best = {"moves": moves, "start": start, "goal": goal, "path": path, "params": params}
		if moves >= spec["max"]:
			break  # nothing longer can win
	if best.is_empty():
		push_error("No pilot level found for %s" % spec["file"])
		return null
	var level: Level = Level.create(id, Difficulty.tier_for_moves(best["moves"]), best["start"], best["goal"], rule_ids,
			best["path"], best["params"])
	return level


## A start and a goal for a pilot of `spec`: random positions (the goal a full
## tower half of the time), or as the mechanic needs them.
static func _pilot_pair(spec: Dictionary, rng: RandomNumberGenerator) -> Array[PuzzleState]:
	var pegs: int = spec["pegs"]
	match spec["mechanic"]:
		BalanceRule.ID:
			var positions: Array = _balanced_positions(pegs, spec["disks"], spec["params"]["tolerance"])
			return [positions[rng.randi_range(0, positions.size() - 1)], positions[rng.randi_range(0, positions.size() - 1)]]
		StripesRule.ID:
			var goal: PuzzleState = LevelGenerator.tower_state(pegs, spec["disks"], rng.randi_range(0, pegs - 1)) \
					if rng.randf() < LevelGenerator.TOWER_GOAL_CHANCE else _striped_state(rng, pegs, spec["disks"])
			return [_striped_state(rng, pegs, spec["disks"]), goal]
		MirrorRule.ID:
			var boards: Array = spec["boards"]
			var first: Array[PuzzleState] = _random_pair(rng, pegs / 2, boards[0], 0)
			var second: Array[PuzzleState] = _random_pair(rng, pegs / 2, boards[1], boards[0])
			return [PuzzleState.new(first[0].pegs + second[0].pegs), PuzzleState.new(first[1].pegs + second[1].pegs)]
	return _random_pair(rng, pegs, spec["disks"], 0)


## A random start and goal of `disks` disks numbered from `offset` + 1.
static func _random_pair(rng: RandomNumberGenerator, pegs: int, disks: int, offset: int) -> Array[PuzzleState]:
	var start: PuzzleState = LevelGenerator.random_state(rng, pegs, disks)
	var goal: PuzzleState = LevelGenerator.tower_state(pegs, disks, rng.randi_range(0, pegs - 1)) \
			if rng.randf() < LevelGenerator.TOWER_GOAL_CHANCE else LevelGenerator.random_state(rng, pegs, disks)
	var pair: Array[PuzzleState] = []
	for state: PuzzleState in [start, goal]:
		var layout: Array = []
		for peg: Array in state.pegs:
			layout.append(peg.map(func(disk: int) -> int: return disk + offset))
		pair.append(PuzzleState.new(layout))
	return pair


## The rule settings of a pilot: fixed in the spec, or (foundation) the
## locked and key disks with the keys' goal pegs.
static func _pilot_params(spec: Dictionary, goal: PuzzleState) -> Dictionary:
	if spec["mechanic"] != FoundationRule.ID:
		return spec.get("params", {}).duplicate(true)
	var disks: int = spec["disks"]
	var locked: Array = []
	for i: int in spec["locked"]:
		locked.append(disks - i)
	var keys: Array = []
	var targets: Array = []
	for disk: int in range(1, spec["keys"] + 1):
		keys.append(disk)
		for peg_index: int in goal.pegs.size():
			if goal.pegs[peg_index].has(disk):
				targets.append(peg_index)
	return {"locked": locked, "keys": keys, "targets": targets}


## Every position of `disks` disks on `pegs` pegs whose pairs are within
## `tolerance` (BalanceRule), sorted pegs only.
static func _balanced_positions(pegs: int, disks: int, tolerance: int) -> Array:
	var key: String = "%d/%d/%d" % [pegs, disks, tolerance]
	if not _balanced.has(key):
		var rule: BalanceRule = BalanceRule.new()
		rule.configure({"tolerance": tolerance})
		var found: Array = []
		for code: int in int(pow(pegs, disks)):
			var layout: Array = []
			for i: int in pegs:
				layout.append([])
			var rest: int = code
			for size: int in range(disks, 0, -1):
				layout[rest % pegs].append(size)
				rest /= pegs
			var state: PuzzleState = PuzzleState.new(layout)
			if rule.is_state_valid(state):
				found.append(state)
		_balanced[key] = found
	return _balanced[key]


## A random position whose stacks alternate odd and even sizes (StripesRule):
## each disk, largest first, goes on a peg that is empty or tops another parity.
static func _striped_state(rng: RandomNumberGenerator, pegs: int, disks: int) -> PuzzleState:
	var layout: Array = []
	for i: int in pegs:
		layout.append([])
	for size: int in range(disks, 0, -1):
		var allowed: Array[int] = []
		for peg_index: int in pegs:
			var stack: Array = layout[peg_index]
			if stack.is_empty() or int(stack[-1]) % 2 != size % 2:
				allowed.append(peg_index)
		layout[allowed[rng.randi_range(0, allowed.size() - 1)]].append(size)
	return PuzzleState.new(layout)


## A Nine Rings level: plain Hanoi plus the alternation rule, between a random
## start and a random goal (half of them a full tower). The rule must make the
## puzzle longer than plain Hanoi. Among the candidates in range the longest
## one wins (ties: first found).
static func build_rings(spec: Dictionary, id: int, seed_value: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Dictionary = {}
	var rule_ids: Array[String] = ["classic_hanoi", AlternationRule.ID]
	var rules: RuleSet = RuleSet.from_ids(rule_ids)
	for attempt: int in spec["attempts"]:
		var start: PuzzleState = LevelGenerator.random_state(rng, spec["pegs"], spec["disks"])
		var goal: PuzzleState = LevelGenerator.random_state(rng, spec["pegs"], spec["disks"])
		if rng.randf() < LevelGenerator.TOWER_GOAL_CHANCE:
			goal = LevelGenerator.tower_state(spec["pegs"], spec["disks"], rng.randi_range(0, spec["pegs"] - 1))
		if goal.equals(start) or classic_pairs().has(LevelValidator.pair_key(start, goal)):
			continue
		var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
		var moves: int = result["min_moves"]
		if not result["solvable"] or moves < spec["min"] or moves > spec["max"]:
			continue
		if best.is_empty() or moves > best["moves"]:
			if Solver.solve(start, goal, RuleSet.classic())["min_moves"] >= moves:
				continue  # the alternation must matter
			best = {"moves": moves, "start": start, "goal": goal, "path": result["path"]}
			if moves >= spec["max"]:
				break  # nothing longer can win
	if best.is_empty():
		push_error("No Nine Rings level found for %s" % spec["file"])
		return null
	return Level.create(id, Difficulty.tier_for_moves(best["moves"]), best["start"], best["goal"], rule_ids, best["path"])

## A caravan road level: plain Hanoi plus the adjacent-pegs rule between a
## random start and a random goal (half of them a full tower); the road must
## make it longer than plain Hanoi. Longest in range wins (ties: first found).
static func build_caravan(spec: Dictionary, id: int, seed_value: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Dictionary = {}
	var rule_ids: Array[String] = ["classic_hanoi", AdjacentPegsRule.ID]
	var rules: RuleSet = RuleSet.from_ids(rule_ids)
	for attempt: int in spec.get("attempts", MAX_ATTEMPTS / 4):
		var start: PuzzleState = LevelGenerator.random_state(rng, spec["pegs"], spec["disks"])
		var goal: PuzzleState = LevelGenerator.random_state(rng, spec["pegs"], spec["disks"])
		if rng.randf() < LevelGenerator.TOWER_GOAL_CHANCE:
			goal = LevelGenerator.tower_state(spec["pegs"], spec["disks"], rng.randi_range(0, spec["pegs"] - 1))
		if goal.equals(start) or classic_pairs().has(LevelValidator.pair_key(start, goal)):
			continue
		var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
		var moves: int = result["min_moves"]
		if not result["solvable"] or moves < spec["min"] or moves > spec["max"]:
			continue
		if best.is_empty() or moves > best["moves"]:
			if Solver.solve(start, goal, RuleSet.classic())["min_moves"] >= moves:
				continue  # the road must matter
			best = {"moves": moves, "start": start, "goal": goal, "path": result["path"]}
			if moves >= spec["max"]:
				break  # nothing longer can win
	if best.is_empty():
		push_error("No caravan level found for %s" % spec["file"])
		return null
	return Level.create(id, Difficulty.tier_for_moves(best["moves"]), best["start"], best["goal"], rule_ids, best["path"])


## Every great exchange level of SWAP_BOARDS, easiest first (the pure kind
## first on a tie), with ids from `first_id` in that order. Empty if a board
## gives no level at all.
static func build_color_swaps(first_id: int) -> Array[Level]:
	var found: Array[Dictionary] = []
	for board_index: int in SWAP_BOARDS.size():
		var board: Dictionary = SWAP_BOARDS[board_index]
		var mixed: bool = board["kind"] == "mixed"
		var k: int = board["k"]
		var patterns: Array[int] = [-1]
		if mixed:
			# Bit s - 1 set: the white disk of size s starts on the left. The
			# largest one always does (the largest pair is on the wrong ends), and
			# neither end may be of one colour.
			patterns.clear()
			for pattern: int in 1 << (k - 1):
				var full: int = pattern | 1 << (k - 1)
				if full != (1 << k) - 1:
					patterns.append(full)
		var before: int = found.size()
		for pattern: int in patterns:
			var start: PuzzleState = color_swap_start(k, board["buffers"], pattern)
			var goal: PuzzleState = color_swap_goal(k, board["buffers"])
			var rules: RuleSet = RuleSet.from_ids([ColorSwapRule.ID], {ColorSwapRule.ID: {"colour": mixed}})
			var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
			var moves: int = result["min_moves"]
			if not result["solvable"] or moves < SWAP_MIN_MOVES or moves > SWAP_MAX_MOVES:
				continue
			found.append({"moves": moves, "mixed": mixed, "order": board_index * 1000 + pattern + 1,
					"start": start, "goal": goal, "path": result["path"]})
		if found.size() == before:
			push_error("The great exchange board %s gives no level" % str(board))
			return [] as Array[Level]
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["moves"] != b["moves"]:
			return a["moves"] < b["moves"]
		return a["order"] < b["order"])
	var levels: Array[Level] = []
	var rule_ids: Array[String] = [ColorSwapRule.ID]
	for i: int in found.size():
		var item: Dictionary = found[i]
		levels.append(Level.create(first_id + i, Difficulty.tier_for_moves(item["moves"]), item["start"], item["goal"],
				rule_ids, item["path"], {ColorSwapRule.ID: {"colour": item["mixed"]}}))
	return levels


## The start of a great exchange board: k disks on each end peg (largest at the
## bottom), `buffers` empty pegs between. `pattern` -1: the pure kind (all
## white on the left); else bit s - 1 set puts the white disk of size s on the
## left and its black twin on the right, and the other way round when clear.
static func color_swap_start(k: int, buffers: int, pattern: int) -> PuzzleState:
	var pegs: Array = []
	for i: int in buffers + 2:
		pegs.append([])
	for size: int in range(k, 0, -1):
		var white_left: bool = pattern < 0 or (pattern >> (size - 1)) & 1 == 1
		pegs[0].append(ColorSwapRule.disk_of(size, white_left))
		pegs[-1].append(ColorSwapRule.disk_of(size, not white_left))
	return PuzzleState.new(pegs)


## The goal of every great exchange board: all black disks on the left end,
## all white ones on the right.
static func color_swap_goal(k: int, buffers: int) -> PuzzleState:
	var pegs: Array = []
	for i: int in buffers + 2:
		pegs.append([])
	for size: int in range(k, 0, -1):
		pegs[0].append(ColorSwapRule.disk_of(size, false))
		pegs[-1].append(ColorSwapRule.disk_of(size, true))
	return PuzzleState.new(pegs)


## Deletes great exchange files numbered past `count` (left over from a run
## with more boards), so every file on disk is one this run built.
static func _remove_extra_swaps(count: int) -> void:
	for file_name: String in DirAccess.get_files_at(MECHANICS_DIR):
		if file_name.begins_with("swap_") and file_name.trim_prefix("swap_").to_int() > count:
			DirAccess.remove_absolute("%s/%s" % [MECHANICS_DIR, file_name])


## A covered-peg level: plain Hanoi, with `spec.covered` pegs under fog. Only
## pegs that hold at least two disks and that the stored optimal solution uses
## within its first LevelValidator.COVERED_REVEAL_WITHIN moves may be covered.
static func build_fog(spec: Dictionary, id: int, seed_value: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Dictionary = {}
	var rule_ids: Array[String] = ["classic_hanoi"]
	for attempt: int in spec.get("attempts", MAX_ATTEMPTS / 4):
		var start: PuzzleState = LevelGenerator.random_state(rng, spec["pegs"], spec["disks"])
		var goal: PuzzleState = LevelGenerator.random_state(rng, spec["pegs"], spec["disks"])
		if rng.randf() < LevelGenerator.TOWER_GOAL_CHANCE:
			goal = LevelGenerator.tower_state(spec["pegs"], spec["disks"], rng.randi_range(0, spec["pegs"] - 1))
		if goal.equals(start) or classic_pairs().has(LevelValidator.pair_key(start, goal)):
			continue
		var result: Dictionary = Solver.solve(start, goal, RuleSet.classic(), LevelValidator.SOLVER_MAX_STATES)
		var moves: int = result["min_moves"]
		if not result["solvable"] or moves < spec["min"] or moves > spec["max"]:
			continue
		var path: Array[Move] = result["path"]
		var candidates: Array[int] = []
		for peg_index: int in spec["pegs"]:
			if start.pegs[peg_index].size() < 2:
				continue
			for i: int in mini(LevelValidator.COVERED_REVEAL_WITHIN, path.size()):
				if (path[i].from_peg == peg_index or path[i].to_peg == peg_index) and not candidates.has(peg_index):
					candidates.append(peg_index)
		if candidates.size() < spec["covered"]:
			continue
		if best.is_empty() or moves > best["moves"]:
			# Seeded shuffle (Array.shuffle() would use the global generator and
			# make reruns differ).
			for i: int in range(candidates.size() - 1, 0, -1):
				var j: int = rng.randi_range(0, i)
				var swap: int = candidates[i]
				candidates[i] = candidates[j]
				candidates[j] = swap
			var covered: Array[int] = candidates.slice(0, spec["covered"])
			covered.sort()
			best = {"moves": moves, "start": start, "goal": goal, "path": path, "covered": covered}
			if moves >= spec["max"]:
				break  # nothing longer can win
	if best.is_empty():
		push_error("No fog level found for %s" % spec["file"])
		return null
	var level: Level = Level.create(id, Difficulty.tier_for_moves(best["moves"]), best["start"], best["goal"], rule_ids, best["path"])
	level.covered_pegs = best["covered"]
	return level


## A seeded shuffle (Array.shuffle() uses the global generator).
static func _shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var copy: Array = items.duplicate()
	for i: int in range(copy.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = swap
	return copy


## Whether `file` is built in this run: all with no --only, else the named
## file or, with a trailing "*", every file starting like it.
static func _selected(only: String, file: String) -> bool:
	if only.is_empty():
		return true
	return file.begins_with(only.trim_suffix("*")) if only.ends_with("*") else file == only


## Start/goal pairs of every classic level file (read once).
static func classic_pairs() -> Dictionary:
	if _classic_pairs.is_empty():
		for tier: String in Difficulty.ORDER:
			for index: int in range(1, LevelCatalog.level_count(tier) + 1):
				var level: Level = LevelCatalog.load_level(tier, index)
				_classic_pairs[LevelValidator.pair_key(level.start, level.goal)] = true
	return _classic_pairs


func _write(level: Level, spec: Dictionary) -> bool:
	if level == null:
		return false
	var path: String = "%s/%s" % [MECHANICS_DIR, spec["file"]]
	level.save_file(path)
	var errors: Array[String] = []
	LevelValidator.load_and_validate(path, errors)
	print("%s: id %d, %s, %d pegs / %d disks, min_moves %d, rules %s %s" % [spec["file"], level.id, level.difficulty,
			level.get_peg_count(), level.get_disk_count(), level.min_moves, str(level.rule_ids), JSON.stringify(level.rule_params)])
	for error: String in errors:
		printerr("  - %s" % error)
	return errors.is_empty()
