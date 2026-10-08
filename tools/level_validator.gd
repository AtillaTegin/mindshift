class_name LevelValidator
extends SceneTree
## Re-checks level JSON files, including that min_moves is really the minimum
## (the Solver is run again for every level).
##   godot --headless --path . --script res://tools/level_validator.gd
##   godot --headless --path . --script res://tools/level_validator.gd -- --require=50
##   godot --headless --path . --script res://tools/level_validator.gd -- --dir=res://data/levels
## --require=N also fails unless every difficulty has at least N valid levels.
## Exits with code 0 only when everything is valid.

const LEVELS_DIR: String = "res://data/levels"
## Offline checks can afford a far larger search than in-game hints.
const SOLVER_MAX_STATES: int = 5000000
## A covered peg must be used within this many moves of the stored solution.
const COVERED_REVEAL_WITHIN: int = 3


func _initialize() -> void:
	quit(0 if _run() else 1)


func _run() -> bool:
	var levels_dir: String = LEVELS_DIR
	var required: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--dir="):
			levels_dir = arg.trim_prefix("--dir=")
		elif arg.begins_with("--require="):
			required = arg.trim_prefix("--require=").to_int()
	var started_ms: int = Time.get_ticks_msec()
	var report: Dictionary = validate_directory(levels_dir)
	var failures: Dictionary = report["failures"]
	for path: String in failures:
		print("FAIL %s" % path)
		for error: String in failures[path]:
			print("     - %s" % error)
	var ok: bool = failures.is_empty() and report["files"] > 0
	var counts: Dictionary = report["valid_counts"]
	if counts.has(Difficulty.BONUS):
		print("%-7s %4d valid levels" % [Difficulty.BONUS, counts[Difficulty.BONUS]])
	for tier: String in Difficulty.ORDER:
		var count: int = counts.get(tier, 0)
		var status: String = ""
		if count < required:
			status = "  <-- fewer than %d" % required
			ok = false
		print("%-7s %4d valid levels%s" % [tier, count, status])
	print("%d files checked, %d invalid (%d ms)" % [report["files"], failures.size(), Time.get_ticks_msec() - started_ms])
	if report["files"] == 0:
		print("No level files found in %s" % levels_dir)
	return ok


## Validates every <tier>/*.json under `levels_dir`, including checks across
## files (unique ids, unique start/goal pairs). Returns
## { files: int, failures: { path: Array[String] }, valid_counts: { tier: int } }.
static func validate_directory(levels_dir: String) -> Dictionary:
	var failures: Dictionary = {}
	var valid_counts: Dictionary = {}
	var files: int = 0
	var id_owner: Dictionary = {}
	var pair_owner: Dictionary = {}
	for tier: String in DirAccess.get_directories_at(levels_dir):
		var file_names: Array = Array(DirAccess.get_files_at("%s/%s" % [levels_dir, tier]))
		file_names.sort()
		for file_name: String in file_names:
			if not file_name.ends_with(".json") or file_name == LevelCatalog.BONUS_INDEX_FILE:
				continue
			files += 1
			var path: String = "%s/%s/%s" % [levels_dir, tier, file_name]
			var errors: Array[String] = []
			var level: Level = load_and_validate(path, errors)
			if level != null:
				if id_owner.has(level.id):
					errors.append("duplicate id %d (also in %s)" % [level.id, id_owner[level.id]])
				else:
					id_owner[level.id] = path
				var pair: String = pair_key(level.start, level.goal)
				if pair_owner.has(pair):
					errors.append("same start and goal as %s" % pair_owner[pair])
				else:
					pair_owner[pair] = path
			if errors.is_empty():
				valid_counts[tier] = valid_counts.get(tier, 0) + 1
			else:
				failures[path] = errors
	if DirAccess.dir_exists_absolute("%s/%s" % [levels_dir, Difficulty.BONUS]):
		var index_errors: Array[String] = validate_bonus_index(levels_dir)
		if not index_errors.is_empty():
			failures["%s/%s/%s" % [levels_dir, Difficulty.BONUS, LevelCatalog.BONUS_INDEX_FILE]] = index_errors
	return {"files": files, "failures": failures, "valid_counts": valid_counts}


