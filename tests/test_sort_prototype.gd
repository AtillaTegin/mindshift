extends "res://tests/test_case.gd"
## Colour-order prototype (res://prototype/sort_pattern/): equal-sized coloured
## disks with their own identities, a target read by colour, and a move budget
## with a win and a loss. Kept apart from the Hanoi engine.

const BOARD_SCENE: PackedScene = preload("res://prototype/sort_pattern/sort_board.tscn")
const MENU_SCENE: PackedScene = preload("res://prototype/sort_pattern/sort_menu.tscn")
const MENU_SCRIPT: GDScript = preload("res://prototype/sort_pattern/sort_menu.gd")

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()
	SortSession.limit_override = 0


func _add(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_nodes.append(node)
	return node


func _level() -> SortPuzzle:
	var errors: Array[String] = []
	var puzzle: SortPuzzle = SortPuzzle.load_file(SortPuzzle.LEVEL_PATH, errors)
	assert_eq(errors, [] as Array[String])
	return puzzle


## Two small pegs-worth of disks: ids 0 and 1 are both large and red, 2 is a small blue.
func _twin_puzzle() -> SortPuzzle:
	var errors: Array[String] = []
	return SortPuzzle.from_dict({"disks": [{"size": 2, "color": "red"}, {"size": 2, "color": "red"},
			{"size": 1, "color": "blue"}], "start": [[0, 2], [1], []], "target_peg": 2,
			"target": ["red", "red", "blue"], "move_limit": 9}, errors)


func _board() -> Control:
	var board: Control = BOARD_SCENE.instantiate()
	board.result_delay = 0.0
	return _add(board)


func test_level_file_is_a_valid_solvable_puzzle() -> void:
	var puzzle: SortPuzzle = _level()
	assert_eq(SortSolver.validate(puzzle), [] as Array[String])
	assert_eq(puzzle.peg_count(), 3)
	assert_eq(puzzle.disk_count(), 6)
	assert_eq(SortSolver.solve(puzzle, puzzle.start)["path"].size(), puzzle.min_moves, "min_moves is the shortest")
	assert_eq(puzzle.move_limit, puzzle.min_moves + 2, "first tests run with M = S + 2")
	var equal_pairs: int = 0
	for a: int in puzzle.disk_count():
		assert_true(SortPuzzle.COLORS.has(puzzle.colors[a]))
		for b: int in range(a + 1, puzzle.disk_count()):
			if puzzle.sizes[a] == puzzle.sizes[b] and puzzle.colors[a] != puzzle.colors[b]:
				equal_pairs += 1
	assert_true(equal_pairs > 0, "some disks share a size but not a colour")
	var red_sizes: Array[int] = []
	for id: int in puzzle.disk_count():
		if puzzle.colors[id] == "red" and not red_sizes.has(puzzle.sizes[id]):
			red_sizes.append(puzzle.sizes[id])
	assert_true(red_sizes.size() > 1, "a colour does not fix a size")


func test_equal_sizes_stack_but_larger_on_smaller_is_refused() -> void:
	var puzzle: SortPuzzle = _level()
	var pegs: Array[Array] = [[0], [1, 2], [5]]
	assert_true(puzzle.can_move(pegs, Move.new(1, 0)), "medium onto large")
	var stacked: Array[Array] = SortPuzzle.apply(pegs, Move.new(1, 0))
	assert_eq(stacked[0], [0, 2], "only the top disk moved")
	assert_true(puzzle.can_move(stacked, Move.new(1, 0)), "medium onto an equal medium")
	assert_false(puzzle.can_move(pegs, Move.new(1, 2)), "medium onto small")
	assert_false(puzzle.can_move(pegs, Move.new(0, 0)), "same peg")
	assert_false(puzzle.can_move([[], [1], []] as Array[Array], Move.new(0, 1)), "empty source")
	assert_true(puzzle.can_move(pegs, Move.new(2, 1)), "small onto medium")


func test_target_is_read_by_colour_not_by_identity() -> void:
	var puzzle: SortPuzzle = _twin_puzzle()
	assert_not_null(puzzle)
	assert_true(puzzle.is_goal([[], [], [0, 1, 2]] as Array[Array]))
	assert_true(puzzle.is_goal([[], [], [1, 0, 2]] as Array[Array]), "the two red disks are interchangeable")
	assert_false(puzzle.is_goal([[2], [], [0, 1]] as Array[Array]), "every disk must be on the target peg")
	assert_eq(puzzle.matched_count([[2], [], [1, 0]] as Array[Array]), 2)
	assert_eq(puzzle.key([[0], [1], [2]] as Array[Array]), puzzle.key([[1], [0], [2]] as Array[Array]))
	# Either red may go first: 1>2, 0>1, 0>2, 1>2.
	assert_eq(SortSolver.solve(puzzle, puzzle.start)["path"].size(), 4)


func test_validator_rejects_broken_levels() -> void:
	var puzzle: SortPuzzle = _level()
	puzzle.move_limit = puzzle.min_moves - 1
	assert_true(" ".join(SortSolver.validate(puzzle)).contains("move_limit"))
	puzzle = _level()
	puzzle.target_colors = ["red", "green", "red", "yellow", "blue", "blue"] as Array[String]
	assert_true(" ".join(SortSolver.validate(puzzle)).contains("cannot be reached"), "the large blue disk can only be the bottom one")
	puzzle = _level()
	puzzle.target_colors[0] = "green"
	assert_true(" ".join(SortSolver.validate(puzzle)).contains("every disk's colour"))
	puzzle = _level()
	puzzle.solution.pop_back()
	assert_false(SortSolver.validate(puzzle).is_empty(), "a solution that falls short")
	puzzle = _level()
	puzzle.start = [[5, 0], [1, 2, 3, 4], []] as Array[Array]
	assert_true(" ".join(SortSolver.validate(puzzle)).contains("larger disk on a smaller"))


func test_only_successful_transfers_use_moves() -> void:
	var session: SortSession = SortSession.new(_level())
	var limit: int = session.move_limit
	assert_eq(session.tap_peg(2), SortSession.TapResult.IGNORED, "empty peg")
	assert_eq(session.tap_peg(0), SortSession.TapResult.SELECTED)
	assert_eq(session.tap_peg(0), SortSession.TapResult.DESELECTED)
	assert_eq(session.tap_peg(0), SortSession.TapResult.SELECTED)
	assert_eq(session.tap_peg(1), SortSession.TapResult.ILLEGAL, "medium green onto small red")
	assert_eq(session.selected_peg, 0, "a refused move keeps the selection")
	assert_eq(session.moves_made, 0)
	assert_eq(session.remaining(), limit)
	assert_eq(session.tap_peg(2), SortSession.TapResult.MOVED)
	assert_eq(session.moves_made, 1)
	assert_eq(session.remaining(), limit - 1)
	assert_eq(session.pegs[2], [3], "the green disk itself moved")


func test_solution_wins_even_on_the_very_last_move() -> void:
	var puzzle: SortPuzzle = _level()
	var session: SortSession = SortSession.new(puzzle, puzzle.min_moves)
	for i: int in puzzle.solution.size():
		assert_eq(session.status, SortSession.Status.PLAYING, "move %d" % i)
		assert_true(session.try_move(puzzle.solution[i]))
	assert_eq(session.remaining(), 0)
	assert_eq(session.status, SortSession.Status.WON, "reaching the target with R = 0 is a win")
	assert_eq(session.tap_peg(0), SortSession.TapResult.IGNORED, "nothing moves after the end")


func test_running_out_of_moves_loses() -> void:
	var session: SortSession = SortSession.new(_level(), 4)
	for i: int in 4:
		assert_eq(session.status, SortSession.Status.PLAYING)
		assert_true(session.try_move(Move.new(1, 2) if i % 2 == 0 else Move.new(2, 1)))
	assert_eq(session.remaining(), 0)
	assert_eq(session.status, SortSession.Status.LOST)
	assert_false(session.try_move(Move.new(1, 2)), "no moves after a loss")
	assert_eq(session.moves_made, 4)


func test_restart_resets_the_whole_puzzle() -> void:
	var puzzle: SortPuzzle = _level()
	var session: SortSession = SortSession.new(puzzle, 2)
	session.try_move(Move.new(0, 2))
	session.try_move(Move.new(0, 2))
	session.tap_peg(1)
	assert_eq(session.status, SortSession.Status.LOST)
	session.restart()
	assert_eq(session.pegs, puzzle.start)
	assert_eq(session.moves_made, 0)
	assert_eq(session.remaining(), 2)
	assert_eq(session.selected_peg, -1)
	assert_eq(session.status, SortSession.Status.PLAYING)
	session.pegs[0].clear()
	assert_eq(puzzle.start[0].size(), 3, "the session never changes the level's start")


func test_board_plays_to_a_win() -> void:
	var board: Control = _board()
	var puzzle: SortPuzzle = board.puzzle
	assert_eq(board.get_node("%DiskLayer").get_child_count(), 6)
	assert_eq(board.get_moves_left_text(), SortTexts.text("BOARD_MOVES_LEFT") % puzzle.move_limit)
	var views: Dictionary = {}
	for id: int in puzzle.disk_count():
		views[id] = board.get_disk_view(id)
		assert_eq(board.get_disk_view(id).color, SortPalette.fill(puzzle.colors[id]))
	board.on_peg_pressed(0)
	board.on_peg_pressed(1)
	assert_eq(board.get_status_text(), SortTexts.text("BOARD_ILLEGAL"), "illegal move explained")
	assert_eq(board.session.moves_made, 0)
	board.on_peg_pressed(0)
	for move: Move in puzzle.solution:
		assert_false(board.is_result_visible())
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)
	assert_eq(board.session.status, SortSession.Status.WON)
	assert_true(board.is_result_visible())
	assert_eq(board.get_result_title(), SortTexts.text("RESULT_WIN_TITLE"))
	for id: int in puzzle.disk_count():
		var view: SortDiskView = board.get_disk_view(id)
		assert_true(view == views[id], "disk %d keeps its own view" % id)
		assert_eq(view.color_name, puzzle.colors[id], "and its colour")
		assert_eq(view.disk_size, puzzle.sizes[id], "and its size")
		assert_true(view.matched, "disk %d is marked in place" % id)


