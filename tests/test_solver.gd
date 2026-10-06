extends "res://tests/test_case.gd"
## Solver. Day 2 acceptance: classic 3-peg Hanoi gives 2^N - 1 (N=3 -> 7,
## N=4 -> 15) and 4 pegs / 8 disks solves in under 5 seconds (time is logged).

const PERFORMANCE_LIMIT_MS: int = 5000


## Classic rule that hides its fast-path support, forcing the generic search.
## Lets every test compare both strategies on identical puzzles.
class OpaqueClassicRule extends ClassicHanoiRule:
	func supports_disk_move_check() -> bool:
		return false


## Asymmetric test rule: even disks may not be placed on peg 1. Moves are not
## always reversible under it, which exercises the backward half of the search.
class NoEvenDiskOnPegOneRule extends RuleBase:
	func get_id() -> String:
		return "test_no_even_on_peg_one"

	func supports_disk_move_check() -> bool:
		return true

	func is_disk_move_allowed(disk: int, _from_peg: int, to_peg: int, _target_top: int) -> bool:
		return not (to_peg == 1 and disk % 2 == 0)


func test_classic_3_pegs_matches_formula() -> void:
	for disks: int in range(1, 9):
		var result: Dictionary = _solve_checked(_tower(3, disks, 0), _tower(3, disks, 2), RuleSet.classic())
		assert_eq(result["min_moves"], (1 << disks) - 1, "fast, N=%d" % disks)
	for disks: int in range(1, 7):
		var result: Dictionary = _solve_checked(_tower(3, disks, 0), _tower(3, disks, 2), _generic_classic())
		assert_eq(result["min_moves"], (1 << disks) - 1, "generic, N=%d" % disks)


func test_spec_examples_n3_is_7_and_n4_is_15() -> void:
	for rules: RuleSet in [RuleSet.classic(), _generic_classic()]:
		assert_eq(_solve_checked(_tower(3, 3, 0), _tower(3, 3, 2), rules)["min_moves"], 7)
		assert_eq(_solve_checked(_tower(3, 4, 0), _tower(3, 4, 2), rules)["min_moves"], 15)


func test_4_pegs_8_disks_under_5_seconds() -> void:
	var started_ms: int = Time.get_ticks_msec()
	var result: Dictionary = Solver.solve(_tower(4, 8, 0), _tower(4, 8, 3), RuleSet.classic())
	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	print("    [perf] 4 pegs / 8 disks: %d moves, %d states, %d ms (limit %d ms)" % [
			result["min_moves"], result["states_visited"], elapsed_ms, PERFORMANCE_LIMIT_MS])
	assert_eq(result["min_moves"], 33, "Frame-Stewart value")
	assert_eq(result["strategy"], "packed")
	assert_true(_path_reaches_goal(_tower(4, 8, 0), _tower(4, 8, 3), result["path"], RuleSet.classic()))
	assert_true(elapsed_ms < PERFORMANCE_LIMIT_MS, "took %d ms" % elapsed_ms)


func test_largest_spec_sizes_log_time() -> void:
	# Expert levels go up to 4-5 pegs and 10 disks; log how the solver copes.
	for config: Array in [[4, 10], [5, 10]]:
		var start: PuzzleState = _tower(config[0], config[1], 0)
		var goal: PuzzleState = _tower(config[0], config[1], config[0] - 1)
		var started_ms: int = Time.get_ticks_msec()
		var result: Dictionary = Solver.solve(start, goal, RuleSet.classic(), 2000000)
		print("    [perf] %d pegs / %d disks: %d moves, %d states, %d ms" % [
				config[0], config[1], result["min_moves"], result["states_visited"], Time.get_ticks_msec() - started_ms])
		assert_true(result["solvable"])
		assert_true(_path_reaches_goal(start, goal, result["path"], RuleSet.classic()))


func test_frame_stewart_values() -> void:
	var four_pegs: Array[int] = [1, 3, 5, 9, 13, 17, 25]
	for i: int in four_pegs.size():
		var disks: int = i + 1
		assert_eq(_solve_checked(_tower(4, disks, 0), _tower(4, disks, 3), RuleSet.classic())["min_moves"],
				four_pegs[i], "4 pegs, %d disks" % disks)
	var five_pegs: Array[int] = [1, 3, 5, 7, 11, 15]
	for i: int in five_pegs.size():
		var disks: int = i + 1
		assert_eq(_solve_checked(_tower(5, disks, 0), _tower(5, disks, 4), RuleSet.classic())["min_moves"],
				five_pegs[i], "5 pegs, %d disks" % disks)


