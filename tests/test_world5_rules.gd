extends "res://tests/test_case.gd"
## World 5 (MindShift_ICRA_Dunya5-9_Yeni_Modlar_v1.md): the goal condition
## engine (section 2), the king, the elephant river and the exchange's new
## waves (sections 3.1-3.3), and the goal variants (section 4).


static func _rules(id: String, params: Dictionary) -> RuleSet:
	var ids: Array[String] = ["classic_hanoi", id]
	return RuleSet.from_ids(ids, {id: params})


func _legal(rules: RuleSet, pegs: Array, from: int, to: int) -> bool:
	return rules.is_move_legal(PuzzleState.new(pegs), Move.new(from, to))


func test_king_goal_is_a_condition() -> void:
	var king: RuleSet = _rules("king", {"crowns": [[3, 2]]})
	assert_not_null(king.goal_rule(), "the king sets the goal")
	var start: PuzzleState = PuzzleState.new([[3, 1], [2], [], []])
	assert_false(king.is_goal_state(start, start))
	assert_true(king.is_goal_state(PuzzleState.new([[1], [], [3], [2]]), start), "only the crown counts")
	var result: Dictionary = Solver.solve(start, start, king, 100000)
	assert_true(result["solvable"])
	assert_eq(result["strategy"], "packed_history", "a goal condition searches one way")
	# 1 off the king, then the king to its gate.
	assert_eq(result["min_moves"], 2)
	var end: PuzzleState = LevelForge.end_of(start, result["path"], king)
	assert_true(king.is_goal_state(end, start))
	# The generic search agrees.
	var generic: Dictionary = Solver._solve_generic(start, start, king, 100000)
	assert_eq(generic["min_moves"], 2)


func test_one_goal_rule_per_set() -> void:
	var errors: Array[String] = []
	var ids: Array[String] = ["classic_hanoi", "king", "king"]
	assert_null(RuleSet.from_ids(ids, {"king": {"crowns": [[3, 1]]}}, errors))


func test_king_vizier_narrow_gate_and_odd_even() -> void:
	var both: RuleSet = _rules("king", {"crowns": [[4, 3], [3, 0]]})
	assert_false(both.is_goal_state(PuzzleState.new([[], [3], [2, 1], [4]]), null), "the vizier is not home yet")
	assert_true(both.is_goal_state(PuzzleState.new([[3], [2, 1], [], [4]]), null))
	var narrow: RuleSet = _rules("king", {"crowns": [[3, 2]], "narrow": [[2, 1]]})
	assert_true(_legal(narrow, [[], [1], [], [3, 2]], 1, 2), "into the gate from its entry")
	assert_false(_legal(narrow, [[], [], [], [3, 2, 1]], 3, 2), "not from another peg")
	assert_eq(narrow.get_violation_message(PuzzleState.new([[], [], [], [3, 2, 1]]), Move.new(3, 2)), "RULE_NARROW_GATE")
	var odd_even: RuleSet = _rules("king", {"odd_even": [0, 2]})
	assert_null(odd_even.goal_rule(), "the odd and even towers are one exact goal")
	assert_eq(LevelForge._odd_even_state(3, 4, [0, 2]).pegs, [[3, 1], [], [4, 2]] as Array[Array])
	var errors: Array[String] = []
	assert_null(RuleSet.from_ids(["classic_hanoi", "king"] as Array[String], {"king": {}}, errors), "crowns or towers")


func test_king_level_checks_and_identity() -> void:
	var start: PuzzleState = PuzzleState.new([[3, 1], [2], [], []])
	var ids: Array[String] = ["classic_hanoi", "king"]
	var params: Dictionary = {"king": {"crowns": [[3, 2]]}}
	var rules: RuleSet = RuleSet.from_ids(ids, params)
	var result: Dictionary = Solver.solve(start, start, rules, 100000)
	var path: Array[Move] = result["path"]
	var goal: PuzzleState = LevelForge.end_of(start, path, rules)
	var level: Level = Level.create(10001, "easy", start, goal, ids, path, params)
	var errors: Array[String] = []
	level.check(errors)
	# 2 moves is below every tier, which is all check() may say.
	assert_true(errors.all(func(error: String) -> bool: return error.begins_with("min_moves")), str(errors))
	# Any other end position meeting the condition is the same puzzle.
	var other: PuzzleState = PuzzleState.new([[], [2], [3], [1]])
	assert_eq(LevelForge.puzzle_key(start, goal, ids, params), LevelForge.puzzle_key(start, other, ids, params))
	# A start that already meets the condition is refused.
	var met: Level = Level.create(10002, "easy", goal, goal, ids, [] as Array[Move], params)
	errors.clear()
	met.check(errors)
	assert_true(errors.has("start equals goal"))


