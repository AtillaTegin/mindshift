class_name LevelValidator
extends SceneTree
## Re-checks level JSON files, including that min_moves is really the minimum
## (the Solver is run again for every level).
##   godot --headless --path . --script res://tools/level_validator.gd
##   godot --headless --path . --script res://tools/level_validator.gd -- --require=50
##   godot --headless --path . --script res://tools/level_validator.gd -- --dir=res://data/levels
## --require=N also fails unless every difficulty has at least N valid classic levels.
## The level path (data/levels/path.json) is checked too: every level on it
## exactly once, the tutorial first, expert levels only on the branch.
## Exits with code 0 only when everything is valid.

const LEVELS_DIR: String = "res://data/levels"
## Offline checks can afford a far larger search than in-game hints.
const SOLVER_MAX_STATES: int = 5000000
## A covered peg must be used within this many moves of the stored solution.
const COVERED_REVEAL_WITHIN: int = 3
## The tutorial levels that must open the path: TutorialDirector.GUIDED_LEVEL_ID
## and FREE_LEVEL_ID (not referenced: TutorialDirector pulls in UI scripts that
## need the autoloads, which --script tools do not have). A test keeps them equal.
const TUTORIAL_LEVEL_IDS: Array[int] = [1001, 1002]


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
	if not FileAccess.file_exists("%s/%s" % [levels_dir, LevelCatalog.PATH_FILE]):
		print("FAIL %s/%s is missing (run tools/path_builder.gd)" % [levels_dir, LevelCatalog.PATH_FILE])
		ok = false
	var counts: Dictionary = report["valid_counts"]
	if counts.has(Difficulty.MECHANICS):
		print("%-9s %4d valid levels" % [Difficulty.MECHANICS, counts[Difficulty.MECHANICS]])
	for tier: String in Difficulty.ORDER:
		var count: int = counts.get(tier, 0)
		var status: String = ""
		if count < required:
			status = "  <-- fewer than %d" % required
			ok = false
		print("%-9s %4d valid levels%s" % [tier, count, status])
	print("%d files checked, %d invalid (%d ms)" % [report["files"], failures.size(), Time.get_ticks_msec() - started_ms])
	if report["files"] == 0:
		print("No level files found in %s" % levels_dir)
	return ok


## Validates every <tier>/*.json and mechanics/*.json under `levels_dir`,
## including checks across files (unique ids, unique start/goal pairs) and,
## when `levels_dir` has one, the level path. Returns
## { files: int, failures: { path: Array[String] }, valid_counts: { folder: int } }.
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
			if not file_name.ends_with(".json"):
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
				var pair: String = puzzle_key(level)
				if pair_owner.has(pair):
					errors.append("same start and goal as %s" % pair_owner[pair])
				else:
					pair_owner[pair] = path
			if errors.is_empty():
				valid_counts[tier] = valid_counts.get(tier, 0) + 1
			else:
				failures[path] = errors
	if FileAccess.file_exists("%s/%s" % [levels_dir, LevelCatalog.PATH_FILE]):
		var path_errors: Array[String] = validate_path(levels_dir)
		if not path_errors.is_empty():
			failures["%s/%s" % [levels_dir, LevelCatalog.PATH_FILE]] = path_errors
	return {"files": files, "failures": failures, "valid_counts": valid_counts}


## The level path lists every level file under `levels_dir` exactly once, with
## the file's own id. The two tutorial levels open it, then classic easy levels
## up to PathBuilder.FIRST_EASY (the only small easy ones); no easy level after
## PathBuilder.EASY_UNTIL; expert levels only appear on the branch, and the
## branch opens after a level that exists.
static func validate_path(levels_dir: String) -> Array[String]:
	var errors: Array[String] = []
	var path: Dictionary = LevelCatalog.read_path("%s/%s" % [levels_dir, LevelCatalog.PATH_FILE], errors)
	var listed: Dictionary = {}
	for track: String in LevelCatalog.TRACKS:
		var entries: Array = path[track]
		for i: int in entries.size():
			var file: String = entries[i]["file"]
			if listed.has(file):
				errors.append("%s is on the path twice" % file)
			listed[file] = true
			var level_errors: Array[String] = []
			var level: Level = Level.load_file("%s/%s" % [levels_dir, file], level_errors)
			if level == null:
				errors.append("%s %d: %s cannot be read" % [track, i + 1, file])
				continue
			if level.id != entries[i]["id"]:
				errors.append("%s has id %d, the path says %d" % [file, level.id, entries[i]["id"]])
			if track == LevelCatalog.MAIN and level.difficulty == "expert":
				errors.append("main %d: expert level %s belongs on the branch" % [i + 1, file])
			if track == LevelCatalog.MAIN and i < PathBuilder.FIRST_EASY \
					and (level.difficulty != "easy" or level.mechanic() != Level.CLASSIC):
				errors.append("main %d: %s is not a classic easy level" % [i + 1, file])
			if track == LevelCatalog.MAIN and level.color_goal != null:
				errors.append_array(combination_stage_errors(level, i + 1))
			# Level structure v4, section 1: easy levels are for learning only.
			if track == LevelCatalog.MAIN and i >= PathBuilder.EASY_UNTIL and level.difficulty == "easy":
				errors.append("main %d: easy level %s after main %d" % [i + 1, file, PathBuilder.EASY_UNTIL])
			if i >= PathBuilder.FIRST_EASY and level.mechanic() == Level.CLASSIC and level.difficulty == "easy" \
					and level.get_disk_count() == Difficulty.get_tier("easy").get("small_disks", 0):
				errors.append("%s %d: a %d-disk easy level only opens the road" % [track, i + 1, level.get_disk_count()])
	var main: Array = path[LevelCatalog.MAIN]
	for i: int in TUTORIAL_LEVEL_IDS.size():
		if main.size() <= i or main[i]["id"] != TUTORIAL_LEVEL_IDS[i]:
			errors.append("main %d must be tutorial level %d" % [i + 1, TUTORIAL_LEVEL_IDS[i]])
	if path["branch_after"] < 1 or path["branch_after"] > main.size():
		errors.append("branch_after %d is not a main path position" % path["branch_after"])
	for folder: String in DirAccess.get_directories_at(levels_dir):
		for file_name: String in DirAccess.get_files_at("%s/%s" % [levels_dir, folder]):
			if file_name.ends_with(".json") and not listed.has("%s/%s" % [folder, file_name]):
				errors.append("%s/%s is not on the path" % [folder, file_name])
	return errors

