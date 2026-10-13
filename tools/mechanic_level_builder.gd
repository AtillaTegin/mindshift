class_name MechanicLevelBuilder
extends SceneTree
## Builds the levels with a special mechanic (Nine Rings alternation, karakuri
## boxes on covered pegs, the caravan road, the great exchange bosses, the
## "Birləşmə Tapmacası" combination puzzles) into data/levels/mechanics/:
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
## road, easy to hard like the karakuri). Built after the bosses so the ids of
## every earlier level stay the same; the path sorts them by length anyway.
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

## "Böyük Mübadilə" bosses (caravan road addendum, section 2): 4 pegs, one
## stack on each end peg, and the goal is the two stacks swapped. `split`:
## "halves" (small disks on the left) or "interleaved" (odd sizes on the left).
## Some keep plain Hanoi rules, some the caravan road's ("the chapter's rule"),
## so the five rise from 17 to 33 moves (measured 2026-10-12; a caravan swap
## of 5 disks would already need 37+).
const BOSS_SPECS: Array[Dictionary] = [
	{"file": "boss_01.json", "disks": 7, "split": "halves", "caravan": false},
	{"file": "boss_02.json", "disks": 4, "split": "halves", "caravan": true},
	{"file": "boss_03.json", "disks": 4, "split": "interleaved", "caravan": true},
	{"file": "boss_04.json", "disks": 9, "split": "interleaved", "caravan": false},
	{"file": "boss_05.json", "disks": 10, "split": "halves", "caravan": false},
]

## "Birləşmə Tapmacası" levels (level structure v4 section 4, correction v2,
## user decisions 2026-10-13). Each level's size comes from its stage on the
## road (Difficulty.COMBINATION_STAGES: peg capacity N, C colours of N disks
## each, E empty pegs), so the builder first works out where the levels will
## land (combination_positions). Inside a stage sizes grow along it, with
## seeded variety. Goals follow the v4 gradient: "Sadə Yığım" (sort) in the
## first two stages, both kinds in the third, "Konkret Kombinasiya" (a full
## colour sequence for every peg) after that.
const COMBO_COUNT: int = 30
## Starts tried per level before giving up.
const COMBO_ATTEMPTS: int = 40
## Positions the guided search may expand per start.
const COMBO_BUDGET: int = 80000


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
	for i: int in BOSS_SPECS.size():
		var spec: Dictionary = BOSS_SPECS[i]
		if _selected(only, spec["file"]):
			ok = _write(build_exchange(spec, next_id), spec) and ok
		next_id += 1
	for i: int in RINGS_LATER_SPECS.size():
		var spec: Dictionary = RINGS_LATER_SPECS[i]
		if _selected(only, spec["file"]):
			ok = _write(build_rings(spec, next_id, BASE_SEED + 300 + i), spec) and ok
		next_id += 1
	var first_combo: int = next_id
	var positions: Array[int] = []
	for i: int in COMBO_COUNT:
		var spec: Dictionary = {"file": "combo_%02d.json" % (i + 1)}
		if _selected(only, spec["file"]):
			if positions.is_empty():
				positions = combination_positions(first_combo)
				if positions.size() != COMBO_COUNT:
					printerr("Cannot work out where the combination levels land on the road")
					return false
			spec.merge(combination_spec(i, positions[i], BASE_SEED + 400 + i))
			ok = _write(build_combination(spec, next_id, BASE_SEED + 400 + i, _earlier_shapes(i)), spec) and ok
		next_id += 1
	print("mechanics: %s" % ("%d levels" % (next_id - Difficulty.MECHANIC_FIRST_ID) if only.is_empty() else only))
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


## A great exchange boss: the left and right stacks of a 4-peg board swap
## places. No search for the puzzle itself, only the Solver for its minimum.
static func build_exchange(spec: Dictionary, id: int) -> Level:
	var left: Array = []
	var right: Array = []
	for size: int in range(spec["disks"], 0, -1):
		var to_left: bool = size % 2 == 1 if spec["split"] == "interleaved" else size <= spec["disks"] / 2
		(left if to_left else right).append(size)
	var start: PuzzleState = PuzzleState.new([left, [], [], right])
	var goal: PuzzleState = PuzzleState.new([right, [], [], left])
	var rule_ids: Array[String] = ["classic_hanoi"]
	if spec["caravan"]:
		rule_ids.append(AdjacentPegsRule.ID)
	var result: Dictionary = Solver.solve(start, goal, RuleSet.from_ids(rule_ids), LevelValidator.SOLVER_MAX_STATES)
	if not result["solvable"]:
		push_error("No solution for %s" % spec["file"])
		return null
	var level: Level = Level.create(id, Difficulty.tier_for_moves(result["min_moves"]), start, goal, rule_ids, result["path"])
	level.boss = Level.GREAT_EXCHANGE
	return level


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


