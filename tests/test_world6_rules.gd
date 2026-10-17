extends "res://tests/test_case.gd"
## World 6 (MindShift_ICRA_Dunya5-9_Yeni_Modlar_v1.md, sections 3.4-3.6): the
## carpet's silhouette goal, Ko's breathing pegs, and the chain's new waves
## (two chains, a chain of three, one that breaks, one of rubber).


static func _rules(id: String, params: Dictionary) -> RuleSet:
	var ids: Array[String] = ["classic_hanoi", id]
	return RuleSet.from_ids(ids, {id: params})


func _legal(rules: RuleSet, pegs: Array, from: int, to: int) -> bool:
	return rules.is_move_legal(PuzzleState.new(pegs), Move.new(from, to))


func test_carpet_goal_is_the_silhouette() -> void:
	var carpet: RuleSet = _rules("carpet", {"heights": [1, 2, 1]})
	assert_not_null(carpet.goal_rule())
	var start: PuzzleState = PuzzleState.new([[4, 3, 2, 1], [], []])
	assert_false(carpet.is_goal_state(start, start))
	assert_true(carpet.is_goal_state(PuzzleState.new([[3], [4, 1], [2]]), start), "any disks in that silhouette")
	var result: Dictionary = Solver.solve(start, start, carpet, 100000)
	assert_eq(result["min_moves"], 4, "1 right, 2 to the middle, 1 onto it, 3 right")
	var navel: RuleSet = _rules("carpet", {"heights": [1, 2, 1], "navel": [1, 2]})
	assert_false(navel.is_goal_state(PuzzleState.new([[3], [4, 1], [2]]), null), "the navel's disk is not on top")
	assert_true(navel.is_goal_state(PuzzleState.new([[3], [4, 2], [1]]), null))
	var coloured: RuleSet = _rules("carpet", {"heights": [1, 2, 1], "colours": [0, 1, 0, 1], "tops": [1, -1, -1]})
	assert_true(coloured.is_goal_state(PuzzleState.new([[4], [3, 1], [2]]), null), "disk 4 is of colour 1")
	assert_false(coloured.is_goal_state(PuzzleState.new([[3], [4, 1], [2]]), null))


func test_ko_breathing_pegs() -> void:
	var ko: RuleSet = _rules("ko", {})
	var start: PuzzleState = PuzzleState.new([[2, 1], [], []])
	var after: PuzzleState = ko.apply_move(start, Move.new(0, 1))
	assert_not_null(after)
	assert_false(ko.is_move_legal(after, Move.new(0, 2)), "the peg 1 was taken from breathes")
	assert_false(ko.is_move_legal(after, Move.new(1, 0)), "nothing goes back onto it either")
	assert_eq(ko.get_violation_message(after, Move.new(1, 0)), "RULE_KO")
	assert_true(ko.is_move_legal(after, Move.new(1, 2)))
	assert_false(ko.can_pick_up(after, 0), "its disk waits")
	var target: RuleSet = _rules("ko", {"target": true})
	var landed: PuzzleState = target.apply_move(start, Move.new(0, 1))
	assert_true(target.is_move_legal(landed, Move.new(0, 2)), "the source is free now")
	assert_false(target.is_move_legal(landed, Move.new(1, 2)), "the target breathes")
	var free: RuleSet = _rules("ko", {"free": 0})
	assert_true(free.is_move_legal(free.apply_move(start, Move.new(0, 1)), Move.new(0, 2)), "the free peg never breathes")
	var long: RuleSet = _rules("ko", {"turns": 2})
	var twice: PuzzleState = long.apply_move(long.apply_move(PuzzleState.new([[3, 2, 1], [], []]), Move.new(0, 1)), Move.new(1, 2))
	assert_false(long.is_move_legal(twice, Move.new(0, 1)), "peg 0 still breathes a move later")
	# On four pegs a tower of three takes 5 classic moves; breathing makes it longer.
	var solved: Dictionary = Solver.solve(PuzzleState.new([[3, 2, 1], [], [], []]), PuzzleState.new([[], [], [], [3, 2, 1]]),
			ko, 100000)
	assert_true(solved["min_moves"] > 5, "breathing makes the tower longer (%d)" % solved["min_moves"])