## Design rules of the mechanic levels, on top of the normal checks. A rule
## beyond classic Hanoi (Nine Rings alternation, caravan road) must make the
## level longer than plain Hanoi, or it changes nothing; a great exchange must
## have its board shape.
static func validate_mechanic_design(level: Level, errors: Array[String]) -> void:
	var rules: RuleSet = level.get_rule_set()
	if rules == null:
		return
	if level.rule_ids.size() > 1:
		var plain: int = Solver.solve(level.start, level.goal, RuleSet.classic(), SOLVER_MAX_STATES)["min_moves"]
		if plain >= level.min_moves:
			errors.append("the %s rule changes nothing (%d moves without it)" % [level.mechanic(), plain])
	if level.color_goal != null:
		validate_combination_shape(level, errors)
	if level.mechanic() == Difficulty.COLOR_SWAP:
		validate_color_swap_shape(level, errors)
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


## "Böyük Mübadilə" v2 (ColorSwapRule alone, at least two empty pegs between
## the ends): each end peg starts with one disk of every size k..1, the two
## disks of a size on opposite ends, the pegs between empty; the goal is every
## black disk on the left end and every white one on the right. The pure kind
## (no colour rule) starts all white on the left: the stacks swap. The mixed
## kind starts with both ends mixed and the largest pair on the wrong ends.
static func validate_color_swap_shape(level: Level, errors: Array[String]) -> void:
	var rules: RuleSet = level.get_rule_set()
	if level.rule_ids.size() != 1 or level.get_disk_count() % 2 != 0 or level.get_peg_count() < 4:
		errors.append("a great exchange has the %s rule alone, k disks of each colour and at least 2 empty pegs between the ends" % ColorSwapRule.ID)
		return
	var colour_bound: bool = (rules.active_rules[0] as ColorSwapRule).colour_bound
	var k: int = level.get_disk_count() / 2
	var last: int = level.get_peg_count() - 1
	var black: Array = []
	var white: Array = []
	for size: int in range(k, 0, -1):
		black.append(ColorSwapRule.disk_of(size, false))
		white.append(ColorSwapRule.disk_of(size, true))
	for peg_index: int in range(1, last):
		if not level.start.pegs[peg_index].is_empty() or not level.goal.pegs[peg_index].is_empty():
			errors.append("the pegs between the two ends start and end empty")
			return
	if level.goal.pegs[0] != black or level.goal.pegs[last] != white:
		errors.append("the goal is every black disk on the left end and every white one on the right")
	var left: Array = level.start.pegs[0]
	var right: Array = level.start.pegs[last]
	var paired: bool = left.size() == k and right.size() == k
	for i: int in mini(left.size(), right.size()):
		paired = paired and ColorSwapRule.size_of(left[i]) == k - i and ColorSwapRule.size_of(right[i]) == k - i \
				and ColorSwapRule.is_white(left[i]) != ColorSwapRule.is_white(right[i])
	if not paired:
		errors.append("each end starts with one disk of every size, the two of a size on opposite ends")
		return
	if not colour_bound and left != white:
		errors.append("the pure kind starts with every white disk on the left")
	if colour_bound and (left == white or left[0] != white[0]):
		errors.append("the mixed kind starts with both ends mixed and the largest white disk on the left")


