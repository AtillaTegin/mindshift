class_name LevelValidator
extends SceneTree
## Re-checks level JSON files, including that min_moves is really the minimum
## (the Solver is run again for every level).
##   godot --headless --path . --script res://tools/level_validator.gd
##   godot --headless --path . --script res://tools/level_validator.gd -- --require=50
##   godot --headless --path . --script res://tools/level_validator.gd -- --dir=res://data/levels
## --require=N also fails unless every difficulty has at least N valid classic levels.
## The level path (data/levels/path.json) is checked too: every level on it
## exactly once, the tutorial first, each level in a chapter that may hold it,
## expert levels only on the islands (validate_path()).
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
		print("FAIL %s/%s is missing (run tools/road_builder.gd)" % [levels_dir, LevelCatalog.PATH_FILE])
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
## the file's own id. The two tutorial levels open it; every main level fits
## its chapter (ChapterPlan: classic, the chapter's mode, an earlier mode as a
## repeat, a combination chapter's combinations and single modes), every
## combination is on the plan's whitelist and obeys its rules (section 4);
## expert levels only appear on the islands; each island opens after a main
## level that exists and holds levels of its own mode.
static func validate_path(levels_dir: String) -> Array[String]:
	var errors: Array[String] = []
	var path: Dictionary = LevelCatalog.read_path("%s/%s" % [levels_dir, LevelCatalog.PATH_FILE], errors)
	var listed: Dictionary = {}
	var main: Array = path[LevelCatalog.MAIN]
	var tracks: Array[Dictionary] = [{"name": LevelCatalog.MAIN, "entries": main, "mode": ""}]
	var after: int = 0
	for island: Dictionary in path["islands"]:
		tracks.append({"name": "island after main %d" % island["after"], "entries": island["levels"], "mode": island["mode"]})
		if island["after"] <= after or island["after"] > main.size():
			errors.append("an island after main %d is out of order or off the road" % island["after"])
		after = island["after"]
	var whitelist: Array[String] = ChapterPlan.whitelist()
	for track: Dictionary in tracks:
		var entries: Array = track["entries"]
		var on_main: bool = track["name"] == LevelCatalog.MAIN
		for i: int in entries.size():
			var file: String = entries[i]["file"]
			if listed.has(file):
				errors.append("%s is on the path twice" % file)
			listed[file] = true
			var level_errors: Array[String] = []
			var level: Level = Level.load_file("%s/%s" % [levels_dir, file], level_errors)
			if level == null:
				errors.append("%s %d: %s cannot be read" % [track["name"], i + 1, file])
				continue
			if level.id != entries[i]["id"]:
				errors.append("%s has id %d, the path says %d" % [file, level.id, entries[i]["id"]])
			var modes: Array[String] = level.modes()
			if modes.size() > 1 and (not ChapterPlan.is_combo_allowed(modes) or (modes.size() == 2 \
					and not whitelist.has(ChapterPlan.combo_key(modes)))):
				errors.append("%s: the combination %s is not on the plan's whitelist" % [file, ChapterPlan.combo_key(modes)])
			if on_main:
				if level.difficulty == "expert":
					errors.append("main %d: expert level %s belongs on an island" % [i + 1, file])
				var fit: String = fits_chapter(modes, i + 1)
				if not fit.is_empty():
					errors.append("main %d: %s %s" % [i + 1, file, fit])
			elif track["mode"] == Level.CLASSIC and not modes.is_empty():
				errors.append("%s: the classic island holds classic levels only" % file)
			elif track["mode"] != Level.CLASSIC and (modes.size() != 1 or modes[0] != track["mode"] \
					or level.difficulty != "expert"):
				errors.append("%s: the %s island holds expert %s levels only" % [file, track["mode"], track["mode"]])
	for i: int in TUTORIAL_LEVEL_IDS.size():
		if main.size() <= i or main[i]["id"] != TUTORIAL_LEVEL_IDS[i]:
			errors.append("main %d must be tutorial level %d" % [i + 1, TUTORIAL_LEVEL_IDS[i]])
	for folder: String in DirAccess.get_directories_at(levels_dir):
		for file_name: String in DirAccess.get_files_at("%s/%s" % [levels_dir, folder]):
			if file_name.ends_with(".json") and not listed.has("%s/%s" % [folder, file_name]):
				errors.append("%s/%s is not on the path" % [folder, file_name])
	return errors