func test_fast_and_generic_agree_on_random_puzzles() -> void:
	_cross_check(RuleSet.classic(), _generic_classic(), 120, 1)


func test_fast_and_generic_agree_with_asymmetric_rule() -> void:
	var fast: RuleSet = RuleSet.classic()
	fast.active_rules.append(NoEvenDiskOnPegOneRule.new())
	var generic: RuleSet = _generic_classic()
	generic.active_rules.append(NoEvenDiskOnPegOneRule.new())
	_cross_check(fast, generic, 120, 2)


func test_start_equals_goal() -> void:
	var state: PuzzleState = PuzzleState.new([[3, 1], [2], []])
	var result: Dictionary = Solver.solve(state, state.duplicate_state(), RuleSet.classic())
	assert_true(result["solvable"])
	assert_eq(result["min_moves"], 0)
	assert_eq(result["path"].size(), 0)
	assert_false(result["limit_reached"])


func test_mid_game_start_and_custom_goal() -> void:
	# The spec's sample start; goal is everything on the last peg.
	var start: PuzzleState = PuzzleState.new([[5, 3, 1], [4], [2], []])
	var goal: PuzzleState = PuzzleState.new([[], [], [], [5, 4, 3, 2, 1]])
	var fast: Dictionary = _solve_checked(start, goal, RuleSet.classic())
	var generic: Dictionary = _solve_checked(start, goal, _generic_classic())
	assert_true(fast["solvable"])
	assert_eq(fast["min_moves"], generic["min_moves"])


func test_different_disks_or_pegs_are_unsolvable_without_search() -> void:
	var rules: RuleSet = RuleSet.classic()
	var missing_disk: Dictionary = Solver.solve(PuzzleState.new([[3, 2, 1], [], []]), PuzzleState.new([[], [], [3, 2]]), rules)
	assert_false(missing_disk["solvable"])
	assert_eq(missing_disk["min_moves"], -1)
	assert_true(missing_disk["states_visited"] <= 1, "no search needed")
	assert_eq(missing_disk["strategy"], "none")
	var other_disk: Dictionary = Solver.solve(PuzzleState.new([[3, 2, 1], [], []]), PuzzleState.new([[], [], [4, 2, 1]]), rules)
	assert_false(other_disk["solvable"])
	var extra_peg: Dictionary = Solver.solve(PuzzleState.new([[2, 1], []]), PuzzleState.new([[], [2, 1], []]), rules)
	assert_false(extra_peg["solvable"])


func test_unreachable_goal_is_unsolvable() -> void:
	# An unsorted goal can never be reached under the classic rule.
	var result: Dictionary = Solver.solve(PuzzleState.new([[2, 1], [], []]), PuzzleState.new([[1, 2], [], []]), RuleSet.classic())
	assert_false(result["solvable"])
	assert_false(result["limit_reached"], "whole space explored")
	# A rule that blocks the goal peg entirely (fast path, both frontiers die out).
	var blocked: RuleSet = RuleSet.classic()
	blocked.active_rules.append(NoEvenDiskOnPegOneRule.new())
	var no_way: Dictionary = Solver.solve(_tower(3, 2, 0), _tower(3, 2, 1), blocked)
	assert_false(no_way["solvable"])
	assert_false(no_way["limit_reached"])


func test_unsorted_start_falls_back_to_generic_search() -> void:
	# [[1, 2]] breaks the classic order, so the packed search cannot represent it.
	var result: Dictionary = _solve_checked(PuzzleState.new([[1, 2], [], []]), PuzzleState.new([[], [], [2, 1]]), RuleSet.classic())
	assert_eq(result["min_moves"], 2)
	assert_eq(result["strategy"], "generic")


func test_max_states_limit() -> void:
	for rules: RuleSet in [RuleSet.classic(), _generic_classic()]:
		var result: Dictionary = Solver.solve(_tower(3, 10, 0), _tower(3, 10, 2), rules, 100)
		assert_false(result["solvable"])
		assert_true(result["limit_reached"])
		assert_eq(result["min_moves"], -1)
		assert_true(result["states_visited"] <= 100, "visited %d" % result["states_visited"])


