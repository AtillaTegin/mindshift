extends "res://tests/test_case.gd"
## RuleSet + ClassicHanoiRule. Day 1 acceptance: a 3-peg / 3-disk start position
## has exactly 2 legal moves.


## Test-only rule: forbids moving onto one peg. Shows a new mechanic plugs into
## RuleSet without changing RuleSet itself.
class ForbiddenTargetRule extends RuleBase:
	var forbidden_peg: int

	func _init(p_forbidden_peg: int) -> void:
		forbidden_peg = p_forbidden_peg

	func get_id() -> String:
		return "test_forbidden_target"

	func is_move_allowed(_state: PuzzleState, move: Move) -> bool:
		return move.to_peg != forbidden_peg


## Test-only rule that only constrains positions: no disks on peg 2.
class EmptyPegTwoRule extends RuleBase:
	func get_id() -> String:
		return "test_empty_peg_two"

	func is_state_valid(state: PuzzleState) -> bool:
		return state.pegs.size() < 3 or state.pegs[2].is_empty()


func test_classic_start_3_pegs_3_disks_has_exactly_two_legal_moves() -> void:
	var rules: RuleSet = RuleSet.classic()
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	var moves: Array[Move] = rules.get_legal_moves(start)
	assert_eq(moves.size(), 2, "legal move count")
	assert_eq(_to_pairs(moves), [[0, 1], [0, 2]], "top disk goes to either other peg")


func test_larger_disk_never_goes_onto_smaller() -> void:
	var rules: RuleSet = RuleSet.classic()
	var state: PuzzleState = PuzzleState.new([[3, 2], [1], []])
	# 0->1 would put disk 2 on disk 1, so it must be filtered out.
	assert_eq(_to_pairs(rules.get_legal_moves(state)), [[0, 2], [1, 0], [1, 2]])


func test_moves_from_empty_pegs_are_filtered() -> void:
	var rules: RuleSet = RuleSet.classic()
	var state: PuzzleState = PuzzleState.new([[], [2, 1], []])
	assert_eq(_to_pairs(rules.get_legal_moves(state)), [[1, 0], [1, 2]])


func test_position_with_one_disk_per_peg() -> void:
	var rules: RuleSet = RuleSet.classic()
	var state: PuzzleState = PuzzleState.new([[3], [2], [1]])
	assert_eq(_to_pairs(rules.get_legal_moves(state)), [[1, 0], [2, 0], [2, 1]])


func test_state_without_disks_has_no_legal_moves() -> void:
	var rules: RuleSet = RuleSet.classic()
	assert_eq(rules.get_legal_moves(PuzzleState.new([[], [], []])).size(), 0)
	assert_eq(rules.get_legal_moves(PuzzleState.new([])).size(), 0)


func test_classic_start_with_4_pegs_has_three_legal_moves() -> void:
	var rules: RuleSet = RuleSet.classic()
	var start: PuzzleState = PuzzleState.new([[4, 3, 2, 1], [], [], []])
	assert_eq(_to_pairs(rules.get_legal_moves(start)), [[0, 1], [0, 2], [0, 3]])


func test_is_move_legal_agrees_with_get_legal_moves() -> void:
	var rules: RuleSet = RuleSet.classic()
	for state: PuzzleState in _reachable_states(rules, PuzzleState.new([[3, 2, 1], [], []])):
		var legal: Array = _to_pairs(rules.get_legal_moves(state))
		for from_peg: int in range(-1, 4):
			for to_peg: int in range(-1, 4):
				var expected: bool = [from_peg, to_peg] in legal
				assert_eq(rules.is_move_legal(state, Move.new(from_peg, to_peg)), expected,
						"%s move %d->%d" % [state.hash_key(), from_peg, to_peg])


func test_legal_moves_always_lead_to_valid_states() -> void:
	var rules: RuleSet = RuleSet.classic()
	var states: Array[PuzzleState] = _reachable_states(rules, PuzzleState.new([[4, 3, 2, 1], [], []]))
	# Every placement of 4 disks on 3 pegs is reachable and classic-valid: 3^4.
	assert_eq(states.size(), 81, "reachable state count")
	for state: PuzzleState in states:
		assert_true(rules.is_state_valid(state), "valid: %s" % state.hash_key())


func test_apply_move_returns_new_state_and_leaves_input_untouched() -> void:
	var rules: RuleSet = RuleSet.classic()
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	var next: PuzzleState = rules.apply_move(start, Move.new(0, 2))
	assert_not_null(next)
	assert_eq(next.to_array(), [[3, 2], [], [1]], "moved state")
	assert_eq(start.to_array(), [[3, 2, 1], [], []], "original state unchanged")
	next.pegs[0].append(99)
	assert_eq(start.to_array(), [[3, 2, 1], [], []], "result shares no arrays with input")


