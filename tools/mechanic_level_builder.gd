class_name MechanicLevelBuilder
extends SceneTree
## Builds the levels with a special mechanic (bonus mechanics addendum: frozen
## disk, covered pegs) into data/levels/mechanics/:
##   godot --headless --path . --script res://tools/mechanic_level_builder.gd
##   ... -- --only=fog_20.json   (rebuild one file; ids and seeds stay the same)
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

## Frozen-disk levels, from easy to hard. Move ranges are targets for the search. All use 4 pegs:
## with 3 pegs, or fewer than 6 disks, a frozen disk that sits on another disk
## practically never changes the shortest solution (measured 2026-10-09).
const FROZEN_SPECS: Array[Dictionary] = [
	{"file": "frozen_01.json", "pegs": 4, "disks": 6, "min": 8, "max": 11},
	{"file": "frozen_02.json", "pegs": 4, "disks": 7, "min": 12, "max": 15},
	{"file": "frozen_03.json", "pegs": 4, "disks": 8, "min": 18, "max": 24},
	{"file": "frozen_04.json", "pegs": 4, "disks": 8, "min": 26, "max": 33},
]

## Covered-peg (karakuri box) levels, from easy to hard: the first ones are
## small (3 disks, one box), later ones grow to 8 disks and two boxes (user
## request 2026-10-12: ~20 of them, starting right after the tutorial and
## getting harder step by step). `covered`: how many pegs start as boxes.
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
]


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
	for i: int in FROZEN_SPECS.size():
		var spec: Dictionary = FROZEN_SPECS[i]
		if only.is_empty() or only == spec["file"]:
			ok = _write(build_frozen(spec, next_id, BASE_SEED + i), spec) and ok
		next_id += 1
	for i: int in FOG_SPECS.size():
		var spec: Dictionary = FOG_SPECS[i]
		if only.is_empty() or only == spec["file"]:
			ok = _write(build_fog(spec, next_id, BASE_SEED + 100 + i), spec) and ok
		next_id += 1
	print("mechanics: %s" % ("%d levels" % (next_id - Difficulty.MECHANIC_FIRST_ID) if only.is_empty() else only))
	return ok


## A frozen-disk level: the frozen disk sits in the middle of a stack (not at
## the bottom) and the freeze must make the puzzle longer than plain Hanoi.
## Among the candidates in range the longest one wins (ties: first found).
static func build_frozen(spec: Dictionary, id: int, seed_value: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Dictionary = {}
	var rule_ids: Array[String] = ["classic_hanoi", "frozen_disk"]
	for attempt: int in MAX_ATTEMPTS:
		var start: PuzzleState = LevelGenerator.random_state(rng, spec["pegs"], spec["disks"])
		var frozen: int = _middle_disk(start, rng)
		if frozen == -1:
			continue
		var goal: PuzzleState = _goal_keeping_base(start, frozen, rng)
		if goal == null or goal.equals(start):
			continue
		var params: Dictionary = {"frozen_disk": {"disk_size": frozen}}
		var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
		var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
		var moves: int = result["min_moves"]
		if not result["solvable"] or moves < spec["min"] or moves > spec["max"]:
			continue
		if Solver.solve(start, goal, RuleSet.classic())["min_moves"] >= moves:
			continue  # the freeze must matter
		if best.is_empty() or moves > best["moves"]:
			best = {"moves": moves, "start": start, "goal": goal, "path": result["path"], "params": params}
	if best.is_empty():
		push_error("No frozen level found for %s" % spec["file"])
		return null
	return Level.create(id, Difficulty.tier_for_moves(best["moves"]), best["start"], best["goal"], rule_ids, best["path"], best["params"])


## A covered-peg level: plain Hanoi, with `spec.covered` pegs under fog. Only
## pegs that hold at least two disks and that the stored optimal solution uses
## within its first LevelValidator.COVERED_REVEAL_WITHIN moves may be covered.
static func build_fog(spec: Dictionary, id: int, seed_value: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var best: Dictionary = {}
	var rule_ids: Array[String] = ["classic_hanoi"]
	for attempt: int in MAX_ATTEMPTS / 4:
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


## A random disk that has at least one disk below it on its peg and is not the
## smallest (so smaller disks can still rest on it), or -1.
static func _middle_disk(state: PuzzleState, rng: RandomNumberGenerator) -> int:
	var candidates: Array[int] = []
	for peg: Array in state.pegs:
		for i: int in range(1, peg.size()):
			if int(peg[i]) > 1:
				candidates.append(peg[i])
	return candidates[rng.randi_range(0, candidates.size() - 1)] if not candidates.is_empty() else -1


## A random goal in which the frozen disk and every disk under it stay put;
## all other disks are spread at random (each peg stays sorted).
static func _goal_keeping_base(start: PuzzleState, frozen: int, rng: RandomNumberGenerator) -> PuzzleState:
	var layout: Array = []
	var frozen_peg: int = -1
	for peg_index: int in start.get_peg_count():
		var peg: Array = start.pegs[peg_index]
		if peg.has(frozen):
			frozen_peg = peg_index
			layout.append(peg.slice(0, peg.find(frozen) + 1))
		else:
			layout.append([])
	for disk: int in range(start.get_disk_count(), 0, -1):
		if layout[frozen_peg].has(disk):
			continue
		# Only disks smaller than the frozen one can rest on it.
		var choices: Array[int] = []
		for peg_index: int in start.get_peg_count():
			if peg_index != frozen_peg or disk < frozen:
				choices.append(peg_index)
		layout[choices[rng.randi_range(0, choices.size() - 1)]].append(disk)
	return PuzzleState.new(layout)


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