func test_two_chains_and_a_chain_of_three() -> void:
	var two: RuleSet = _rules("chain", {"groups": [[1, 3], [2, 4]]})
	var state: PuzzleState = PuzzleState.new([[3], [1], [4], [2], []])
	assert_eq(two.group_of(2, state), [2, 4] as Array[int])
	assert_false(two.is_move_legal(state, Move.new(3, 4)), "2 never moves alone")
	assert_true(two.is_move_legal(state, Move.new(1, 4, 0, 1)), "1 and 3 together")
	var three: RuleSet = _rules("chain", {"groups": [[1, 2, 3]]})
	var spread: PuzzleState = PuzzleState.new([[1], [2], [3], [], []])
	var moves: Array[Move] = three.get_legal_moves(spread)
	assert_true(moves.all(func(move: Move) -> bool: return move.from_peg_3 >= 0), "the three move together")
	var move: Move = Move.new(0, 3, 1, 4, 2, 0)
	assert_true(three.is_move_legal(spread, move))
	assert_eq(three.apply_move(spread, move).pegs, [[3], [], [], [1], [2]] as Array[Array])
	assert_eq(Move.from_array([0, 3, 1, 4, 2, 0]).to_array(), [0, 3, 1, 4, 2, 0])
	var result: Dictionary = Solver.solve(spread, PuzzleState.new([[], [], [], [3, 2, 1], []]), three, 200000)
	assert_eq(result["strategy"], "generic", "a chain of three is searched generically")


func test_a_chain_breaks_and_rubber_holds() -> void:
	var breaking: RuleSet = _rules("chain", {"disks": [1, 3], "breaking": true})
	var state: PuzzleState = breaking.prepared(PuzzleState.new([[1], [3], [], []]))
	var together: Move = Move.new(0, 2, 1, 2)
	assert_true(breaking.is_move_legal(state, together), "the pair may land on one peg")
	var after: PuzzleState = breaking.apply_move(state, together)
	assert_eq(after.pegs[2], [3, 1], "the larger first, the smaller on it")
	assert_eq(breaking.group_of(1, after), [] as Array[int], "the chain is broken for good")
	assert_true(breaking.is_move_legal(after, Move.new(2, 0)), "1 moves alone now")
	var plain: RuleSet = _rules("chain", {"disks": [1, 3]})
	assert_false(plain.is_move_legal(plain.prepared(PuzzleState.new([[1], [3], [], []])), together), "an unbreaking pair never shares a peg")
	var rubber: RuleSet = _rules("chain", {"disks": [1, 3], "rubber": true})
	var spread: PuzzleState = PuzzleState.new([[1], [3], [], [], []])
	assert_true(rubber.is_move_legal(spread, Move.new(0, 2, 1, 3)), "two neighbouring pegs")
	assert_false(rubber.is_move_legal(spread, Move.new(0, 2, 1, 4)))
	assert_eq(rubber.get_violation_message(spread, Move.new(0, 2, 1, 4)), "RULE_RUBBER")
	var found: Dictionary = Solver.solve(spread, PuzzleState.new([[], [], [], [3], [1]]), rubber, 200000)
	assert_true(found["solvable"])
	assert_true((found["path"] as Array).all(func(move: Move) -> bool:
		return not move.is_compound() or absi(move.to_peg - move.to_peg_2) == 1), "the fast search keeps the rubber too")


func test_a_session_takes_three_targets() -> void:
	var ids: Array[String] = ["classic_hanoi", "chain"]
	var level: Level = make_level(10101, ids, [[1], [2], [3], [], []], [[], [], [], [3, 2, 1], []],
			{"chain": {"groups": [[1, 2, 3]]}})
	var session: GameSession = GameSession.new(level)
	assert_eq(session.tap_peg(0), GameSession.TapResult.SELECTED)
	assert_eq(session.get_selected_disks(), [1, 2, 3] as Array[int], "the whole chain is lifted")
	assert_eq(session.tap_peg(3), GameSession.TapResult.TARGETED)
	assert_eq(session.tap_peg(4), GameSession.TapResult.TARGETED)
	assert_eq(session.tap_peg(0), GameSession.TapResult.MOVED)
	assert_eq(session.state.pegs, [[3], [], [], [1], [2]] as Array[Array])