func test_apply_move_rejects_illegal_moves() -> void:
	var rules: RuleSet = RuleSet.classic()
	var state: PuzzleState = PuzzleState.new([[3, 2], [1], []])
	assert_null(rules.apply_move(state, Move.new(0, 1)), "larger onto smaller")
	assert_null(rules.apply_move(state, Move.new(0, 0)), "same peg")
	assert_null(rules.apply_move(state, Move.new(2, 0)), "empty source peg")
	assert_null(rules.apply_move(state, Move.new(3, 0)), "source out of range")
	assert_null(rules.apply_move(state, Move.new(0, 3)), "target out of range")
	assert_null(rules.apply_move(state, Move.new(-1, 0)), "negative source")
	assert_null(rules.apply_move(state, null), "null move")
	assert_null(rules.apply_move(null, Move.new(0, 2)), "null state")
	assert_eq(state.to_array(), [[3, 2], [1], []], "state unchanged after rejections")


func test_is_goal_state() -> void:
	var rules: RuleSet = RuleSet.classic()
	var goal: PuzzleState = PuzzleState.new([[], [], [3, 2, 1]])
	assert_true(rules.is_goal_state(PuzzleState.new([[], [], [3, 2, 1]]), goal))
	assert_false(rules.is_goal_state(PuzzleState.new([[], [3, 2, 1], []]), goal))
	assert_false(rules.is_goal_state(PuzzleState.new([[], [], [3, 2, 1], []]), goal), "peg count differs")
	assert_false(rules.is_goal_state(null, goal))
	assert_false(rules.is_goal_state(goal, null))


func test_from_ids_builds_classic_rule_set() -> void:
	var rules: RuleSet = RuleSet.from_ids(["classic_hanoi"])
	assert_not_null(rules)
	assert_eq(rules.get_rule_ids(), ["classic_hanoi"])
	assert_eq(rules.get_legal_moves(PuzzleState.new([[3, 2, 1], [], []])).size(), 2)
	assert_eq(RuleSet.classic().get_rule_ids(), ["classic_hanoi"])


func test_from_ids_rejects_bad_input() -> void:
	assert_null(RuleSet.from_ids(["classic_hanoi", "no_such_rule"]), "unknown id")
	assert_null(RuleSet.from_ids([1]), "non-string id")
	assert_null(RuleSet.from_ids("classic_hanoi"), "not an array")
	assert_null(RuleSet.from_ids(null), "null")
	assert_null(RuleSet.create_rule("no_such_rule"))


func test_is_state_valid() -> void:
	var rules: RuleSet = RuleSet.classic()
	assert_true(rules.is_state_valid(PuzzleState.new([[5, 3, 1], [4], [2], []])), "spec example start")
	assert_true(rules.is_state_valid(PuzzleState.new([[], [], []])), "no disks")
	assert_false(rules.is_state_valid(PuzzleState.new([[1, 2], [], []])), "smaller under larger")
	assert_false(rules.is_state_valid(PuzzleState.new([[2, 2], [], []])), "equal sizes stacked")
	assert_false(rules.is_state_valid(PuzzleState.new([[2], [2], []])), "duplicate size")
	assert_false(rules.is_state_valid(PuzzleState.new([[0], [], []])), "zero size")
	assert_false(rules.is_state_valid(PuzzleState.new([[-3], [], []])), "negative size")
	assert_false(rules.is_state_valid(PuzzleState.new([])), "no pegs")
	assert_false(rules.is_state_valid(null), "null")
	var tampered: PuzzleState = PuzzleState.new([[], [], []])
	tampered.pegs[0].append(1.5)
	assert_false(rules.is_state_valid(tampered), "non-integer size")


func test_rule_set_without_rules_only_checks_structure() -> void:
	var rules: RuleSet = RuleSet.new()
	var state: PuzzleState = PuzzleState.new([[3, 2], [1], []])
	assert_eq(_to_pairs(rules.get_legal_moves(state)), [[0, 1], [0, 2], [1, 0], [1, 2]])
	assert_true(rules.is_state_valid(PuzzleState.new([[1, 2], [], []])), "ordering is a rule, not structure")
	# Structural checks must hold on their own, without the classic rule's help.
	assert_true(rules.is_move_legal(state, Move.new(0, 1)), "larger onto smaller is fine without rules")
	assert_false(rules.is_move_legal(state, Move.new(0, 0)), "same peg")
	assert_null(rules.apply_move(state, Move.new(0, 0)), "same peg")
	assert_false(rules.is_move_legal(state, Move.new(2, 0)), "empty source")
	assert_false(rules.is_move_legal(state, Move.new(0, 3)), "target out of range")


