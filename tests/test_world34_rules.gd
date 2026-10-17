extends "res://tests/test_case.gd"
## World 3-4 sub-elements (MindShift_Dunya3-4_Alt_Elementler_v1.md): each
## rule's settings, the moves they allow or refuse and why, and how the forge
## measures a helping or a limiting sub-element.


static func _rules(id: String, params: Dictionary) -> RuleSet:
	var ids: Array[String] = ["classic_hanoi", id]
	return RuleSet.from_ids(ids, {id: params})


func _legal(rules: RuleSet, pegs: Array, from: int, to: int) -> bool:
	return rules.is_move_legal(PuzzleState.new(pegs), Move.new(from, to))


func test_caravan_oasis_tunnel_bridge_one_way_and_jump() -> void:
	# Stops 0, 1, 3 on the road; peg 2 is the oasis beside stop 1.
	var oasis: RuleSet = _rules("adjacent_pegs", {"oasis": [2, 1]})
	assert_true(_legal(oasis, [[], [1], [], [2]], 1, 2), "into the oasis from its stop")
	assert_false(_legal(oasis, [[1], [], [], [2]], 0, 2), "not from another stop")
	assert_true(_legal(oasis, [[], [2], [], []], 1, 3), "stop 1 and stop 3 are neighbours on the road")
	assert_false(_legal(oasis, [[], [1], [2], []], 1, 2), "the oasis holds one disk")
	assert_eq(oasis.get_violation_message(PuzzleState.new([[], [1], [2], []]), Move.new(1, 2)), "RULE_OASIS_FULL")
	var tunnel: RuleSet = _rules("adjacent_pegs", {"tunnels": [[0, 3]]})
	assert_true(_legal(tunnel, [[1], [], [], []], 0, 3), "the tunnel links the ends")
	assert_false(_legal(tunnel, [[1], [], [], []], 0, 2))
	var bridge: RuleSet = _rules("adjacent_pegs", {"bridges": [[1, 2, 2]]})
	assert_true(_legal(bridge, [[], [2], [], []], 1, 2))
	assert_false(_legal(bridge, [[], [3], [], []], 1, 2), "3 is too wide for the bridge")
	assert_eq(bridge.get_violation_message(PuzzleState.new([[], [3], [], []]), Move.new(1, 2)), "RULE_BRIDGE")
	var arrow: RuleSet = _rules("adjacent_pegs", {"one_way": [[1, 2]]})
	assert_true(_legal(arrow, [[], [1], [], []], 1, 2))
	assert_false(_legal(arrow, [[], [], [1], []], 2, 1), "never against the arrow")
	assert_eq(arrow.get_violation_message(PuzzleState.new([[], [], [1], []]), Move.new(2, 1)), "RULE_ONE_WAY")
	assert_true(arrow.can_dead_end(), "a one-way road can leave a disk stranded")
	assert_false(bridge.can_dead_end())
	var jump: RuleSet = _rules("adjacent_pegs", {"jump": true})
	assert_true(_legal(jump, [[1], [3], [], []], 0, 2), "over a larger disk")
	assert_false(_legal(jump, [[2], [1], [], []], 0, 2), "not over a smaller one")
	assert_false(_legal(jump, [[1], [], [], []], 0, 2), "not over an empty stop")


func test_stripes_neutral_base_paint_and_inverse() -> void:
	var neutral: RuleSet = _rules("stripes", {"neutral": 2})
	assert_true(_legal(neutral, [[4], [2], []], 1, 0), "grey on an even disk")
	assert_true(_legal(neutral, [[2], [], [1]], 2, 0), "anything on grey")
	var bases: RuleSet = _rules("stripes", {"bases": [0, 1, 0]})
	assert_false(_legal(bases, [[3], [], []], 0, 1), "an odd disk not on an odd base")
	assert_true(_legal(bases, [[2], [], []], 0, 1))
	assert_eq(bases.get_violation_message(PuzzleState.new([[3], [], []]), Move.new(0, 1)), "RULE_STRIPES_BASE")
	var paint: RuleSet = _rules("stripes", {"paint": 1})
	var state: PuzzleState = PuzzleState.new([[3], [2], [1]])
	assert_false(paint.is_move_legal(state, Move.new(2, 1)), "1 turns even on the way: it may not land on 2")
	var odd: PuzzleState = PuzzleState.new([[3], [], [1]])
	var painted: PuzzleState = paint.apply_move(odd, Move.new(2, 1))
	assert_not_null(painted)
	assert_eq(paint.memory_of(painted), 1, "disk 1 is painted")
	assert_true(paint.is_move_legal(painted, Move.new(1, 0)), "now even, it goes on odd 3")
	var turned: RuleSet = _rules("stripes", {"inverse": true})
	assert_true(_legal(turned, [[3], [1], []], 1, 0), "the same colour now")
	assert_false(_legal(turned, [[2], [1], []], 1, 0))
	assert_eq(turned.get_violation_message(PuzzleState.new([[2], [1], []]), Move.new(1, 0)), "RULE_STRIPES_INVERSE")