## "" if a main road level with `modes` fits the chapter at `position`, else
## why not: a classic chapter holds classic levels; a mode chapter its mode,
## classic levels and earlier chapters' modes; a combination chapter its
## combinations, its single modes and classic levels.
static func fits_chapter(modes: Array[String], position: int) -> String:
	var chapter: Dictionary = ChapterPlan.chapter_at(position)
	if chapter.is_empty():
		return "lies past the chapter plan"
	if modes.is_empty():
		return ""
	match chapter["kind"]:
		ChapterPlan.MODE_CHAPTER:
			if modes.size() == 1 and (modes[0] == chapter["mode"] or ChapterPlan.modes_before(position).has(modes[0])):
				return ""
		ChapterPlan.COMBO_CHAPTER:
			if modes.size() == 1 and (chapter["singles"] as Array).has(modes[0]):
				return ""
			if modes.size() == 2 and (chapter.get("with_earlier_combos", false) \
					or (chapter["combos"] as Array).any(func(combo: Array) -> bool:
						return ChapterPlan.combo_key(combo) == ChapterPlan.combo_key(modes))):
				return ""
	return "does not belong in the chapter at main %d-%d (%s)" % [chapter["first"], chapter["last"], ChapterPlan.combo_key(modes)]


## Design rules of the mechanic levels, on top of the normal checks. Each rule
## beyond classic Hanoi must make the level longer: without any one of them
## the same start and goal take fewer moves (a combination is longer than
## either of its modes alone); a great exchange must have its board shape.
static func validate_mechanic_design(level: Level, errors: Array[String]) -> void:
	var rules: RuleSet = level.get_rule_set()
	if rules == null:
		return
	if level.rule_ids.size() > 1 \
			and not LevelForge.matters(level.start, level.goal, level.rule_ids, level.rule_params, level.min_moves):
		errors.append("a rule of %s changes nothing (as short without it)" % ChapterPlan.combo_key(level.modes()))
	if level.mechanic() == Difficulty.COLOR_SWAP:
		validate_color_swap_shape(level, errors)
	# Every lock and seal must be closed at the start, and a chain must move.
	if (level.rule_ids.has(FoundationRule.ID) or level.rule_ids.has(SealedBoxRule.ID)) and rules.memory_of(level.start) != 0:
		errors.append("a lock or seal is open at the start")
	if level.mechanic() == ChainRule.ID and not level.solution_path.any(func(move: Move) -> bool: return move.is_compound()):
		errors.append("the chained disks never move in the solution")
	# A covered peg must hide something and be opened early by the stored
	# optimal solution, so three stars never depend on luck (user decision
	# 2026-10-09: within the first COVERED_REVEAL_WITHIN moves). User decision
	# 2026-10-16: a count board (each box shows its count) and an empty box
	# show enough, so they are exempt; a sealed box only from the early use (a
	# tap never opens it, the smallest disk does).
	var sealed: Array = level.rule_params.get(SealedBoxRule.ID, {}).get("pegs", [])
	for peg_index: int in level.covered_pegs:
		if peg_index < 0 or peg_index >= level.get_peg_count() or level.variants.has("count_board"):
			continue  # bad indices are reported by Level.check()
		if level.variants.has("empty_box") and level.start.pegs[peg_index].is_empty():
			continue
		if level.start.pegs[peg_index].size() < 2:
			errors.append("covered peg %d hides nothing (fewer than 2 disks)" % peg_index)
		var used: bool = sealed.has(peg_index)
		for i: int in mini(COVERED_REVEAL_WITHIN, level.solution_path.size()):
			var move: Move = level.solution_path[i]
			used = used or move.from_peg == peg_index or move.to_peg == peg_index
		if not used:
			errors.append("covered peg %d is not used in the first %d moves of the solution" % [peg_index, COVERED_REVEAL_WITHIN])
	for peg_index: int in sealed:
		if not level.covered_pegs.has(peg_index):
			errors.append("sealed peg %d is no karakuri box" % peg_index)
	for disk: int in level.glass_disks:
		if not level.covered_pegs.any(func(peg: int) -> bool: return peg < level.get_peg_count() and level.start.pegs[peg].has(disk)):
			errors.append("glass disk %d is not inside a box" % disk)
	validate_variants(level, errors)