func test_null_arguments() -> void:
	var state: PuzzleState = _tower(3, 3, 0)
	assert_false(Solver.solve(null, state, RuleSet.classic())["solvable"])
	assert_false(Solver.solve(state, null, RuleSet.classic())["solvable"])
	assert_false(Solver.solve(state, state, null)["solvable"])


func test_inputs_are_not_modified() -> void:
	var start: PuzzleState = PuzzleState.new([[5, 3, 1], [4], [2], []])
	var goal: PuzzleState = _tower(4, 5, 3)
	for rules: RuleSet in [RuleSet.classic(), _generic_classic()]:
		Solver.solve(start, goal, rules)
		assert_eq(start.to_array(), [[5, 3, 1], [4], [2], []])
		assert_eq(goal.to_array(), [[], [], [], [5, 4, 3, 2, 1]])


func test_result_is_deterministic() -> void:
	var start: PuzzleState = PuzzleState.new([[5, 3, 1], [4], [2], []])
	var goal: PuzzleState = _tower(4, 5, 3)
	var first: Array = _to_pairs(Solver.solve(start, goal, RuleSet.classic())["path"])
	var second: Array = _to_pairs(Solver.solve(start, goal, RuleSet.classic())["path"])
	assert_eq(first, second)


func test_result_has_typed_move_path() -> void:
	var result: Dictionary = Solver.solve(_tower(3, 2, 0), _tower(3, 2, 2), RuleSet.classic())
	var path: Array = result["path"]
	assert_true(path.is_typed() and path.get_typed_script() == Move, "path is Array[Move]")
	assert_eq(_to_pairs(result["path"]), [[0, 1], [0, 2], [1, 2]])


func _cross_check(fast: RuleSet, generic: RuleSet, count: int, seed: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	var unsolvable: int = 0
	for i: int in count:
		var pegs: int = rng.randi_range(3, 4)
		var disks: int = rng.randi_range(1, 5)
		var start: PuzzleState = _random_state(rng, pegs, disks)
		var goal: PuzzleState = _random_state(rng, pegs, disks)
		var a: Dictionary = Solver.solve(start, goal, fast)
		var b: Dictionary = Solver.solve(start, goal, generic)
		var label: String = "%s -> %s" % [start.hash_key(), goal.hash_key()]
		if not start.equals(goal):
			assert_eq(a["strategy"], "packed", "fast rules use the packed search " + label)
			assert_eq(b["strategy"], "generic", "opaque rules use the generic search " + label)
		assert_eq(a["solvable"], b["solvable"], "solvable " + label)
		assert_eq(a["min_moves"], b["min_moves"], "min_moves " + label)
		if a["solvable"]:
			assert_true(_path_reaches_goal(start, goal, a["path"], fast), "fast path " + label)
			assert_true(_path_reaches_goal(start, goal, b["path"], generic), "generic path " + label)
		else:
			unsolvable += 1
	print("    %d random puzzles compared (%d unsolvable)" % [count, unsolvable])


## Solves and checks that the returned path is legal and ends at the goal.
func _solve_checked(start: PuzzleState, goal: PuzzleState, rules: RuleSet) -> Dictionary:
	var result: Dictionary = Solver.solve(start, goal, rules)
	assert_true(result["solvable"], "solvable: %s -> %s" % [start.hash_key(), goal.hash_key()])
	assert_eq(result["path"].size(), result["min_moves"], "path length")
	assert_true(_path_reaches_goal(start, goal, result["path"], rules), "path valid: %s -> %s" % [start.hash_key(), goal.hash_key()])
	return result


static func _path_reaches_goal(start: PuzzleState, goal: PuzzleState, path: Array, rules: RuleSet) -> bool:
	var state: PuzzleState = start
	for move: Move in path:
		state = rules.apply_move(state, move)
		if state == null:
			return false
	return state.equals(goal)


static func _generic_classic() -> RuleSet:
	var rules: Array[RuleBase] = [OpaqueClassicRule.new()]
	return RuleSet.new(rules)


static func _tower(peg_count: int, disk_count: int, on_peg: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	for size: int in range(disk_count, 0, -1):
		layout[on_peg].append(size)
	return PuzzleState.new(layout)


static func _random_state(rng: RandomNumberGenerator, peg_count: int, disk_count: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	for size: int in range(disk_count, 0, -1):
		layout[rng.randi_range(0, peg_count - 1)].append(size)
	return PuzzleState.new(layout)


static func _to_pairs(moves: Array) -> Array:
	var pairs: Array = []
	for move: Move in moves:
		pairs.append(move.to_array())
	return pairs