## The bonus index must list every bonus level file exactly once, with the
## level's own id and a tier tab, at most BONUS_PER_TAB per tab.
static func validate_bonus_index(levels_dir: String) -> Array[String]:
	var errors: Array[String] = []
	var bonus_dir: String = "%s/%s" % [levels_dir, Difficulty.BONUS]
	var entries: Array[Dictionary] = LevelCatalog.read_bonus_index("%s/%s" % [bonus_dir, LevelCatalog.BONUS_INDEX_FILE], errors)
	var listed: Array[String] = []
	var per_tab: Dictionary = {}
	for entry: Dictionary in entries:
		var file_name: String = entry["file"]
		if listed.has(file_name):
			errors.append("%s is listed twice" % file_name)
		listed.append(file_name)
		per_tab[entry["tab"]] = per_tab.get(entry["tab"], 0) + 1
		var level_errors: Array[String] = []
		var level: Level = Level.load_file("%s/%s" % [bonus_dir, file_name], level_errors)
		if level == null:
			errors.append("%s cannot be read" % file_name)
		elif level.id != entry["id"]:
			errors.append("%s has id %d, the index says %d" % [file_name, level.id, entry["id"]])
	for tab: String in per_tab:
		if per_tab[tab] > LevelCatalog.BONUS_PER_TAB:
			errors.append("%d bonus levels in the %s tab (at most %d)" % [per_tab[tab], tab, LevelCatalog.BONUS_PER_TAB])
	for file_name: String in DirAccess.get_files_at(bonus_dir):
		if file_name.ends_with(".json") and file_name != LevelCatalog.BONUS_INDEX_FILE and not listed.has(file_name):
			errors.append("%s is not in the index" % file_name)
	return errors


## Design rules of the bonus mechanics, on top of the normal checks. A frozen
## disk must sit on another disk (a frozen bottom disk would just be a peg
## base) and the freeze must make the level longer than plain Hanoi.
static func validate_bonus_design(level: Level, errors: Array[String]) -> void:
	var rules: RuleSet = level.get_rule_set()
	if rules == null:
		return
	var pinned: Array[int] = []
	for disk: int in range(1, level.get_disk_count() + 1):
		if not rules.is_disk_movable(disk):
			pinned.append(disk)
	for disk: int in pinned:
		for peg: Array in level.start.pegs:
			if not peg.is_empty() and peg[0] == disk:
				errors.append("frozen disk %d is the bottom disk of its peg" % disk)
	if not pinned.is_empty():
		var plain: int = Solver.solve(level.start, level.goal, RuleSet.classic(), SOLVER_MAX_STATES)["min_moves"]
		if plain >= level.min_moves:
			errors.append("the frozen disk changes nothing (%d moves without it)" % plain)
	# A covered peg must hide something and be opened early by the stored
	# optimal solution, so three stars never depend on luck (user decision
	# 2026-10-09: within the first COVERED_REVEAL_WITHIN moves).
	for peg_index: int in level.covered_pegs:
		if peg_index < 0 or peg_index >= level.get_peg_count():
			continue  # reported by Level.check()
		if level.start.pegs[peg_index].size() < 2:
			errors.append("covered peg %d hides nothing (fewer than 2 disks)" % peg_index)
		var used: bool = false
		for i: int in mini(COVERED_REVEAL_WITHIN, level.solution_path.size()):
			var move: Move = level.solution_path[i]
			used = used or move.from_peg == peg_index or move.to_peg == peg_index
		if not used:
			errors.append("covered peg %d is not used in the first %d moves of the solution" % [peg_index, COVERED_REVEAL_WITHIN])


## Loads one level file and checks it on its own (folder must match the
## difficulty). Problems go to `errors`; returns the level if it could be parsed.
static func load_and_validate(path: String, errors: Array[String]) -> Level:
	var level: Level = Level.load_file(path, errors)
	if level == null:
		return null
	var folder: String = path.get_base_dir().get_file()
	if folder != level.difficulty:
		errors.append("difficulty \"%s\" is stored in the \"%s\" folder" % [level.difficulty, folder])
	elif level.is_bonus():
		validate_bonus_design(level, errors)
	elif Difficulty.accepts_id(level.difficulty, level.id):
		# The game finds a level by id, so the file number must match it.
		var expected_name: String = Difficulty.level_file_name(level.difficulty, Difficulty.index_of_id(level.id))
		if path.get_file() != expected_name:
			errors.append("id %d belongs in %s, not %s" % [level.id, expected_name, path.get_file()])
	validate_level(level, errors)
	return level


## Level.check() plus a fresh Solver run proving min_moves is the minimum.
## Shipped levels must not use time_limit_seconds: v1 has no timed levels
## (decision 2026-10-09, spec section 8; timers are kept for a later separate
## "against the clock" mode). The field itself stays in the level format.
static func validate_level(level: Level, errors: Array[String]) -> void:
	var error_count: int = errors.size()
	if level.time_limit_seconds != null:
		errors.append("time_limit_seconds must be null: v1 has no timed levels")
	level.check(errors)
	if errors.size() > error_count:
		return
	var result: Dictionary = Solver.solve(level.start, level.goal, level.get_rule_set(), SOLVER_MAX_STATES)
	if not result["solvable"]:
		errors.append("the solver found no solution (limit reached: %s)" % str(result["limit_reached"]))
	elif result["min_moves"] != level.min_moves:
		errors.append("min_moves is %d but the shortest solution has %d moves" % [level.min_moves, result["min_moves"]])


## Identity of a puzzle for duplicate detection (spec 4.4 step 6).
static func pair_key(start: PuzzleState, goal: PuzzleState) -> String:
	return "%s => %s" % [start.hash_key(), goal.hash_key()]
