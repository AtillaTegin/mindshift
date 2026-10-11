class_name LevelGenerator
extends SceneTree
## Generates levels into data/levels/<difficulty>/ (spec 4.4).
##   godot --headless --path . --script res://tools/level_generator.gd -- --difficulty=medium --count=76
##   godot --headless --path . --script res://tools/level_generator.gd -- --difficulty=all
## Options: --difficulty=easy|medium|hard|expert|all (default all), --count=N
## (default: the tier's Difficulty.default_count), --seed=N (default: a fixed
## seed per difficulty, so reruns give the same files).
## Afterwards run tools/path_builder.gd: it places the levels on the level path.
## A run replaces the difficulty's previous <difficulty>_NNN.json files. Every
## file is re-read and checked by LevelValidator right after it is written.
## Exits with code 0 only when all requested levels were written and validated.

const LEVELS_DIR: String = Difficulty.LEVELS_DIR
const BASE_SEED: int = 20261006
const RULE_IDS: Array[String] = ["classic_hanoi"]
## Share of goals that are a full tower on one peg; the rest are random positions.
const TOWER_GOAL_CHANCE: float = 0.5
## Give up when this many puzzles per requested level have been tried.
const MAX_ATTEMPTS_PER_LEVEL: int = 200


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	var tiers: Array[String] = Difficulty.ORDER.duplicate()
	# -1: each tier's own default count.
	var count: int = -1
	var seed_override: int = -1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--difficulty="):
			var tier: String = arg.trim_prefix("--difficulty=")
			if tier != "all":
				if not Difficulty.is_known(tier):
					printerr("Unknown difficulty \"%s\" (use %s or all)" % [tier, ", ".join(Difficulty.ORDER)])
					return false
				tiers = [tier]
		elif arg.begins_with("--count="):
			count = arg.trim_prefix("--count=").to_int()
		elif arg.begins_with("--seed="):
			seed_override = arg.trim_prefix("--seed=").to_int()
	if count != -1 and (count < 1 or count > Difficulty.MAX_LEVELS_PER_TIER):
		printerr("--count must be between 1 and %d" % Difficulty.MAX_LEVELS_PER_TIER)
		return false

	var ok: bool = true
	for tier: String in tiers:
		var started_ms: int = Time.get_ticks_msec()
		var seed_value: int = seed_override if seed_override >= 0 else default_seed(tier)
		var stats: Dictionary = {}
		var tier_count: int = count if count != -1 else Difficulty.default_count(tier)
		var levels: Array[Level] = generate(tier, tier_count, seed_value, stats)
		print("%s: %d/%d levels, %d puzzles tried, min_moves %s, seed %d (%d ms)" % [
				tier, levels.size(), tier_count, stats["attempts"], _range_text(levels), seed_value,
				Time.get_ticks_msec() - started_ms])
		if levels.size() < tier_count:
			printerr("%s: gave up after %d attempts" % [tier, stats["attempts"]])
			ok = false
			continue
		ok = _write_tier(tier, levels) and ok
	return ok


static func default_seed(tier: String) -> int:
	return BASE_SEED + Difficulty.ORDER.find(tier)


## Generates `count` distinct, solver-verified levels for `tier`, sorted by
## min_moves (easiest first) and numbered from the tier's first id. Returns
## fewer levels if the attempt budget runs out. `stats` receives "attempts".
static func generate(tier: String, count: int, seed_value: int, stats: Dictionary = {}) -> Array[Level]:
	var settings: Dictionary = Difficulty.get_tier(tier)
	var rules: RuleSet = RuleSet.from_ids(RULE_IDS)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var seen_pairs: Dictionary[String, bool] = {}
	var found: Array[Dictionary] = []
	var attempts: int = 0
	var max_attempts: int = count * MAX_ATTEMPTS_PER_LEVEL
	while found.size() < count and attempts < max_attempts:
		attempts += 1
		var peg_count: int = rng.randi_range(settings["min_pegs"], settings["max_pegs"])
		var disk_count: int = rng.randi_range(settings["min_disks"], settings["max_disks"])
		var start: PuzzleState = random_state(rng, peg_count, disk_count)
		var goal: PuzzleState
		if rng.randf() < TOWER_GOAL_CHANCE:
			goal = tower_state(peg_count, disk_count, rng.randi_range(0, peg_count - 1))
		else:
			goal = random_state(rng, peg_count, disk_count)
		if start.equals(goal):
			continue
		var pair: String = LevelValidator.pair_key(start, goal)
		if seen_pairs.has(pair):
			continue
		seen_pairs[pair] = true
		var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
		if result["solvable"] and Difficulty.accepts_moves(tier, result["min_moves"]):
			found.append({"start": start, "goal": goal, "path": result["path"], "pair": pair})
	stats["attempts"] = attempts

	# Easiest first; ties broken by size and then by the puzzle itself so the
	# order never depends on anything but the seed.
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var moves_a: int = a["path"].size()
		var moves_b: int = b["path"].size()
		if moves_a != moves_b:
			return moves_a < moves_b
		var disks_a: int = (a["start"] as PuzzleState).get_disk_count()
		var disks_b: int = (b["start"] as PuzzleState).get_disk_count()
		if disks_a != disks_b:
			return disks_a < disks_b
		return a["pair"] < b["pair"])
	var levels: Array[Level] = []
	for i: int in found.size():
		var entry: Dictionary = found[i]
		var path: Array[Move] = entry["path"]
		levels.append(Level.create(settings["first_id"] + i, tier, entry["start"], entry["goal"], RULE_IDS, path))
	return levels


## Every disk on a random peg; each peg is sorted, so the position is legal.
static func random_state(rng: RandomNumberGenerator, peg_count: int, disk_count: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	for size: int in range(disk_count, 0, -1):
		layout[rng.randi_range(0, peg_count - 1)].append(size)
	return PuzzleState.new(layout)


## All disks stacked on one peg.
static func tower_state(peg_count: int, disk_count: int, on_peg: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	for size: int in range(disk_count, 0, -1):
		layout[on_peg].append(size)
	return PuzzleState.new(layout)


## Replaces the tier's level files and validates each one right after writing.
func _write_tier(tier: String, levels: Array[Level]) -> bool:
	var dir_path: String = "%s/%s" % [LEVELS_DIR, tier]
	DirAccess.make_dir_recursive_absolute(dir_path)
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		printerr("Cannot open %s" % dir_path)
		return false
	for old_file: String in dir.get_files():
		if old_file.begins_with(tier + "_") and old_file.ends_with(".json"):
			dir.remove(old_file)
	var ok: bool = true
	for i: int in levels.size():
		var path: String = Difficulty.level_path(tier, i + 1, LEVELS_DIR)
		var save_error: Error = levels[i].save_file(path)
		if save_error != OK:
			printerr("Cannot write %s: %s" % [path, error_string(save_error)])
			ok = false
			continue
		var errors: Array[String] = []
		LevelValidator.load_and_validate(path, errors)
		if not errors.is_empty():
			ok = false
			printerr("Validation failed for %s:" % path)
			for error: String in errors:
				printerr("  - %s" % error)
	print("%s: wrote %d files to %s%s" % [tier, levels.size(), dir_path, "" if ok else " (with errors)"])
	return ok


static func _range_text(levels: Array[Level]) -> String:
	if levels.is_empty():
		return "-"
	return "%d..%d" % [levels[0].min_moves, levels[-1].min_moves]