## Loads one level file and checks it on its own: a tier folder holds classic
## levels of that difficulty, data/levels/mechanics/ the levels with a special
## mechanic. Problems go to `errors`; returns the level if it could be parsed.
static func load_and_validate(path: String, errors: Array[String]) -> Level:
	var level: Level = Level.load_file(path, errors)
	if level == null:
		return null
	var folder: String = path.get_base_dir().get_file()
	if folder == Difficulty.MECHANICS:
		if level.mechanic() == Level.CLASSIC:
			errors.append("a level in the mechanics folder needs a special rule or covered pegs")
		validate_mechanic_design(level, errors)
	elif folder != level.difficulty:
		errors.append("difficulty \"%s\" is stored in the \"%s\" folder" % [level.difficulty, folder])
	elif level.mechanic() != Level.CLASSIC:
		errors.append("a %s level belongs in the mechanics folder" % level.mechanic())
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
	if level.color_goal != null:
		_validate_combination_solution(level, errors)
		return
	var result: Dictionary = Solver.solve(level.start, level.goal, level.get_rule_set(), SOLVER_MAX_STATES)
	if not result["solvable"]:
		errors.append("the solver found no solution (limit reached: %s)" % str(result["limit_reached"]))
	elif result["min_moves"] != level.min_moves:
		errors.append("min_moves is %d but the shortest solution has %d moves" % [level.min_moves, result["min_moves"]])


## A combination level's stored solution is its proof: Level.check() already
## replayed it to a position that meets the colour goal. Its min_moves is that
## solution's length (an example, user decision 2026-10-13); while the board is
## small enough for a full search (at most CombinationSolver.EXACT_DISKS disks)
## it must also be the shortest.
static func _validate_combination_solution(level: Level, errors: Array[String]) -> void:
	if level.get_disk_count() > CombinationSolver.EXACT_DISKS:
		return
	var result: Dictionary = CombinationSolver.search(ColorGoal.letters_of(level.start, level.disk_colors),
			CombinationSolver.capacity_of(level), level.color_goal, SOLVER_MAX_STATES)
	if not result["solvable"]:
		errors.append("the combination solver found no solution")
	elif result["min_moves"] != level.min_moves:
		errors.append("min_moves is %d but the shortest solution has %d moves" % [level.min_moves, result["min_moves"]])


## Correction v2, error 2: Water Sort's shape. Every colour has exactly as many
## disks as a peg holds (N), and the start has C full pegs and E empty ones.
static func validate_combination_shape(level: Level, errors: Array[String]) -> void:
	var capacity: int = CombinationSolver.capacity_of(level)
	var colours: Array[String] = level.color_goal.goal_colours(level.disk_colors)
	for color_name: String in colours:
		if level.disk_colors.count(color_name) != capacity:
			errors.append("%d %s disks, a peg holds %d (every colour fills a peg)" % [level.disk_colors.count(color_name), color_name, capacity])
			return
	for peg: Array in level.start.pegs:
		if not peg.is_empty() and peg.size() != capacity:
			errors.append("the start has a peg that is neither full nor empty")
			return
	if level.get_peg_count() - colours.size() < 1:
		errors.append("a combination level needs at least one empty peg")


## Corrections v2 and v3: a combination level at main path `position` has the
## capacity and colours of its stage (Difficulty.COMBINATION_STAGES, capacity
## never above Difficulty.COMBINATION_MAX_CAPACITY), the measured E_min empty
## pegs and the stage's tier.
static func combination_stage_errors(level: Level, position: int) -> Array[String]:
	var errors: Array[String] = []
	var stage: Dictionary = Difficulty.combination_stage(position)
	var capacity: int = CombinationSolver.capacity_of(level)
	var colours: int = level.color_goal.goal_colours(level.disk_colors).size()
	var empty: int = level.get_peg_count() - colours
	var checks: Dictionary = {"capacity": capacity, "colours": colours}
	for key: String in checks:
		if checks[key] < stage[key][0] or checks[key] > stage[key][1]:
			errors.append("main %d (%s): %s %d is outside %s" % [position, stage["name"], key, checks[key], str(stage[key])])
	if capacity > Difficulty.COMBINATION_MAX_CAPACITY:
		errors.append("main %d: capacity %d is above %d" % [position, capacity, Difficulty.COMBINATION_MAX_CAPACITY])
	if empty != Difficulty.combination_empty(colours, capacity):
		errors.append("main %d: %d empty pegs, E_min of %dx%d is %d" % [position, empty, colours, capacity,
				Difficulty.combination_empty(colours, capacity)])
	if level.difficulty != stage["tier"]:
		errors.append("main %d (%s): difficulty %s, the stage is %s" % [position, stage["name"], level.difficulty, stage["tier"]])
	return errors


## Identity of a puzzle for duplicate detection (spec 4.4 step 6).
static func pair_key(start: PuzzleState, goal: PuzzleState) -> String:
	return "%s => %s" % [start.hash_key(), goal.hash_key()]


## pair_key(), except that a combination level is told by its colours, up to
## their names (ColorGoal.shape_key): its disk ids mean nothing, and the same
## puzzle in other colours is still the same puzzle.
static func puzzle_key(level: Level) -> String:
	if level.color_goal == null:
		return pair_key(level.start, level.goal)
	return level.color_goal.shape_key(ColorGoal.letters_of(level.start, level.disk_colors))
