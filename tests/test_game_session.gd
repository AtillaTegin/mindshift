extends "res://tests/test_case.gd"
## GameSession: tap handling, move counting, solving.


func _session() -> GameSession:
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[], [], [3, 2, 1]])
	var rule_ids: Array[String] = ["classic_hanoi"]
	return GameSession.new(Level.create(1001, "easy", start, goal, rule_ids, Solver.solve(start, goal, RuleSet.classic())["path"]))


func test_tap_selects_then_moves() -> void:
	var session: GameSession = _session()
	assert_eq(session.tap_peg(0), GameSession.TapResult.SELECTED)
	assert_eq(session.selected_peg, 0)
	assert_eq(session.get_selected_disk(), 1)
	assert_eq(session.tap_peg(2), GameSession.TapResult.MOVED)
	assert_eq(session.state.to_array(), [[3, 2], [], [1]])
	assert_eq(session.move_count, 1)
	assert_eq(session.selected_peg, -1, "selection cleared after a move")


func test_tap_same_peg_deselects_without_counting() -> void:
	var session: GameSession = _session()
	session.tap_peg(0)
	assert_eq(session.tap_peg(0), GameSession.TapResult.DESELECTED)
	assert_eq(session.selected_peg, -1)
	assert_eq(session.move_count, 0)


func test_tap_empty_peg_without_selection_is_ignored() -> void:
	var session: GameSession = _session()
	assert_eq(session.tap_peg(1), GameSession.TapResult.IGNORED)
	assert_eq(session.tap_peg(-1), GameSession.TapResult.IGNORED)
	assert_eq(session.tap_peg(3), GameSession.TapResult.IGNORED)
	assert_eq(session.selected_peg, -1)


func test_illegal_move_keeps_selection_and_count() -> void:
	var session: GameSession = _session()
	session.tap_peg(0)
	session.tap_peg(2)  # disk 1 -> peg 2
	session.tap_peg(0)  # pick up disk 2
	assert_eq(session.tap_peg(2), GameSession.TapResult.ILLEGAL, "2 onto 1")
	assert_eq(session.move_count, 1)
	assert_eq(session.selected_peg, 0, "player can choose another target")
	assert_eq(session.state.to_array(), [[3, 2], [], [1]])
	assert_eq(session.tap_peg(1), GameSession.TapResult.MOVED)


func test_solution_path_solves_and_counts_moves() -> void:
	var session: GameSession = _session()
	for move: Move in session.level.solution_path:
		assert_false(session.is_solved())
		session.tap_peg(move.from_peg)
		assert_eq(session.tap_peg(move.to_peg), GameSession.TapResult.MOVED, str(move))
	assert_true(session.is_solved())
	assert_eq(session.move_count, 7)
	assert_eq(session.history.size(), 7)
	assert_eq(session.tap_peg(2), GameSession.TapResult.IGNORED, "no play after solving")


func test_detour_counts_every_move() -> void:
	var session: GameSession = _session()
	session.tap_peg(0)
	session.tap_peg(1)
	session.tap_peg(1)
	session.tap_peg(0)
	assert_eq(session.move_count, 2)
	assert_eq(session.state.to_array(), [[3, 2, 1], [], []])


func test_restart_and_time() -> void:
	var session: GameSession = _session()
	session.tap_peg(0)
	session.tap_peg(2)
	session.add_time(1.5)
	assert_eq(session.elapsed_seconds, 1.5)
	session.restart()
	assert_eq(session.move_count, 0)
	assert_eq(session.elapsed_seconds, 0.0)
	assert_true(session.history.is_empty())
	assert_true(session.state.equals(session.level.start))
	assert_false(session.state == session.level.start, "restart copies the start position")


func test_time_stops_when_solved() -> void:
	var session: GameSession = _session()
	for move: Move in session.level.solution_path:
		session.try_move(move)
	session.add_time(3.0)
	assert_eq(session.elapsed_seconds, 0.0)
