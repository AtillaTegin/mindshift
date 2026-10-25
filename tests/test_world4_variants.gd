extends "res://tests/test_case.gd"

## World 4 sub-elements (Dünya 3-4 Alt-Elementlər): each one, drawn on a small
## board, must change the solution (a limit lengthens it, a helper is needed).
## A variant that cannot be drawn is reported by name, never skipped silently.

const CASES: Array = [
	["alternation", "broken_ring", 4, 5],
	["alternation", "reset_peg", 4, 5],
	["alternation", "new_leader", 4, 5],
	["alternation", "waiting_ring", 4, 5],
	["balance", "stone", 4, 4],
	["balance", "long_arm", 4, 4],
	["balance", "three_scales", 6, 4],
	["balance", "own_limits", 4, 4],
]


func test_every_world_four_sub_element_changes_the_solution() -> void:
	var lines: Array[String] = []
	var failed: Array[String] = []
	for entry: Array in CASES:
		var mode: String = entry[0]
		var variant: String = entry[1]
		var board: Dictionary = LevelForge.fitted({"pegs": entry[2], "disks": entry[3], "variants": [variant]})
		var level: Level = forge_level(19400, [mode], board, 5, 30)
		if level == null:
			lines.append("%s: NOT DRAWN" % variant)
			failed.append(variant)
			continue
		var helper: bool = ChapterPlan.HELPERS.has(variant)
		var without: Variant = LevelForge.settings_without(variant, level.rule_params)
		var before: String = "-"
		var after: int = level.min_moves
		if without != null:
			var rules: RuleSet = RuleSet.from_ids(level.rule_ids, without)
			var result: Dictionary = Solver.solve(level.start, level.goal, rules, LevelForge.MAX_STATES)
			before = str(result["min_moves"]) if result["solvable"] else "unsolvable"
			var matters: bool = LevelForge.variants_matter(level.start, level.goal, level.rule_ids, level.rule_params,
					[variant], level.min_moves)
			if not matters:
				failed.append(variant)
		lines.append("%s (%s): %s -> %d" % [variant, "helper" if helper else "limit", before, after])
	print("WORLD4_VARIANTS\n" + "\n".join(lines))
	assert_true(failed.is_empty(), "not measured or no effect: %s" % ", ".join(failed))
