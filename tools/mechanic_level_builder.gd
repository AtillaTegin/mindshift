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
	print("mechanics: %s" % ("%d levels" % built if only.is_empty() else only))
	return ok


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