## Chapter waves v1: every sub-element the level names is really there, every
## rule-changing one makes it longer on its own, and nothing is there that it
## does not name (the guides and the rule panel go by the names).
static func validate_variants(level: Level, errors: Array[String]) -> void:
	var rules: RuleSet = level.get_rule_set()
	var capacity: PegCapacityRule = null
	var lock: FoundationRule = null
	for rule: RuleBase in rules.active_rules:
		if rule is PegCapacityRule:
			capacity = rule
		elif rule is FoundationRule:
			lock = rule
	var found: Array[String] = []
	if capacity != null:
		if capacity.capacities.has(1):
			found.append("narrow")
		if capacity.arches.any(func(n: int) -> bool: return n > 0):
			found.append("arch")
		if capacity.holes.any(func(n: int) -> bool: return n > 0):
			found.append("holed")
	if lock != null and lock.stages.size() > 1:
		found.append("chain_lock")
	if level.rule_ids.has(SealedBoxRule.ID):
		found.append("sealed")
	if not level.glass_disks.is_empty():
		found.append("glass")
	for variant: String in found:
		if not level.variants.has(variant):
			errors.append("the level has a %s but does not name it" % variant)
	for variant: String in level.variants:
		var missing: bool = false
		match variant:
			"narrow", "arch", "holed", "chain_lock", "sealed", "glass":
				missing = not found.has(variant)
			"count_board":
				missing = level.covered_pegs.size() != level.get_peg_count()
			"empty_box":
				missing = not level.covered_pegs.any(func(peg: int) -> bool:
					return peg < level.get_peg_count() and level.start.pegs[peg].is_empty())
			"reclosing":
				missing = level.covered_pegs.is_empty()
			"key_disk":
				missing = lock == null or lock.keys.size() != 1
			"middle_lock":
				missing = lock == null or not lock.locked.any(func(disk: int) -> bool:
					for stack: Array in level.start.pegs:
						var at: int = stack.find(disk)
						if at > 0 and at < stack.size() - 1:
							return true
					return false)
		if missing:
			errors.append("the level names %s but has none" % variant)
	if not LevelForge.variants_matter(level.start, level.goal, level.rule_ids, level.rule_params, level.variants,
			level.min_moves):
		errors.append("a sub-element of %s changes nothing" % str(level.variants))


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
	var result: Dictionary = Solver.solve(level.start, level.goal, level.get_rule_set(), SOLVER_MAX_STATES)
	if not result["solvable"]:
		errors.append("the solver found no solution (limit reached: %s)" % str(result["limit_reached"]))
	elif result["min_moves"] != level.min_moves:
		errors.append("min_moves is %d but the shortest solution has %d moves" % [level.min_moves, result["min_moves"]])


## Identity of a puzzle for duplicate detection (spec 4.4 step 6).
static func pair_key(start: PuzzleState, goal: PuzzleState) -> String:
	return "%s => %s" % [start.hash_key(), goal.hash_key()]


## pair_key() plus, for a level with rules beyond classic Hanoi, its rules and
## their settings: the same start and goal under another rule (a narrower
## balance, a different capacity) is another puzzle. Karakuri boxes do not
## count (LevelForge.puzzle_key()).
static func puzzle_key(level: Level) -> String:
	return LevelForge.puzzle_key(level.start, level.goal, level.rule_ids, level.rule_params)