## Main path positions the combination levels will get, in chapter order: the
## path builder run with stand-ins for them (the first one easy, as its stage
## is; the rest not), since a level's stage depends on its position.
static func combination_positions(first_id: int) -> Array[int]:
	var errors: Array[String] = []
	var pools: Dictionary = {}
	for tier: String in Difficulty.ORDER:
		pools[tier] = PathBuilder.read_folder(Difficulty.LEVELS_DIR, tier, errors)
	var mechanics: Array[Dictionary] = []
	for file_name: String in DirAccess.get_files_at(MECHANICS_DIR):
		if not file_name.ends_with(".json") or file_name.begins_with("combo_"):
			continue
		var level: Level = Level.load_file("%s/%s" % [MECHANICS_DIR, file_name], errors)
		if level != null:
			mechanics.append({"file": "%s/%s" % [Difficulty.MECHANICS, file_name], "id": level.id, "level": level})
	for i: int in COMBO_COUNT:
		var stand_in: Level = Level.new()
		stand_in.id = first_id + i
		stand_in.rule_ids.assign([CombinationRule.ID])
		stand_in.difficulty = "easy" if i == 0 else "medium"
		mechanics.append({"file": "%s/combo_%02d.json" % [Difficulty.MECHANICS, i + 1], "id": stand_in.id, "level": stand_in})
	var positions: Array[int] = []
	var path: Dictionary = PathBuilder.build_from(pools, mechanics, errors)
	if not errors.is_empty():
		printerr("; ".join(errors))
		return positions
	var main: Array = path[LevelCatalog.MAIN]
	for i: int in main.size():
		var id: int = main[i]["id"]
		if id >= first_id and id < first_id + COMBO_COUNT:
			positions.append(i + 1)
	return positions


