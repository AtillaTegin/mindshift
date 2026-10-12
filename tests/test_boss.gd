extends "res://tests/test_case.gd"
## "Böyük Mübadilə" bosses (caravan road addendum, section 2; Hanoi variant E):
## two stacks on the end pegs of a 4-peg board swap places. Rare, rising in
## difficulty, two caravan colours, a word of explanation and a larger stop.

const SAVE_PATH: String = "res://.test_saves/test_boss_save.json"
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


func _boss_positions() -> Array[int]:
	var positions: Array[int] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == Level.GREAT_EXCHANGE:
			positions.append(position)
	return positions


func test_bosses_are_rare_and_get_harder() -> void:
	var positions: Array[int] = _boss_positions()
	assert_true(positions.size() >= 5 and positions.size() <= 8, "%d bosses" % positions.size())
	for i: int in range(1, positions.size()):
		var gap: int = positions[i] - positions[i - 1]
		assert_true(gap >= 35 and gap <= 50, "one every ~40-50 levels (%d)" % gap)
	var previous: int = 0
	var caravan_rules: int = 0
	for position: int in positions:
		var level: Level = LevelCatalog.load_at(MAIN, position)
		assert_eq(level.boss, Level.GREAT_EXCHANGE)
		assert_true(LevelValidator.is_great_exchange(level.start, level.goal), "main %d is a swap" % position)
		assert_true(level.min_moves > previous, "each boss harder than the last (%d)" % position)
		assert_true(level.min_moves <= 33, "on the main road")
		previous = level.min_moves
		if level.rule_ids.has(AdjacentPegsRule.ID):
			caravan_rules += 1
		var errors: Array[String] = []
		LevelValidator.validate_level(level, errors)
		LevelValidator.validate_mechanic_design(level, errors)
		assert_eq(errors, [] as Array[String], "main %d" % position)
	assert_true(caravan_rules >= 1, "some keep the caravan road's rule")


func test_validator_knows_a_swap() -> void:
	var start: PuzzleState = PuzzleState.new([[5, 3, 1], [], [], [4, 2]])
	assert_true(LevelValidator.is_great_exchange(start, PuzzleState.new([[4, 2], [], [], [5, 3, 1]])))
	assert_false(LevelValidator.is_great_exchange(start, PuzzleState.new([[], [], [], [5, 4, 3, 2, 1]])), "not one tower")
	assert_false(LevelValidator.is_great_exchange(PuzzleState.new([[3, 1], [2], [], []]), start), "two stacks on the end pegs")
	var level: Level = Level.create(9900, "medium", start, PuzzleState.new([[], [5, 4, 3, 2, 1], [], []]),
			["classic_hanoi"] as Array[String], Solver.solve(start, PuzzleState.new([[], [5, 4, 3, 2, 1], [], []]), RuleSet.classic())["path"])
	level.boss = Level.GREAT_EXCHANGE
	var errors: Array[String] = []
	LevelValidator.validate_mechanic_design(level, errors)
	assert_true(" ".join(errors).contains("great exchange"), str(errors))
	var data: Dictionary = level.to_dict()
	assert_eq(data["boss"], Level.GREAT_EXCHANGE, "written to the level file")
	data["boss"] = "dragon"
	var parse_errors: Array[String] = []
	assert_null(Level.from_dict(data, parse_errors), "unknown boss kinds are rejected")


func test_board_shows_two_caravans_and_explains_the_goal() -> void:
	var board: GameBoard = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	board.save_system = SaveSystem.new(SAVE_PATH)
	board.tutorials_enabled = false
	board.background_hints = false
	_add(board)
	var level: Level = LevelCatalog.load_at(MAIN, _boss_positions()[0])
	board.start_level(level)
	var white: Dictionary = ThemeManager.EXCHANGE_DISKS["white"]
	var black: Dictionary = ThemeManager.EXCHANGE_DISKS["black"]
	for view: DiskView in board.get_node("%DiskLayer").get_children():
		var on_left: bool = level.start.pegs[0].has(view.disk_size)
		assert_eq(view.color, white["fill"] if on_left else black["fill"], "disk %d" % view.disk_size)
		assert_eq(view.number_color, white["text"] if on_left else black["text"])
	var preview: BoardPreview = board.get_node("%GoalPreview")
	assert_eq(preview.disk_palette.size(), level.get_disk_count(), "the goal shows the same caravans")
	var status: Label = board.get_node("%StatusLabel")
	assert_eq(status.text, tr("BOSS_EXCHANGE_INTRO"))
	assert_eq(status.theme_type_variation, &"SecondaryLabel", "a calm explanation")
	assert_eq(board.get_board_skin().skin, "caravan", "the caravan road's dress")
	for move: Move in level.solution_path:
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)
	assert_true(board.session.is_solved())
	assert_eq(board.last_result["stars"], 3, "stars like any level")


func test_map_shows_a_boss_as_a_larger_stop() -> void:
	var save: SaveSystem = SaveSystem.new(SAVE_PATH)
	var first: int = _boss_positions()[0]
	for position: int in range(1, first):
		save.completed_levels[str(LevelCatalog.level_id_at(MAIN, position))] = {"stars": 1, "best_moves": 99, "best_time_seconds": 9}
	var screen: Control = SELECT_SCENE.instantiate()
	screen.save_system = save
	_add(screen)
	var boss: LevelCell = screen.get_cell(first)
	var plain: LevelCell = screen.get_cell(first - 1)
	assert_true(boss.boss)
	assert_false(plain.boss)
	assert_true(boss.size.x > plain.size.x, "larger than an ordinary stop")
	assert_eq(boss.skin, "caravan")
