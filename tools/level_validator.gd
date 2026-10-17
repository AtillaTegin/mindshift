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
					errors.append("the same puzzle as %s (pegs reordered or mirrored, or colours swapped)" % pair_owner[pair])
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
## expert levels only appear on the islands and as a chapter's Böyük Sınaq
## (34-65 moves, v1.2 3.2a); each island opens after a main level that exists
## and holds levels of its own mode. No level takes fewer moves than its
## world's floor (ChapterPlan.world_floor) but the guided intros: the tutorial
## levels and the first main level of each lesson and of each sub-element.
static func validate_path(levels_dir: String) -> Array[String]:
	var errors: Array[String] = []
	var path: Dictionary = LevelCatalog.read_path("%s/%s" % [levels_dir, LevelCatalog.PATH_FILE], errors)
	var listed: Dictionary = {}
	var main: Array = path[LevelCatalog.MAIN]
	var tracks: Array[Dictionary] = [{"name": LevelCatalog.MAIN, "entries": main, "mode": "", "after": 0}]
	var after: int = 0
	for island: Dictionary in path["islands"]:
		tracks.append({"name": "island after main %d" % island["after"], "entries": island["levels"], "mode": island["mode"],
				"after": island["after"]})
		if island["after"] <= after or island["after"] > main.size():
			errors.append("an island after main %d is out of order or off the road" % island["after"])
		after = island["after"]
	var whitelist: Array[String] = ChapterPlan.whitelist()
	# Lessons and lesson/sub-element pairs met on the main road so far.
	var taught: Dictionary = {}
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
			# The world's floor; the first level of a lesson or sub-element is its intro.
			var intro: bool = on_main and (i < TUTORIAL_LEVEL_IDS.size() or not taught.has(level.lesson()))
			if on_main:
				taught[level.lesson()] = true
				for variant: String in level.variants:
					intro = intro or not taught.has(level.lesson() + "/" + variant)
					taught[level.lesson() + "/" + variant] = true
			var least: int = ChapterPlan.world_floor(ChapterPlan.world_at(i + 1 if on_main else track["after"]))
			# A goal variant's level is a short breather (ICRA section 4).
			var breath: bool = level.variants.any(func(variant: String) -> bool: return ChapterPlan.GOAL_RULES.has(variant))
			if not intro and not breath and level.min_moves < least:
				errors.append("%s %d: %s takes %d moves, below the world's floor of %d" % [track["name"], i + 1, file,
						level.min_moves, least])
			if modes.size() > 1 and (not ChapterPlan.is_combo_allowed(modes) or (modes.size() == 2 \
					and not whitelist.has(ChapterPlan.combo_key(modes)))):
				errors.append("%s: the combination %s is not on the plan's whitelist" % [file, ChapterPlan.combo_key(modes)])
			if on_main:
				# Fəsil Sistemi v1.2, 3.2a: up to 33 moves, but a chapter's Böyük Sınaq 34-65.
				var big_test: bool = ChapterPlan.is_big_test(i + 1)
				if level.difficulty == "expert" and not big_test:
					errors.append("main %d: expert level %s belongs on an island" % [i + 1, file])
				if big_test and (level.min_moves < ChapterPlan.BIG_TEST[0] or level.min_moves > ChapterPlan.BIG_TEST[1]):
					errors.append("main %d: the Böyük Sınaq %s takes %d moves, not %d-%d" % [i + 1, file, level.min_moves,
							ChapterPlan.BIG_TEST[0], ChapterPlan.BIG_TEST[1]])
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
	if level.rule_ids.has(ColorSwapRule.ID):
		validate_color_swap_shape(level, errors)
	# Every lock and seal must be closed at the start, and a chain must move.
	if (level.rule_ids.has(FoundationRule.ID) or level.rule_ids.has(SealedBoxRule.ID)) and rules.memory_of(level.start) != 0:
		errors.append("a lock or seal is open at the start")
	if level.mechanic() == ChainRule.ID and not level.solution_path.any(func(move: Move) -> bool: return move.is_compound()):
		errors.append("the chained disks never move in the solution")
	# A covered peg must hide something and be opened early by the stored
	# optimal solution, so three stars never depend on luck (user decision
	# 2026-10-09: within the first COVERED_REVEAL_WITHIN moves). Current
	# decisions 2026-10-16 (B.2, B.5): in a fully hidden level and an empty-box
	# level a box needs one disk and no early use, and only an empty-box level
	# has an empty box, one at most; a sealed box is exempt from the early use
	# only (a tap never opens it, the smallest disk does).
	var sealed: Array = level.rule_params.get(SealedBoxRule.ID, {}).get("pegs", [])
	var relaxed: bool = level.variants.has("full_hidden") or level.variants.has("empty_box")
	var empty_boxes: int = 0
	for peg_index: int in level.covered_pegs:
		if peg_index < 0 or peg_index >= level.get_peg_count():
			continue  # bad indices are reported by Level.check()
		if level.start.pegs[peg_index].is_empty():
			empty_boxes += 1
		if relaxed:
			continue
		if level.start.pegs[peg_index].size() < 2:
			errors.append("covered peg %d hides nothing (fewer than 2 disks)" % peg_index)
		var used: bool = sealed.has(peg_index)
		for i: int in mini(COVERED_REVEAL_WITHIN, level.solution_path.size()):
			var move: Move = level.solution_path[i]
			used = used or move.from_peg == peg_index or move.to_peg == peg_index
		if not used:
			errors.append("covered peg %d is not used in the first %d moves of the solution" % [peg_index, COVERED_REVEAL_WITHIN])
	if empty_boxes > (1 if level.variants.has("empty_box") else 0):
		errors.append("%d empty boxes: an empty peg is never boxed, but for the one empty box" % empty_boxes)
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
	found.append_array(world_three_four_variants(rules, level.get_peg_count(), errors))
	found.append_array(world_five_variants(rules, level, errors))
	found.append_array(world_six_variants(rules, level))
	found.append_array(world_seven_variants(rules, level, errors))
	found.append_array(world_eight_nine_variants(rules, level))
	for variant: String in found:
		if not level.variants.has(variant):
			errors.append("the level has a %s but does not name it" % variant)
	for variant: String in level.variants:
		var missing: bool = false
		match variant:
			"narrow", "arch", "holed", "chain_lock", "sealed", "glass", "oasis", "tunnel", "bridge", "one_way", "jump", \
					"neutral", "colored_base", "paint", "inverse", "back_peg", "shortcut", "center", "eight", "broken_ring", \
					"reset_peg", "new_leader", "waiting_ring", "stone", "long_arm", "three_scales", "own_limits", "moving_stone", \
					"vizier", "narrow_gate", "odd_even", "goal_odd_even", "stone_bridge", "ferry", "two_crossings", "reverse", \
					"bonfire", "mixed", "caravanserai", "three_caravans", "navel", "coloured", "buta", "twin", "target_ko", \
					"free_peg", "long_ko", "two_stones", "two_chains", "breaking", "long_chain", "rubber", "cart", \
					"reverse_weight", "fatigue", "uphill", "neutral_earth", "element_base", "creation", "element_peg", \
					"changing", "clean_peg", "fading", "two_trails", "big_trail", "fair", "sum_and_height", "double_peg", \
					"parity", "pass", "grey", "double_turn", "three_colours", "deep_crack", "two_workshops", "single_repair", \
					"ordered_repair", "long_light", "fixed_lantern", "two_lamps", "lamp_disk", "free_cell", "red_black", \
					"king_spot":
				missing = not found.has(variant)
			"goal_sum":
				missing = not level.rule_ids.has(SumRule.ID)
			"goal_silhouette":
				missing = not level.rule_ids.has(CarpetRule.ID)
			"goal_king":
				missing = not level.rule_ids.has(KingRule.ID)
			"siege":
				missing = not LevelForge._besieged(level.start)
			"mid_start":
				missing = LevelForge.swap_at_home(level.start, 3 if found.has("three_caravans") else 2)
			"full_hidden":
				missing = range(level.get_peg_count()).any(func(peg: int) -> bool:
					return level.covered_pegs.has(peg) == level.start.pegs[peg].is_empty())
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