func test_dial_back_shortcut_center_and_eight() -> void:
	var back: RuleSet = _rules("cyclic", {"back": 1})
	assert_true(_legal(back, [[], [1], [], []], 1, 0), "back from the two-way peg")
	assert_false(_legal(back, [[], [], [1], []], 2, 1))
	var skip: RuleSet = _rules("cyclic", {"skip": 0})
	assert_true(_legal(skip, [[1], [], [], []], 0, 2), "over the next peg")
	assert_false(_legal(skip, [[], [1], [], []], 1, 3))
	var center: RuleSet = _rules("cyclic", {"center": 4})
	assert_true(_legal(center, [[], [], [1], [], []], 2, 4), "any peg to the centre")
	assert_true(_legal(center, [[], [], [], [], [1]], 4, 1), "and back to any")
	assert_true(_legal(center, [[], [], [], [1], []], 3, 0), "the circle skips the centre")
	assert_false(_legal(center, [[1], [], [], [], [2]], 0, 4), "it holds one disk")
	assert_eq(center.get_violation_message(PuzzleState.new([[1], [], [], [], [2]]), Move.new(0, 4)), "RULE_CENTER_FULL")
	var eight: RuleSet = _rules("cyclic", {"eight": [[0, 1, 2], [0, 4, 3]]})
	assert_true(_legal(eight, [[1], [], [], [], []], 0, 1))
	assert_true(_legal(eight, [[1], [], [], [], []], 0, 4), "the shared peg leads into both circles")
	assert_true(_legal(eight, [[], [], [], [1], []], 3, 0))
	assert_false(_legal(eight, [[], [], [1], [], []], 2, 3), "only through the shared peg")


func test_rings_broken_reset_leader_and_waiting() -> void:
	var broken: RuleSet = _rules("alternation", {"free": 4})
	var start: PuzzleState = PuzzleState.new([[5, 4], [3, 2, 1], [], []])
	assert_true(broken.is_move_legal(start, Move.new(0, 2)), "the broken ring moves first")
	var reset: RuleSet = _rules("alternation", {"reset": 2})
	var after: PuzzleState = reset.apply_move(PuzzleState.new([[5, 3], [4, 2], [1], []]), Move.new(2, 3))
	after = reset.apply_move(after, Move.new(1, 2))
	assert_not_null(after, "2 after 1")
	assert_true(reset.is_move_legal(after, Move.new(0, 3)) == false, "3 may not land on 1")
	assert_true(reset.can_pick_up(after, 0), "after a disk landed on the reset peg any disk may go")
	var leader: RuleSet = _rules("alternation", {"leader": 3})
	var led: PuzzleState = PuzzleState.new([[5, 3], [4, 2, 1], [], []])
	assert_true(leader.can_pick_up(led, 0), "the crowned disk may go first")
	assert_false(leader.can_pick_up(led, 1), "disk 1 is no leader now")
	assert_eq(leader.get_pick_up_violation_message(led, 1), "RULE_ALTERNATION_LEADER")
	var waiting: RuleSet = _rules("alternation", {"waiting": 2})
	var wait: PuzzleState = waiting.apply_move(PuzzleState.new([[5, 3], [4, 2], [1], []]), Move.new(2, 3))
	wait = waiting.apply_move(wait, Move.new(3, 2))
	assert_true(waiting.can_pick_up(wait, 1), "right after the leader")
	var three: PuzzleState = waiting.apply_move(PuzzleState.new([[5, 4], [3], [2, 1], []]), Move.new(2, 3))
	three = waiting.apply_move(three, Move.new(1, 0)) if waiting.is_move_legal(three, Move.new(1, 0)) else three
	assert_eq(waiting.get_pick_up_violation_message(PuzzleState.new([[5], [4, 3], [2], []]), 2), "RULE_WAITING")