func test_river_elephants_bridge_ferry_crossings_reverse() -> void:
	var river: RuleSet = _rules("river", {"banks": [0, 0, 1, 1], "elephant": 3})
	assert_true(_legal(river, [[2], [], [], []], 0, 2), "a small disk crosses")
	assert_false(_legal(river, [[3], [], [], []], 0, 2), "an elephant does not")
	assert_eq(river.get_violation_message(PuzzleState.new([[3], [], [], []]), Move.new(0, 2)), "RULE_ELEPHANT")
	assert_true(_legal(river, [[3], [], [], []], 0, 1), "along its own bank")
	var bridge: RuleSet = _rules("river", {"banks": [0, 0, 1, 1], "elephant": 3, "bridges": [[1, 2]]})
	assert_true(_legal(bridge, [[], [3], [], []], 1, 2), "over the stone bridge")
	assert_false(_legal(bridge, [[3], [], [], []], 0, 2))
	var ferry: RuleSet = _rules("river", {"banks": [0, 0, 2, 1, 1], "elephant": 3})
	assert_true(_legal(ferry, [[3], [], [], [], []], 0, 2), "an elephant boards the ferry")
	assert_true(_legal(ferry, [[], [], [3], [], []], 2, 4), "and leaves it for the other bank")
	assert_false(_legal(ferry, [[1], [], [3], [], []], 0, 2), "the ferry carries one disk")
	assert_eq(ferry.get_violation_message(PuzzleState.new([[1], [], [3], [], []]), Move.new(0, 2)), "RULE_FERRY_FULL")
	assert_false(ferry.is_state_valid(PuzzleState.new([[], [], [3, 1], [], []])))
	var fords: RuleSet = _rules("river", {"banks": [0, 0, 1, 1], "elephant": 4, "crossings": [[1, 2, 3], [0, 3, 1]]})
	assert_true(_legal(fords, [[], [3], [], []], 1, 2))
	assert_false(_legal(fords, [[2], [], [], []], 0, 3), "this ford takes 1 only")
	assert_false(_legal(fords, [[1], [], [], []], 0, 2), "no ford there")
	assert_eq(fords.get_violation_message(PuzzleState.new([[2], [], [], []]), Move.new(0, 3)), "RULE_CROSSING")
	var reverse: RuleSet = _rules("river", {"banks": [0, 0, 1, 1], "elephant": 3, "reverse": true})
	assert_true(_legal(reverse, [[3], [], [], []], 0, 2), "only elephants cross")
	assert_false(_legal(reverse, [[1], [], [], []], 0, 2))
	assert_eq(reverse.get_violation_message(PuzzleState.new([[1], [], [], []]), Move.new(0, 2)), "RULE_RIVER_REVERSE")
	var errors: Array[String] = []
	assert_null(RuleSet.from_ids(["classic_hanoi", "river"] as Array[String], {"river": {"banks": [0, 1, 1], "elephant": 3}},
			errors), "two pegs on each bank")


func test_exchange_three_caravans_and_caravanserai() -> void:
	assert_eq(ColorSwapRule.disk_with(2, ColorSwapRule.RED, 3), 6)
	assert_eq(ColorSwapRule.size_of(6, 3), 2)
	assert_eq(ColorSwapRule.colour_of(6, 3), ColorSwapRule.RED)
	assert_eq(ColorSwapRule.disk_with(3, ColorSwapRule.BLACK, 2), ColorSwapRule.disk_of(3, false), "two colours as before")
	var three: RuleSet = RuleSet.from_ids(["color_swap"] as Array[String], {"color_swap": {"colour": false, "colours": 3}})
	assert_false(_legal(three, [[4], [6], []], 0, 1), "equal sizes never stack")
	assert_true(_legal(three, [[1], [6], []], 0, 1))
	var inn: RuleSet = RuleSet.from_ids(["color_swap"] as Array[String], {"color_swap": {"colour": true, "caravanserai": 1}})
	assert_true(_legal(inn, [[1], [4], [4]], 0, 1), "colours mix in the caravanserai")
	assert_false(_legal(inn, [[1], [], [4]], 0, 2), "not elsewhere")
	var start: PuzzleState = LevelForge.swap_start_three(5, 2)
	var goal: PuzzleState = LevelForge.swap_goal(5, 2, 3)
	assert_eq(start.pegs[0], [4, 1], "white at home on the left")
	assert_eq(goal.pegs[2], [4, 1], "white goes to black's home")
	assert_true(LevelForge.swap_at_home(start, 3))
	assert_false(LevelForge.swap_at_home(PuzzleState.new([[4], [1], [5, 2], [], [6, 3]]), 3))
	var result: Dictionary = Solver.solve(start, goal, three, 2000000)
	assert_true(result["solvable"], "three caravans can turn round")


func test_goal_variant_is_no_mode() -> void:
	var start: PuzzleState = PuzzleState.new([[4, 1], [3], [2], []])
	var ids: Array[String] = ["classic_hanoi", "king", "river"]
	var params: Dictionary = {"king": {"crowns": [[4, 3]]}, "river": {"banks": [0, 0, 1, 1], "elephant": 4,
			"bridges": [[1, 3]]}}
	var level: Level = Level.create(10003, "easy", start, start, ids, [] as Array[Move], params)
	level.variants.assign(["goal_king"])
	assert_eq(level.modes(), ["river"] as Array[String], "a river level with the king's goal")
	assert_eq(level.mechanic(), "river")
	assert_eq(level.lesson(), "river")
	assert_false(level.is_combo())
	var combo: Level = Level.create(10004, "easy", start, start, ids, [] as Array[Move], params)
	assert_true(combo.is_combo(), "without the variant the king is a mode of its own")


func test_forge_draws_world_five() -> void:
	var king: Level = forge_level(10005, ["king"], {"pegs": 4, "disks": 7, "variants": ["siege"]}, 6, 30)
	assert_not_null(king)
	assert_true(LevelForge._besieged(king.start))
	assert_true(king.get_rule_set().is_goal_state(king.goal, king.goal), "the goal meets the crown's condition")
	var river: Level = forge_level(10006, ["river"], {"pegs": 4, "disks": 6, "variants": ["ferry"]}, 6, 40)
	assert_not_null(river)
	assert_eq(river.get_peg_count(), 5, "the ferry is a peg of its own")
	var swap: Level = forge_level(10007, ["color_swap"], {"pegs": 5, "disks": 6, "variants": ["mid_start"]}, 6, 40)
	assert_not_null(swap)
	assert_false(LevelForge.swap_at_home(swap.start, 2), "the caravans start on the way")
	assert_false(swap.rule_ids.has("classic_hanoi"), "the exchange brings its own size rule")
