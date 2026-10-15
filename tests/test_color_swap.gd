extends "res://tests/test_case.gd"
## "Böyük Mübadilə" v2 (great exchange addendum 2026-10-13 and the user's
## decision on its two kinds): white and black disks, one of each size per
## colour, on the two end pegs. "Təmiz Dəyişmə" (pure) swaps the two stacks
## under the size rule; "Qarışıq-Ayırma" (mixed) sorts mixed ends under the
## size rule plus "colours never touch". A chapter of 30-40 levels on the main
## road (the old rare bosses are gone), and a refused move always says why.

const SAVE_PATH: String = "res://.test_saves/test_color_swap_save.json"
const MAIN: String = LevelCatalog.MAIN
const SELECT_SCENE: PackedScene = preload("res://scenes/level_select.tscn")

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _add(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_nodes.append(node)
	return node


func _rules(colour: bool) -> RuleSet:
	return RuleSet.from_ids([ColorSwapRule.ID], {ColorSwapRule.ID: {"colour": colour}})


## The great exchange levels with their main path positions, in road order.
func _on_road() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == ColorSwapRule.ID:
			found.append({"position": position, "level": LevelCatalog.load_at(MAIN, position)})
	return found


func _board_for(level: Level) -> GameBoard:
	var board: GameBoard = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	board.save_system = SaveSystem.new(SAVE_PATH)
	board.tutorials_enabled = false
	board.background_hints = false
	_add(board)
	board.start_level(level)
	(board.get_node("%Board") as Control).size = Vector2(672.0, 700.0)
	return board


func test_ids_carry_size_and_colour() -> void:
	assert_eq(ColorSwapRule.disk_of(3, true), 5)
	assert_eq(ColorSwapRule.disk_of(3, false), 6)
	for size: int in range(1, 6):
		for white: bool in [true, false]:
			var disk: int = ColorSwapRule.disk_of(size, white)
			assert_eq(ColorSwapRule.size_of(disk), size)
			assert_eq(ColorSwapRule.is_white(disk), white)
	var errors: Array[String] = []
	assert_null(RuleSet.from_ids([ColorSwapRule.ID], {}, errors), "the kind must be given")
	assert_null(RuleSet.from_ids([ColorSwapRule.ID], {ColorSwapRule.ID: {"colour": 1}}, errors))


func test_size_rule_for_both_kinds() -> void:
	for colour: bool in [false, true]:
		var rules: RuleSet = _rules(colour)
		# White 2 (id 3) on the left, black 1 (id 2) and black 3 (id 6) elsewhere.
		var state: PuzzleState = PuzzleState.new([[3], [2], [6], [4], []])
		assert_false(rules.is_move_legal(state, Move.new(0, 1)), "larger onto smaller")
		assert_eq(rules.get_violation_message(state, Move.new(0, 1)), "RULE_CLASSIC_HANOI")
		assert_false(rules.is_move_legal(state, Move.new(0, 3)), "never onto its own size")
		assert_eq(rules.get_violation_message(state, Move.new(0, 3)), "RULE_SAME_SIZE")
		assert_true(rules.is_move_legal(state, Move.new(0, 4)), "an empty peg takes anything")
		assert_true(rules.is_state_valid(PuzzleState.new([[6, 3, 2], [], [], [5, 4, 1]])), "mixed stacks may start")
		assert_false(rules.is_state_valid(PuzzleState.new([[3, 4], [], [], []])), "equal sizes never stack")
		assert_true(Solver._can_pack(PuzzleState.new([[6, 3, 2], [], [], [5, 4, 1]]), PuzzleState.new([[6, 4, 2], [], [], [5, 3, 1]]), rules),
				"the Solver keeps its fast path")


func test_colour_rule_only_for_the_mixed_kind() -> void:
	# White 1 (id 1) onto black 3 (id 6): the size fits, the colour does not.
	var state: PuzzleState = PuzzleState.new([[1], [6], [5], []])
	assert_true(_rules(false).is_move_legal(state, Move.new(0, 1)), "pure: colour does not limit moves")
	assert_false(_rules(true).is_move_legal(state, Move.new(0, 1)), "mixed: colours never touch")
	assert_eq(_rules(true).get_violation_message(state, Move.new(0, 1)), "RULE_COLOUR_TOUCH")
	assert_true(_rules(true).is_move_legal(state, Move.new(0, 2)), "white onto a larger white")


func test_chapter_is_dense_and_mixes_both_kinds() -> void:
	var road: Array[Dictionary] = _on_road()
	assert_true(road.size() >= 30 and road.size() <= 40, "30-40 levels, no longer rare bosses (%d)" % road.size())
	assert_eq(road[0]["position"], PathBuilder.CHAPTER_STARTS[ColorSwapRule.ID], "starts at the first boss's old slot")
	assert_eq((road[0]["level"] as Level).lesson(), ColorSwapRule.ID, "the pure swap comes first")
	assert_true(road[-1]["position"] > PathBuilder.MIX_UNTIL, "to the end of the road (%d)" % road[-1]["position"])
	var kinds: Dictionary = {}
	var first_mixed: int = 0
	var previous: int = 0
	for entry: Dictionary in road:
		var level: Level = entry["level"]
		var position: int = entry["position"]
		kinds[level.lesson()] = kinds.get(level.lesson(), 0) + 1
		if first_mixed == 0 and level.lesson() == Level.COLOR_SWAP_MIXED:
			first_mixed = position
		assert_true(level.min_moves >= previous, "easiest first (main %d)" % position)
		previous = level.min_moves
		assert_true(level.min_moves <= 33, "on the main road")
		assert_eq(level.difficulty, Difficulty.tier_for_moves(level.min_moves), "tier by length")
		if level.difficulty == "easy":
			assert_true(position <= PathBuilder.EASY_UNTIL, "easy only while learning (%d)" % position)
		var errors: Array[String] = []
		LevelValidator.validate_mechanic_design(level, errors)
		assert_eq(errors, [] as Array[String], "main %d" % position)
	assert_true(kinds.get(ColorSwapRule.ID, 0) >= 5, "pure swaps: %s" % str(kinds))
	assert_true(kinds.get(Level.COLOR_SWAP_MIXED, 0) >= 5, "mixed ones: %s" % str(kinds))
	assert_true(first_mixed > 0 and first_mixed <= PathBuilder.EASY_UNTIL, "the colour rule is met while learning (%d)" % first_mixed)


func test_validator_knows_the_board() -> void:
	var start: PuzzleState = PuzzleState.new([[5, 3, 1], [], [], [6, 4, 2]])
	var goal: PuzzleState = PuzzleState.new([[6, 4, 2], [], [], [5, 3, 1]])
	var path: Array[Move] = Solver.solve(start, goal, _rules(false))["path"]
	var rule_ids: Array[String] = [ColorSwapRule.ID]
	var pure: Level = Level.create(9900, "medium", start, goal, rule_ids, path, {ColorSwapRule.ID: {"colour": false}})
	var errors: Array[String] = []
	LevelValidator.validate_mechanic_design(pure, errors)
	assert_eq(errors, [] as Array[String])
	# The same board as a mixed level: both ends are of one colour.
	var not_mixed: Level = Level.create(9900, "medium", start, goal, rule_ids, path, {ColorSwapRule.ID: {"colour": true}})
	LevelValidator.validate_mechanic_design(not_mixed, errors)
	assert_true(" ".join(errors).contains("mixed"), str(errors))
	errors.clear()
	var wrong_goal: Level = Level.create(9900, "medium", start, PuzzleState.new([[], [], [], [6, 5, 4, 3, 2, 1]]), rule_ids, [],
			{ColorSwapRule.ID: {"colour": false}})
	LevelValidator.validate_mechanic_design(wrong_goal, errors)
	assert_true(" ".join(errors).contains("black disk on the left"), str(errors))
	errors.clear()
	var no_buffers: Level = Level.create(9900, "easy", PuzzleState.new([[3, 1], [4, 2]]), PuzzleState.new([[4, 2], [3, 1]]),
			rule_ids, [], {ColorSwapRule.ID: {"colour": false}})
	LevelValidator.validate_mechanic_design(no_buffers, errors)
	assert_true(" ".join(errors).contains("empty pegs between"), str(errors))


func test_each_kind_is_introduced_once() -> void:
	var pure: int = LevelCatalog.first_main_position(ColorSwapRule.ID)
	var mixed: int = LevelCatalog.first_main_position(Level.COLOR_SWAP_MIXED)
	assert_true(pure > 0 and mixed > pure, "pure %d, then mixed %d" % [pure, mixed])
	assert_true(TutorialDirector.is_mechanic_intro(LevelCatalog.load_at(MAIN, pure)))
	assert_true(TutorialDirector.is_mechanic_intro(LevelCatalog.load_at(MAIN, mixed)))
	for entry: Dictionary in _on_road():
		if entry["position"] != pure and entry["position"] != mixed:
			assert_false(TutorialDirector.is_mechanic_intro(entry["level"]), "main %d" % entry["position"])
	assert_true(TutorialDirector.INTRO_TEXTS.has(Level.COLOR_SWAP_MIXED))


func test_board_shows_sizes_and_two_colours() -> void:
	var road: Array[Dictionary] = _on_road()
	var level: Level = null
	for entry: Dictionary in road:
		if (entry["level"] as Level).get_peg_count() == Difficulty.MECHANIC_SIZES[Difficulty.COLOR_SWAP]["max_pegs"]:
			level = entry["level"]
			break
	assert_not_null(level, "a board with 4 buffers")
	var board: GameBoard = _board_for(level)
	var white: Dictionary = ThemeManager.EXCHANGE_DISKS["white"]
	var black: Dictionary = ThemeManager.EXCHANGE_DISKS["black"]
	var widths: Dictionary = {}
	for view: DiskView in board.get_node("%DiskLayer").get_children():
		var size: int = ColorSwapRule.size_of(view.disk_size)
		var is_white: bool = ColorSwapRule.is_white(view.disk_size)
		assert_eq(view.color, white["fill"] if is_white else black["fill"], "disk %d" % view.disk_size)
		assert_eq(view.label, size, "it shows its size, not its id")
		var width: float = snappedf(board.get_disk_rect(view.disk_size).size.x, 0.1)
		if widths.has(size):
			assert_eq(widths[size], width, "the two disks of a size are equally wide")
		widths[size] = width
	for size: int in range(2, widths.size() + 1):
		assert_true(widths[size] > widths[size - 1], "larger is wider")
	var rows: Dictionary = {}
	for peg: PegView in board.get_node("%PegLayer").get_children():
		rows[peg.position.y] = true
	assert_eq(rows.size(), 1, "the two ends stay on one row")
	assert_eq(board.get_board_skin().skin, "caravan")
	var preview: BoardPreview = board.get_node("%GoalPreview")
	assert_eq(preview.disk_palette.size(), level.get_disk_count(), "the goal shows the same disks")
	# The goal is told by the rule panel under the board (mode labels v1).
	var mixed: bool = level.lesson() == Level.COLOR_SWAP_MIXED
	assert_eq((board.get_node("%RuleName") as Label).text, tr("MODE_SWAP_MIXED_NAME" if mixed else "MODE_SWAP_NAME"))
	assert_eq((board.get_node("%RuleText") as Label).text, tr("MODE_SWAP_MIXED_RULE" if mixed else "MODE_SWAP_RULE"))
	for move: Move in level.solution_path:
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)
	assert_true(board.session.is_solved())
	assert_eq(board.last_result["stars"], 3, "stars like any level")