func test_board_loses_and_retry_resets() -> void:
	SortSession.limit_override = 3
	var board: Control = _board()
	assert_eq(board.session.move_limit, 3, "the menu's limit is used")
	for move: Array in [[0, 2], [2, 0], [0, 2]]:
		board.on_peg_pressed(move[0])
		board.on_peg_pressed(move[1])
	assert_eq(board.session.status, SortSession.Status.LOST)
	assert_true(board.is_result_visible())
	assert_eq(board.get_result_title(), SortTexts.text("RESULT_LOSE_TITLE"))
	board.restart()
	assert_false(board.is_result_visible())
	assert_eq(board.session.pegs, board.puzzle.start)
	assert_eq(board.session.remaining(), 3)
	assert_eq(board.get_status_text(), "")
	for id: int in board.puzzle.disk_count():
		assert_false(board.get_disk_view(id).matched)


func test_progress_shows_on_the_board_and_the_pattern() -> void:
	var board: Control = _board()
	var pattern: SortPatternView = board.get_node("%PatternView")
	assert_eq(pattern.target_colors, board.puzzle.target_colors)
	# Green first onto the empty target peg: it is not the blue base.
	board.on_peg_pressed(0)
	board.on_peg_pressed(2)
	assert_eq(pattern.matched, 0)
	assert_eq(pattern.occupied, 1)
	assert_eq(board.get_status_text(), SortTexts.text("BOARD_WRONG_PLACE"))
	for move: Move in board.puzzle.solution.slice(1, 7):
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)
	assert_eq(pattern.matched, 1, "the large blue base is in place")
	assert_eq(board.get_status_text(), SortTexts.text("BOARD_PROGRESS_UP") % [1, 6])
	assert_true(board.get_disk_view(0).matched)


func test_menu_changes_the_limit_within_bounds() -> void:
	var menu: Control = _add(MENU_SCENE.instantiate())
	var puzzle: SortPuzzle = menu.puzzle
	assert_eq(menu.current_limit(), puzzle.move_limit)
	menu.change_limit(1)
	assert_eq(SortSession.limit_override, puzzle.move_limit + 1)
	for i: int in 40:
		menu.change_limit(-1)
	assert_eq(menu.current_limit(), puzzle.min_moves, "never below the shortest solution")
	assert_true((menu.get_node("%MinusButton") as Button).disabled)
	for i: int in 40:
		menu.change_limit(1)
	assert_eq(menu.current_limit(), puzzle.min_moves + MENU_SCRIPT.MAX_SLACK)
	menu.change_limit(puzzle.move_limit - menu.current_limit())
	assert_eq(SortSession.limit_override, 0, "the level's own limit again")
