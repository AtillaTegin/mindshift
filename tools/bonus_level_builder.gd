class_name BonusLevelBuilder
extends SceneTree
## Builds the bonus levels (bonus mechanics addendum) into data/levels/bonus/
## and writes data/levels/bonus/index.json (file, id and level-select tab):
##   godot --headless --path . --script res://tools/bonus_level_builder.gd
## Separate from LevelGenerator on purpose: the main generator and the 200 main
## levels stay untouched. Puzzles come from a fixed-seed search; the Solver
## proves every min_moves and LevelValidator checks every file it writes.
## Exits with code 0 only when every level was built and validated.

const BONUS_DIR: String = Difficulty.LEVELS_DIR + "/" + Difficulty.BONUS
const INDEX_FILE: String = "index.json"
const BASE_SEED: int = 20261009
const MAX_ATTEMPTS: int = 8000

## One entry per bonus level, one frozen-disk level per tab (difficulty rises
## from tab to tab). Move ranges are targets for the search. All use 4 pegs:
## with 3 pegs, or fewer than 6 disks, a frozen disk that sits on another disk
## practically never changes the shortest solution (measured 2026-10-09).
const FROZEN_SPECS: Array[Dictionary] = [
	{"file": "frozen_01.json", "tab": "easy", "pegs": 4, "disks": 6, "min": 8, "max": 11},
	{"file": "frozen_02.json", "tab": "medium", "pegs": 4, "disks": 7, "min": 12, "max": 15},
	{"file": "frozen_03.json", "tab": "hard", "pegs": 4, "disks": 8, "min": 18, "max": 24},
	{"file": "frozen_04.json", "tab": "expert", "pegs": 4, "disks": 8, "min": 26, "max": 33},
]


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	DirAccess.make_dir_recursive_absolute(BONUS_DIR)
	var index: Array[Dictionary] = []
	var ok: bool = true
	var next_id: int = Difficulty.BONUS_FIRST_ID
	for i: int in FROZEN_SPECS.size():
		var spec: Dictionary = FROZEN_SPECS[i]
		var level: Level = build_frozen(spec, next_id, BASE_SEED + i)
		ok = _write(level, spec, index) and ok
		next_id += 1
	var file: FileAccess = FileAccess.open("%s/%s" % [BONUS_DIR, INDEX_FILE], FileAccess.WRITE)
	file.store_string(JSON.stringify({"levels": index}, "  ") + "\n")
	file.close()
	print("bonus: %d levels, index written" % index.size())
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
	return Level.create(id, Difficulty.BONUS, best["start"], best["goal"], rule_ids, best["path"], best["params"])


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


func _write(level: Level, spec: Dictionary, index: Array[Dictionary]) -> bool:
	if level == null:
		return false
	var path: String = "%s/%s" % [BONUS_DIR, spec["file"]]
	level.save_file(path)
	var errors: Array[String] = []
	LevelValidator.load_and_validate(path, errors)
	print("%s: id %d, %d pegs / %d disks, min_moves %d, rules %s %s" % [spec["file"], level.id,
			level.get_peg_count(), level.get_disk_count(), level.min_moves, str(level.rule_ids), JSON.stringify(level.rule_params)])
	for error: String in errors:
		printerr("  - %s" % error)
	index.append({"file": spec["file"], "id": level.id, "tab": spec["tab"]})
	return errors.is_empty()