func test_scales_stone_long_arm_limits_and_moving_stone() -> void:
	var stone: BalanceRule = RuleSet.create_rule("balance") as BalanceRule
	assert_eq(stone.configure({"tolerance": 2, "weights": [3, 0, 0, 0]}), "")
	assert_eq(stone.weight_of(0, 2), 5, "the stone adds its weight")
	var arm: BalanceRule = RuleSet.create_rule("balance") as BalanceRule
	assert_eq(arm.configure({"tolerance": 2, "factors": [1, 2, 1, 1]}), "")
	assert_eq(arm.weight_of(1, 3), 6, "a long arm doubles")
	var limits: BalanceRule = RuleSet.create_rule("balance") as BalanceRule
	assert_eq(limits.configure({"tolerances": [1, 4]}), "")
	assert_eq([limits.limit_of(0), limits.limit_of(3)], [1, 4])
	assert_ne(limits.configure({"tolerance": 1, "tolerances": [1, 4]}), "", "one or the other")
	var moving: RuleSet = _rules("balance", {"tolerance": 5, "weights": [0, 2, 0, 0], "moving_stone": true})
	var state: PuzzleState = PuzzleState.new([[2], [], [1], []])
	assert_false(_rules("balance", {"tolerance": 3, "weights": [0, 2, 0, 0], "moving_stone": true}).is_move_legal(state,
			Move.new(1, 1)), "not where the scale would tip past its limit (2 + 2 against 0)")
	assert_true(moving.has_special_moves())
	var carry: Move = Move.new(1, 1)
	assert_true(moving.is_move_legal(state, carry), "the stone may go over to pan 0")
	var after: PuzzleState = moving.apply_move(state, carry)
	assert_eq(moving.memory_of(after), 1)
	assert_false(moving.is_move_legal(after, carry), "once only")
	assert_true(moving.can_dead_end(), "it never comes back")
	var level: Level = make_level(19301, ["classic_hanoi", "balance"] as Array[String], [[3], [], [2, 1], []],
			[[], [3], [], [2, 1]], {"balance": {"tolerance": 5, "weights": [0, 2, 0, 0], "moving_stone": true}})
	assert_false(level.solution_path.is_empty(), "the Solver searches with the stone's move")


func test_the_forge_measures_helpers_and_limits() -> void:
	assert_eq(LevelForge.settings_without("oasis", {"adjacent_pegs": {"oasis": [2, 1]}}),
			{"adjacent_pegs": {"oasis": [2, 2]}}, "an oasis cut off from the road")
	assert_eq(LevelForge.settings_without("own_limits", {"balance": {"tolerances": [2, 5]}}),
			{"balance": {"tolerance": 5}}, "every scale at the widest limit")
	assert_null(LevelForge.settings_without("three_scales", {"balance": {"tolerance": 3}}), "a board shape")
	var board: Dictionary = LevelForge.fitted({"pegs": 4, "disks": 5, "variants": ["oasis"]})
	assert_eq(board["pegs"], 5, "an oasis is one more peg")
	assert_eq(LevelForge.fitted({"pegs": 4, "disks": 5, "variants": ["eight"]})["pegs"], 5, "the eight is odd")
	assert_eq(LevelForge.fitted({"pegs": 4, "disks": 5, "variants": ["three_scales"]})["pegs"], 6)
	# A forged tunnel level: without the tunnel it takes longer (it is used).
	var level: Level = forge_level(19302, ["adjacent_pegs"], {"pegs": 4, "disks": 4, "variants": ["tunnel"]}, 5, 30)
	assert_not_null(level)
	var without: Variant = LevelForge.settings_without("tunnel", level.rule_params)
	var longer: Dictionary = Solver.solve(level.start, level.goal, RuleSet.from_ids(level.rule_ids, without))
	assert_true(not longer["solvable"] or longer["min_moves"] > level.min_moves, "the tunnel is used")
	# The validator names what it finds.
	var errors: Array[String] = []
	var found: Array[String] = LevelValidator.world_three_four_variants(level.get_rule_set(), level.get_peg_count(), errors)
	assert_eq(found, ["tunnel"] as Array[String])


func test_board_shapes_of_world_three_four() -> void:
	var cells: Array[Rect2] = BoardLayout.peg_cells(BoardLayout.CIRCLE_CENTER, 5, Vector2(600, 600))
	assert_true(cells[4].get_center().is_equal_approx(Vector2(300, 300)), "the centre peg in the middle")
	var eight: Array[Rect2] = BoardLayout.peg_cells(BoardLayout.EIGHT, 5, Vector2(600, 600))
	assert_true(eight[0].get_center().is_equal_approx(Vector2(300, 300)), "the shared peg in the middle")
	assert_true(eight[1].get_center().x < 300 and eight[4].get_center().x > 300, "one circle each side")
	for i: int in eight.size():
		for j: int in range(i + 1, eight.size()):
			assert_false(eight[i].grow(-8.0).intersects(eight[j].grow(-8.0)), "pegs %d and %d apart" % [i, j])
