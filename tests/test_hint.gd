extends "res://tests/test_case.gd"
## Hints (spec 4.7). Day 6 acceptance: the hint gives a correct next move both
## on the optimal path and after the player has left it.

## Levels checked in every tier (1-based positions).
const SAMPLE_INDEXES: Array[int] = [1, 25, 50]


func _sample_levels() -> Array[Level]:
	var levels: Array[Level] = []
	for tier: String in Difficulty.ORDER:
		for index: int in SAMPLE_INDEXES:
			levels.append(LevelCatalog.load_level(tier, index))
	return levels


## Moves left in a shortest solution from `state`.
static func _distance(state: PuzzleState, session: GameSession) -> int:
	return Solver.solve(state, session.level.goal, session.rules, GameSession.HINT_MAX_STATES)["min_moves"]


func test_hint_follows_solution_path_on_the_optimal_path() -> void:
	for level: Level in _sample_levels():
		var session: GameSession = GameSession.new(level)
		for k: int in level.solution_path.size():
			var hint: Dictionary = session.get_hint()
			assert_true(hint["from_path"], "level %d step %d read from the path" % [level.id, k])
			assert_true((hint["move"] as Move).equals(level.solution_path[k]), "level %d step %d" % [level.id, k])
			session.try_move(hint["move"])
		assert_true(session.is_solved(), "level %d solved by following hints" % level.id)
		assert_null(session.get_hint()["move"], "no hint once solved")


func test_hint_is_optimal_after_leaving_the_path() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6
	var slowest_ms: int = 0
	for level: Level in _sample_levels():
		var session: GameSession = GameSession.new(level)
		# Leave the path: a legal first move that is not the optimal one, then a
		# few random legal moves.
		var detour: Array[Move] = []
		for move: Move in session.rules.get_legal_moves(session.state):
			if not move.equals(level.solution_path[0]):
				detour.append(move)
		session.try_move(detour[rng.randi_range(0, detour.size() - 1)])
		for i: int in rng.randi_range(0, 3):
			var legal: Array[Move] = session.rules.get_legal_moves(session.state)
			session.try_move(legal[rng.randi_range(0, legal.size() - 1)])
		if session.is_solved():
			continue
		var distance: int = _distance(session.state, session)
		var moves_before: int = session.move_count
		# Every hint must bring the goal exactly one move closer.
		while not session.is_solved():
			var started_ms: int = Time.get_ticks_msec()
			var hint: Dictionary = session.get_hint()
			slowest_ms = maxi(slowest_ms, Time.get_ticks_msec() - started_ms)
			var move: Move = hint["move"]
			assert_not_null(move, "level %d has a hint" % level.id)
			if move == null:
				break
			var remaining: int = _distance(session.state, session)
			assert_true(session.try_move(move), "level %d hint %s is legal" % [level.id, str(move)])
			assert_eq(_distance(session.state, session), remaining - 1, "level %d hint %s is optimal" % [level.id, str(move)])
		assert_eq(session.move_count - moves_before, distance, "level %d finished in the minimum from the detour" % level.id)
	print("    slowest hint: %d ms" % slowest_ms)


func test_hint_after_detour_and_return_reads_the_path_again() -> void:
	var level: Level = LevelCatalog.load_level("medium", 10)
	var session: GameSession = GameSession.new(level)
	var first: Move = level.solution_path[0]
	session.try_move(first)
	session.try_move(Move.new(first.to_peg, first.from_peg))
	var hint: Dictionary = session.get_hint()
	assert_true(hint["from_path"], "back at the start position")
	assert_true((hint["move"] as Move).equals(first))


func test_undo_restores_position_and_count() -> void:
	var level: Level = LevelCatalog.load_level("easy", 20)
	var session: GameSession = GameSession.new(level)
	assert_false(session.can_undo())
	assert_false(session.undo())
	session.try_move(level.solution_path[0])
	session.try_move(level.solution_path[1])
	var after_one: PuzzleState = GameSession.new(level).state
	after_one = session.rules.apply_move(after_one, level.solution_path[0])
	assert_true(session.undo())
	assert_true(session.state.equals(after_one))
	assert_eq(session.move_count, 1)
	assert_eq(session.undo_count, 1)
	assert_eq(session.history.size(), 1)
	assert_true(session.undo())
	assert_true(session.state.equals(level.start))
	assert_eq(session.move_count, 0)
	assert_false(session.undo())
	session.restart()
	assert_eq(session.undo_count, 0, "the per-attempt count restarts (free undos are daily, see test_economy)")


func test_no_undo_after_solving() -> void:
	var level: Level = LevelCatalog.load_level("easy", 1)
	var session: GameSession = GameSession.new(level)
	for move: Move in level.solution_path:
		session.try_move(move)
	assert_false(session.can_undo())
	assert_false(session.undo())