func test_every_rule_state_check_counts() -> void:
	var rules: RuleSet = RuleSet.classic()
	rules.active_rules.append(EmptyPegTwoRule.new())
	assert_true(rules.is_state_valid(PuzzleState.new([[2], [1], []])))
	assert_false(rules.is_state_valid(PuzzleState.new([[2], [], [1]])), "second rule rejects")


func test_rule_base_defaults_allow_everything() -> void:
	# A rule that only overrides is_state_valid does not restrict moves...
	var state_only: Array[RuleBase] = [EmptyPegTwoRule.new()]
	var moves: Array[Move] = RuleSet.new(state_only).get_legal_moves(PuzzleState.new([[2], [1], []]))
	assert_eq(moves.size(), 4)
	# ...and one that only overrides is_move_allowed does not restrict positions.
	var move_only: Array[RuleBase] = [ForbiddenTargetRule.new(2)]
	assert_true(RuleSet.new(move_only).is_state_valid(PuzzleState.new([[1, 2], [], [3]])))
	var base: RuleBase = RuleBase.new()
	assert_true(base.is_move_allowed(PuzzleState.new([[2], [1], []]), Move.new(0, 1)))
	assert_true(base.is_state_valid(PuzzleState.new([[1, 2], [], []])))


func test_new_rule_combines_with_classic_without_changing_rule_set() -> void:
	var rules: RuleSet = RuleSet.classic()
	rules.active_rules.append(ForbiddenTargetRule.new(2))
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	assert_eq(_to_pairs(rules.get_legal_moves(start)), [[0, 1]])
	assert_null(rules.apply_move(start, Move.new(0, 2)))
	assert_eq(rules.get_rule_ids(), ["classic_hanoi", "test_forbidden_target"])


func test_classic_rule_fast_path_hooks() -> void:
	var rule: ClassicHanoiRule = ClassicHanoiRule.new()
	assert_true(rule.supports_disk_move_check())
	assert_true(rule.keeps_stacks_sorted())
	assert_true(rule.is_disk_move_allowed(1, 0, 1, -1), "onto empty peg")
	assert_true(rule.is_disk_move_allowed(1, 0, 1, 2), "onto larger disk")
	assert_false(rule.is_disk_move_allowed(2, 0, 1, 1), "onto smaller disk")
	assert_false(rule.is_disk_move_allowed(2, 0, 1, 2), "onto equal disk")
	var base: RuleBase = RuleBase.new()
	assert_false(base.supports_disk_move_check(), "opt-in only")
	assert_false(base.keeps_stacks_sorted(), "opt-in only")


func test_classic_move_check_uses_disk_check() -> void:
	# is_move_allowed() must agree with is_disk_move_allowed() on every move.
	var rules: RuleSet = RuleSet.new()
	var rule: ClassicHanoiRule = ClassicHanoiRule.new()
	for state: PuzzleState in _reachable_states(rules, PuzzleState.new([[3, 2, 1], [], []])):
		for move: Move in rules.get_legal_moves(state):
			var expected: bool = rule.is_disk_move_allowed(state.get_top_disk(move.from_peg),
					move.from_peg, move.to_peg, state.get_top_disk(move.to_peg))
			assert_eq(rule.is_move_allowed(state, move), expected, "%s %s" % [state.hash_key(), str(move)])


func test_constructor_copies_rule_array() -> void:
	var source: Array[RuleBase] = [ClassicHanoiRule.new()]
	var rules: RuleSet = RuleSet.new(source)
	source.append(ForbiddenTargetRule.new(1))
	assert_eq(rules.active_rules.size(), 1)


static func _to_pairs(moves: Array[Move]) -> Array:
	var pairs: Array = []
	for move: Move in moves:
		pairs.append(move.to_array())
	return pairs


## Every state reachable from `start` (BFS), start included.
static func _reachable_states(rules: RuleSet, start: PuzzleState) -> Array[PuzzleState]:
	var states: Array[PuzzleState] = [start]
	var seen: Dictionary[String, bool] = {start.hash_key(): true}
	var index: int = 0
	while index < states.size():
		var state: PuzzleState = states[index]
		index += 1
		for move: Move in rules.get_legal_moves(state):
			var next: PuzzleState = rules.apply_move(state, move)
			var key: String = next.hash_key()
			if not seen.has(key):
				seen[key] = true
				states.append(next)
	return states