## Size and goal of the combination level at main path `position` (its stage
## in Difficulty.COMBINATION_STAGES), drawn with `seed_value`.
static func combination_spec(index: int, position: int, seed_value: int) -> Dictionary:
	var stage: Dictionary = Difficulty.combination_stage(position)
	var stage_from: int = 1
	for earlier: Dictionary in Difficulty.COMBINATION_STAGES:
		if earlier == stage:
			break
		stage_from = earlier["to"] + 1
	var progress: float = clampf(float(position - stage_from) / maxf(stage["to"] - stage_from, 1.0), 0.0, 1.0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var capacity: int = _grow(stage["capacity"], progress, rng)
	var colours: int = _grow(stage["colours"], progress, rng)
	var empty: int = _grow(stage["empty"], progress, rng)
	# T = C + E stays inside the stage's peg range.
	empty = clampi(empty, maxi(stage["empty"][0], stage["pegs"][0] - colours), mini(stage["empty"][1], stage["pegs"][1] - colours))
	var kind: String = ColorGoal.PATTERN
	match stage["name"]:
		"intro", "middle_1":
			kind = ColorGoal.SORT
		"middle_2":
			kind = ColorGoal.SORT if index % 2 == 0 else ColorGoal.PATTERN
	return {"stage": stage["name"], "tier": stage["tier"], "position": position, "capacity": capacity,
			"colours": colours, "empty": empty, "kind": kind}


## A value in `bounds` ([min, max]) that grows with `progress` (0..1) through
## the stage, give or take a little.
static func _grow(bounds: Array, progress: float, rng: RandomNumberGenerator) -> int:
	return bounds[0] + roundi((bounds[1] - bounds[0]) * clampf(progress + rng.randf_range(-0.35, 0.35), 0.0, 1.0))


## A "Birləşmə Tapmacası" level from a combination_spec(): `colours` colours of
## `capacity` disks each, shuffled onto that many full pegs with `empty` empty
## pegs among them (Water Sort's start). A pattern goal is the same disks
## shuffled into a full, mixed colour sequence for every peg that ends full.
## Only a start with a solution found by search is kept (breadth-first, so the
## shortest, while there are at most 10 disks; else guided search within
## COMBO_BUDGET): that solution is stored and proves the level solvable.
## Starts that are partly done already, or an earlier level in other colours
## (`used`: ColorGoal.shape_key), are skipped.
static func build_combination(spec: Dictionary, id: int, seed_value: int, used: Dictionary = {}) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var capacity: int = spec["capacity"]
	var peg_count: int = spec["colours"] + spec["empty"]
	for attempt: int in spec.get("attempts", COMBO_ATTEMPTS):
		var disks: Array = []
		for color_name: String in _shuffled(ColorGoal.LETTERS.keys(), rng).slice(0, spec["colours"]):
			for k: int in capacity:
				disks.append(ColorGoal.letter_of(color_name))
		var goal: ColorGoal = ColorGoal.sort()
		if spec["kind"] == ColorGoal.PATTERN:
			var stacks: Array = _stacks(_shuffled(disks, rng), capacity)
			if stacks.any(func(text: String) -> bool: return text.count(text[0]) == text.length()):
				continue  # every target peg shows a combination of colours
			var targets: Array = []
			for text: String in _place(stacks, peg_count, rng):
				var target: Array = []
				for letter: String in text:
					target.append(ColorGoal.colour_of(letter))
				targets.append(target)
			goal = ColorGoal.pattern(targets)
		var start: PackedStringArray = _place(_stacks(_shuffled(disks, rng), capacity), peg_count, rng)
		if goal.matches(start) or _half_done(goal, start) or used.has(goal.shape_key(start)):
			continue
		var result: Dictionary = CombinationSolver.search(start, capacity, goal) if disks.size() <= 10 \
				else CombinationSolver.guided_search(start, capacity, goal, COMBO_BUDGET)
		if not result["solvable"]:
			continue
		return _combination_level(id, spec, start, goal, CombinationSolver.shorten(start, result["path"]))
	push_error("No combination level found for %s" % spec["file"])
	return null


## The level for a found start and solution: disk ids 1..N in the order they
## stand, peg by peg, bottom to top; the goal position is where the solution ends.
static func _combination_level(id: int, spec: Dictionary, pegs: PackedStringArray, goal: ColorGoal, path: Array[Move]) -> Level:
	var layout: Array = []
	var colours: Array[String] = []
	for text: String in pegs:
		var peg: Array = []
		for letter: String in text:
			colours.append(ColorGoal.colour_of(letter))
			peg.append(colours.size())
		layout.append(peg)
	var start: PuzzleState = PuzzleState.new(layout)
	var rule_ids: Array[String] = [CombinationRule.ID]
	var params: Dictionary = {CombinationRule.ID: {"capacity": spec["capacity"]}}
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	var position: PuzzleState = start
	for move: Move in path:
		position = rules.apply_move(position, move)
	var level: Level = Level.create(id, spec["tier"], start, position, rule_ids, path, params)
	level.disk_colors = colours
	level.color_goal = goal
	return level


## `letters` cut into stacks of `size`.
static func _stacks(letters: Array, size: int) -> Array:
	var stacks: Array = []
	for i: int in range(0, letters.size(), size):
		stacks.append("".join(PackedStringArray(letters.slice(i, i + size))))
	return stacks


## `stacks` on random pegs of `peg_count`, the others empty.
static func _place(stacks: Array, peg_count: int, rng: RandomNumberGenerator) -> PackedStringArray:
	var order: Array = _shuffled(range(peg_count), rng)
	var pegs: PackedStringArray = PackedStringArray()
	pegs.resize(peg_count)
	for i: int in stacks.size():
		pegs[order[i]] = stacks[i]
	return pegs


## ColorGoal.shape_key of the combination levels built before combo number
## `index` (read from their files), so a later one never repeats one in other
## colours.
static func _earlier_shapes(index: int) -> Dictionary:
	var shapes: Dictionary = {}
	for i: int in index:
		var errors: Array[String] = []
		var level: Level = Level.load_file("%s/combo_%02d.json" % [MECHANICS_DIR, i + 1], errors)
		if level != null and level.color_goal != null:
			shapes[LevelValidator.puzzle_key(level)] = true
	return shapes


## A start that is partly done already: a peg of one colour only (sort), or a
## peg whose two bottom disks are already right (pattern).
static func _half_done(goal: ColorGoal, pegs: PackedStringArray) -> bool:
	for peg_index: int in pegs.size():
		var text: String = pegs[peg_index]
		if goal.kind == ColorGoal.SORT:
			if not text.is_empty() and text.count(text[0]) == text.length():
				return true
		elif goal.placed_on(pegs, peg_index) >= mini(2, text.length()) and not text.is_empty():
			return true
	return false


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