func test_a_refused_move_says_why() -> void:
	var level: Level = null
	for entry: Dictionary in _on_road():
		if (entry["level"] as Level).lesson() == Level.COLOR_SWAP_MIXED:
			level = entry["level"]
			break
	var board: GameBoard = _board_for(level)
	var status: Label = board.get_node("%StatusLabel")
	var last: int = level.get_peg_count() - 1
	var heard: Array[String] = []
	board.illegal_move.connect(func(_move: Move, message: String) -> void: heard.append(message))
	# The top of the left end onto the top of the right end: same size, refused.
	board.on_peg_pressed(0)
	board.on_peg_pressed(last)
	assert_eq(status.text, tr("RULE_SAME_SIZE"), "never a silent refusal")
	assert_eq(status.theme_type_variation, &"SecondaryLabel", "said calmly, nothing is punished")
	assert_eq(heard, [tr("RULE_SAME_SIZE")] as Array[String])
	# The disk stays picked up: put it aside, then try a larger one onto it.
	board.on_peg_pressed(1)
	assert_eq(board.session.move_count, 1)
	board.on_peg_pressed(0)
	board.on_peg_pressed(1)
	assert_eq(status.text, tr("RULE_CLASSIC_HANOI"))


func test_dead_end_gets_an_honest_hint() -> void:
	# A mixed level: a disk lifted off the other colour cannot go back.
	var level: Level = null
	for entry: Dictionary in _on_road():
		if (entry["level"] as Level).lesson() == Level.COLOR_SWAP_MIXED:
			level = entry["level"]
			break
	var session: GameSession = GameSession.new(level)
	var off: Move = null
	for move: Move in session.rules.get_legal_moves(session.state):
		if not move.equals(level.solution_path[0]):
			off = move
			break
	session.try_move(off)
	var back: Move = session.return_to_path_move()
	if back != null:
		assert_true(session.rules.apply_move(session.state, back).equals(level.start), "a way back is a real one")
	assert_not_null(GameSession.solve_hint(level, session.state.duplicate_state(), session.rules), "the Solver still finds a way")


func test_map_shows_the_chapter_as_ordinary_stops() -> void:
	var save: SaveSystem = SaveSystem.new(SAVE_PATH)
	var first: int = LevelCatalog.first_main_position(ColorSwapRule.ID)
	for position: int in range(1, first):
		save.completed_levels[str(LevelCatalog.level_id_at(MAIN, position))] = {"stars": 1, "best_moves": 99, "best_time_seconds": 9}
	var screen: Control = SELECT_SCENE.instantiate()
	screen.save_system = save
	_add(screen)
	var stop: LevelCell = screen.get_cell(first)
	var plain: LevelCell = screen.get_cell(first - 1)
	assert_eq(stop.size, plain.size, "no larger boss stop any more")
	assert_eq(stop.skin, "caravan")