## The World 3-4 sub-elements `rules` hold on a board of `peg_count` pegs
## (MindShift_Dunya3-4_Alt_Elementler_v1.md); a setting only made for
## measuring (a centre cut off) goes to `errors`.
static func world_three_four_variants(rules: RuleSet, peg_count: int, errors: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for rule: RuleBase in rules.active_rules:
		if rule is AdjacentPegsRule:
			var road: AdjacentPegsRule = rule
			for pair: Array in [["oasis", road.oasis >= 0], ["tunnel", not road.tunnels.is_empty()],
					["bridge", not road.bridges.is_empty()], ["one_way", not road.one_way.is_empty()], ["jump", road.jump]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is StripesRule:
			var stripes: StripesRule = rule
			for pair: Array in [["neutral", stripes.neutral > 0], ["colored_base", stripes.get_params().has("bases")],
					["paint", stripes.paint >= 0], ["inverse", stripes.inverse]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is CyclicRule:
			var dial: CyclicRule = rule
			if dial.center_closed:
				errors.append("a centre cut off from the circle (only for measuring)")
			for pair: Array in [["back_peg", dial.back >= 0], ["shortcut", dial.skip >= 0], ["center", dial.center >= 0],
					["eight", not dial.eight.is_empty()]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is AlternationRule:
			var rings: AlternationRule = rule
			for pair: Array in [["broken_ring", rings.free > 0], ["reset_peg", rings.reset >= 0],
					["new_leader", rings.leader != 1], ["waiting_ring", rings.waiting > 0]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is BalanceRule:
			var scales: BalanceRule = rule
			for pair: Array in [["stone", scales.stone_pan() >= 0], ["long_arm", scales.get_params().has("factors")],
					["own_limits", not scales.tolerances.is_empty()], ["moving_stone", scales.moving_stone],
					["three_scales", peg_count == 6]]:
				if pair[1]:
					found.append(pair[0])
	return found


## The World 5 sub-elements `rules` hold (ICRA World 5-9, sections 3.1-3.3);
## a setting only made for measuring (a ferry closed to elephants) goes to
## `errors`. The king's odd and even towers are "goal_odd_even" where the level
## names that goal variant.
static func world_five_variants(rules: RuleSet, level: Level, errors: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for rule: RuleBase in rules.active_rules:
		if rule is KingRule:
			var king: KingRule = rule
			for pair: Array in [["vizier", king.crowns.size() > 1], ["narrow_gate", not king.narrow.is_empty()],
					["goal_odd_even" if level.variants.has("goal_odd_even") else "odd_even", not king.odd_even.is_empty()]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is RiverRule:
			var river: RiverRule = rule
			if river.ferry_small:
				errors.append("a ferry closed to the elephants (only for measuring)")
			for pair: Array in [["stone_bridge", not river.bridges.is_empty()], ["ferry", river.ferry() >= 0],
					["two_crossings", not river.crossings.is_empty()], ["reverse", river.reverse], ["bonfire", river.fire]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is ColorSwapRule:
			var swap: ColorSwapRule = rule
			for pair: Array in [["mixed", swap.colour_bound], ["caravanserai", swap.caravanserai >= 0],
					["three_caravans", swap.colours == 3]]:
				if pair[1]:
					found.append(pair[0])
	return found


## The World 6 sub-elements `rules` hold (ICRA World 5-9, sections 3.4-3.6):
## a carpet's navel, colours, uneven ("buta") or twin silhouette (a goal
## variant's silhouette is "goal_silhouette" and not named by its shape); Ko's
## kinds of breathing and free peg; a second chain, a chain of three, one that
## breaks, one of rubber.
static func world_six_variants(rules: RuleSet, level: Level) -> Array[String]:
	var found: Array[String] = []
	for rule: RuleBase in rules.active_rules:
		if rule is CarpetRule and not level.variants.has("goal_silhouette"):
			var carpet: CarpetRule = rule
			var mirrored: Array[int] = carpet.heights.duplicate()
			mirrored.reverse()
			var twin: bool = carpet.heights.size() == 6 and carpet.heights.slice(0, 3) == carpet.heights.slice(3)
			for pair: Array in [["navel", not carpet.navel.is_empty()], ["coloured", not carpet.colours.is_empty()],
					["twin", twin], ["buta", not twin and carpet.heights != mirrored]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is KoRule:
			var ko: KoRule = rule
			for pair: Array in [["target_ko", ko.target], ["two_stones", ko.both], ["free_peg", ko.free >= 0],
					["long_ko", ko.turns > 1]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is ChainRule:
			var chain: ChainRule = rule
			for pair: Array in [["two_chains", chain.groups.size() > 1],
					["long_chain", chain.groups.any(func(group: Array) -> bool: return group.size() > 2)],
					["breaking", chain.breaking], ["rubber", chain.rubber]]:
				if pair[1]:
					found.append(pair[0])
	return found


## The World 7 sub-elements `rules` hold (ICRA World 5-9, sections 3.7-3.9);
## a setting only made for measuring (a cart's peg as a plain stop) goes to
## `errors`.
static func world_seven_variants(rules: RuleSet, level: Level, errors: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for rule: RuleBase in rules.active_rules:
		if rule is HeavyRule:
			var heavy: HeavyRule = rule
			if heavy.stop >= 0:
				errors.append("a cart without its free way out (only for measuring)")
			var reversed: bool = heavy.reach.size() > 1 and heavy.reach[-1] == 0 and heavy.reach[0] > 0
			for pair: Array in [["cart", heavy.cart >= 0], ["reverse_weight", reversed], ["fatigue", heavy.fatigue],
					["uphill", heavy.uphill]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is ElementsRule:
			var wuxing: ElementsRule = rule
			for pair: Array in [["neutral_earth", wuxing.earth], ["element_base", wuxing.bases.any(func(b: int) -> bool: return b >= 0)],
					["creation", wuxing.creation], ["element_peg", wuxing.turning >= 0], ["changing", wuxing.changing]]:
				if pair[1]:
					found.append(pair[0])
		elif rule is TrailRule:
			var trail: TrailRule = rule
			for pair: Array in [["clean_peg", trail.clean >= 0], ["fading", trail.recent > 2],
					["two_trails", trail.disks.size() > 1], ["big_trail", trail.disk == level.get_disk_count()]]:
				if pair[1]:
					found.append(pair[0])
	return found


## The World 8-9 sub-elements `rules` hold (ICRA World 5-9, sections
## 3.10-3.14); a goal variant's sums ("goal_sum") are not named by their kind.
static func world_eight_nine_variants(rules: RuleSet, level: Level) -> Array[String]:
	var found: Array[String] = []
	for rule: RuleBase in rules.active_rules:
		var pairs: Array = []
		if rule is SumRule and not level.variants.has("goal_sum"):
			var sum: SumRule = rule
			pairs = [["fair", sum.fair], ["sum_and_height", not sum.counts.is_empty()], ["double_peg", sum.double >= 0],
					["parity", not sum.parity.is_empty()]]
		elif rule is TurnsRule:
			var turns: TurnsRule = rule
			pairs = [["pass", turns.pass], ["grey", turns.colours.has(TurnsRule.GREY)],
					["double_turn", turns.order.size() == 4], ["three_colours", turns.order.has(TurnsRule.RED)]]
		elif rule is KintsugiRule:
			var kintsugi: KintsugiRule = rule
			pairs = [["deep_crack", kintsugi.deep], ["two_workshops", kintsugi.workshops.size() > 1],
					["single_repair", kintsugi.single], ["ordered_repair", kintsugi.ordered]]
		elif rule is LampRule:
			var lamp: LampRule = rule
			pairs = [["long_light", lamp.radius > 1], ["fixed_lantern", lamp.fixed >= 0], ["two_lamps", lamp.two],
					["lamp_disk", lamp.carrier > 0]]
		elif rule is SolitaireRule:
			var solitaire: SolitaireRule = rule
			pairs = [["free_cell", solitaire.cell >= 0], ["red_black", not solitaire.colours.is_empty()],
					["king_spot", solitaire.kings > 0]]
		for pair: Array in pairs:
			if pair[1]:
				found.append(pair[0])
	return found


## "Böyük Mübadilə" (v2, ICRA 3.3): its own size rule (no classic Hanoi), at
## least four pegs. Two colours: k disks of each, the goal every black disk on
## the left end and every white one on the right, the pegs between empty. The
## start: each end one disk of every size k..1, the two disks of a size on
## opposite ends; the pure kind (no colour rule) all white on the left, the
## mixed kind both ends mixed with the largest pair on the wrong ends. Three
## colours ("Üç karvan"): white, black and red stacks on the left end, the
## middle peg and the right end, the goal each on the next one's place. A
## "mid_start" level starts on the way instead, at a legal position (Level.check).
static func validate_color_swap_shape(level: Level, errors: Array[String]) -> void:
	var rules: RuleSet = level.get_rule_set()
	var swap: ColorSwapRule = null
	for rule: RuleBase in rules.active_rules:
		if rule is ColorSwapRule:
			swap = rule
	var colours: int = swap.colours
	if level.rule_ids.has(ClassicHanoiRule.ID) or level.get_disk_count() % colours != 0 or level.get_peg_count() < 4:
		errors.append("a great exchange has its own size rule, k disks of each colour and at least 4 pegs")
		return
	var colour_bound: bool = swap.colour_bound
	var k: int = level.get_disk_count() / colours
	var last: int = level.get_peg_count() - 1
	var expected: PuzzleState = LevelForge.swap_goal(level.get_peg_count(), k, colours)
	if not level.goal.equals(expected):
		errors.append("the goal is every black disk on the left end and every white one on the right" if colours == 2 \
				else "the goal is each caravan on the next one's place")
		return
	if level.variants.has("mid_start"):
		return
	if colours == 3:
		if not level.start.equals(LevelForge.swap_start_three(level.get_peg_count(), k)):
			errors.append("three caravans start white on the left end, black in the middle, red on the right end")
		return
	for peg_index: int in range(1, last):
		if not level.start.pegs[peg_index].is_empty():
			errors.append("the pegs between the two ends start empty")
			return
	var black: Array = []
	var white: Array = []
	for size: int in range(k, 0, -1):
		black.append(ColorSwapRule.disk_of(size, false))
		white.append(ColorSwapRule.disk_of(size, true))
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


## The level's canonical form (PuzzleIdentity): the same for its pegs
## reordered or mirrored and for swapped colours; the same start and goal
## under another rule (a narrower balance, a different capacity) is another
## puzzle. Karakuri boxes do not count (LevelForge.puzzle_key()).
static func puzzle_key(level: Level) -> String:
	return LevelForge.puzzle_key(level.start, level.goal, level.rule_ids, level.rule_params)
