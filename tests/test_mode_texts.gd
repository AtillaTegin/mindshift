extends "res://tests/test_case.gd"
## Mode labels specification v1 (2026-10-15): every mode has a short label
## beside its stops on the level map and a name and rule under the board, all
## from one register (ModeTexts). A mode the levels or the rule registry can
## produce without an entry there fails here, so none is ever forgotten.
## Tests of the full road (ROAD_MODE=full); the demo road skips them.
const FULL_ROAD_TESTS: Array[String] = ["test_every_stop_on_the_map_carries_its_mode"]

const SAVE_PATH: String = "res://.test_saves/test_mode_texts_save.json"
const MAIN: String = LevelCatalog.MAIN
const SELECT_SCENE: PackedScene = preload("res://scenes/level_select.tscn")
## The rule panel's width and font sizes (scenes/game_board.tscn).
const PANEL_WIDTH: float = 540.0
const NAME_FONT_SIZE: int = 26
const RULE_FONT_SIZE: int = 22

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


func test_every_mode_in_the_game_is_registered() -> void:
	# Every level on the path, every track (combinations included).
	var lessons: Dictionary = {}
	for track: String in LevelCatalog.tracks():
		for position: int in range(1, LevelCatalog.track_length(track) + 1):
			lessons[LevelCatalog.lesson_at(track, position)] = true
	# Every rule the registry can create (the mixed great exchange is a mode of its own).
	for id: String in RuleSet.RULE_IDS:
		var rule: RuleBase = RuleSet.create_rule(id)
		assert_not_null(rule, "%s is in create_rule()" % id)
		assert_eq(rule.get_id(), id)
		# A sub-element's rule (the sealed box) speaks through its mode.
		lessons[Level.CLASSIC if id == ClassicHanoiRule.ID else ChapterPlan.mode_of_rule(id)] = true
	lessons[Level.COLOR_SWAP_MIXED] = true
	# Every mode and combination of the chapter plan.
	for mode: String in ChapterPlan.MODES:
		lessons[mode] = true
	for key: String in ChapterPlan.whitelist():
		lessons[key] = true
	assert_null(RuleSet.create_rule("no_such_rule"))
	for lesson: String in lessons:
		assert_true(ModeTexts.has(lesson), "%s has its label, name and rule" % lesson)
	assert_false(ModeTexts.has("peg_capacity+no_such_mode"))


func test_every_register_entry_has_its_three_texts() -> void:
	for lesson: String in ModeTexts.MODES:
		for key: String in [ModeTexts.label_key(lesson), ModeTexts.name_key(lesson), ModeTexts.rule_key(lesson)]:
			assert_ne(Languages.text(key), key, "%s is in az.po" % key)


func test_names_take_one_line_and_rules_at_most_two() -> void:
	var font: Font = ThemeDB.fallback_font
	for lesson: String in ModeTexts.MODES:
		var name: String = Languages.text(ModeTexts.name_key(lesson))
		assert_true(font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, NAME_FONT_SIZE).x <= PANEL_WIDTH,
				"%s: the name fits one line" % lesson)
		var rule: String = Languages.text(ModeTexts.rule_key(lesson)).replace("%d", "10")
		var lines: float = font.get_multiline_string_size(rule, HORIZONTAL_ALIGNMENT_CENTER, PANEL_WIDTH, RULE_FONT_SIZE).y \
				/ font.get_height(RULE_FONT_SIZE)
		assert_true(lines <= 2.01, "%s: the rule takes %.1f lines" % [lesson, lines])


func test_every_stop_on_the_map_carries_its_mode() -> void:
	var save: SaveSystem = SaveSystem.new(SAVE_PATH)
	for position: int in range(1, 91):
		save.completed_levels[str(LevelCatalog.level_id_at(MAIN, position))] = {"stars": 1, "best_moves": 99, "best_time_seconds": 9}
	var screen: Control = SELECT_SCENE.instantiate()
	screen.save_system = save
	_add(screen)
	var map: PathMap = screen.get_map()
	# The phone's map width (headless runs have no real window size).
	map.size = Vector2(672.0, map.custom_minimum_size.y)
	var stops: Array[Rect2] = []
	for position: int in range(1, map.shown_count() + 1):
		var cell: LevelCell = map.get_cell(position)
		stops.append(Rect2(cell.position, cell.size))
	for position: int in range(1, map.shown_count() + 1):
		var label: Label = map.get_label(position)
		assert_eq(label.text, ModeTexts.label(LevelCatalog.lesson_at(MAIN, position)), "main %d" % position)
		var rect: Rect2 = Rect2(label.position, label.size)
		assert_true(rect.position.x >= 0.0 and rect.end.x <= map.size.x, "main %d: inside the map" % position)
		for stop: Rect2 in stops:
			assert_false(rect.intersects(stop), "main %d: clear of every stop" % position)
	var island: Button = map.get_island_button()
	assert_not_null(island)
	var after: int = LevelCatalog.island_after(LevelCatalog.island_tracks()[0])
	assert_false(Rect2(map.get_label(after).position, map.get_label(after).size)
			.intersects(Rect2(island.position, island.size)), "clear of the island marker")


func test_island_labels_name_expert_levels_only() -> void:
	for island: String in LevelCatalog.island_tracks():
		var experts: int = 0
		for position: int in range(1, LevelCatalog.track_length(island) + 1):
			var text: String = PathMap.stop_label(island, position)
			var expert: bool = LevelCatalog.load_at(island, position).difficulty == "expert"
			assert_eq(text.ends_with(Languages.text("MAP_EXPERT_SUFFIX")), expert, "%s %d: %s" % [island, position, text])
			experts += 1 if expert else 0
		if LevelCatalog.island_mode(island) == Level.CLASSIC:
			assert_true(experts > 0 and experts < LevelCatalog.track_length(island), "the classic island mixes in breathers")
		else:
			pass  # eased islands: the tier follows the moves, the label follows the tier (checked above)
	for position: int in range(1, 30):
		assert_false(PathMap.stop_label(MAIN, position).contains(Languages.text("MAP_EXPERT_SUFFIX")), "never on the main road")


func test_combinations_join_their_modes() -> void:
	# Chapter plan section 4.4: "Tutum + Kilid" on the map, both rules under the board.
	var combo: Level = null
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.lesson_at(MAIN, position) == "peg_capacity+foundation":
			combo = LevelCatalog.load_at(MAIN, position)
			assert_eq(PathMap.stop_label(MAIN, position), "%s + %s" % [tr("MODE_CAPACITY_LABEL"), tr("MODE_FOUNDATION_LABEL")])
			break
	assert_not_null(combo, "world 2 has it")
	assert_eq(ModeTexts.name_of(combo), "%s + %s" % [tr("MODE_CAPACITY_LABEL"), tr("MODE_FOUNDATION_LABEL")],
			"named like its map label")
	assert_eq(ModeTexts.rule_of(combo), "%s %s" % [tr("MODE_CAPACITY_RULE"), tr("MODE_FOUNDATION_RULE")])
	# Up to three lines for two rules (section 4.4), the name on one.
	var font: Font = ThemeDB.fallback_font
	for key: String in ChapterPlan.whitelist():
		var parts: PackedStringArray = PackedStringArray()
		for mode: String in key.split("+"):
			parts.append(Languages.text(ModeTexts.rule_key(mode)).replace("%d", "10"))
		var lines: float = font.get_multiline_string_size(" ".join(parts), HORIZONTAL_ALIGNMENT_CENTER, PANEL_WIDTH,
				RULE_FONT_SIZE).y / font.get_height(RULE_FONT_SIZE)
		assert_true(lines <= 3.01, "%s: the rules take %.1f lines" % [key, lines])
		var name_width: float = font.get_string_size(ModeTexts.label(key), HORIZONTAL_ALIGNMENT_CENTER, -1, NAME_FONT_SIZE).x
		assert_true(name_width <= PANEL_WIDTH, "%s: the name fits one line (%.0f)" % [key, name_width])


func test_rule_panel_shows_the_mode_under_the_board() -> void:
	var board: GameBoard = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	board.save_system = SaveSystem.new(SAVE_PATH)
	board.tutorials_enabled = false
	board.background_hints = false
	board.level_path = ""
	_add(board)
	board.start_level(LevelCatalog.load_at(MAIN, 5))
	assert_eq((board.get_node("%RuleName") as Label).text, tr("MODE_CLASSIC_NAME"))
	assert_eq((board.get_node("%RuleText") as Label).text, tr("MODE_CLASSIC_RULE"))
	# The balance's chapter is not built yet (world 4): a small one of its own.
	var rule_ids: Array[String] = ["classic_hanoi", "balance"]
	var params: Dictionary = {"balance": {"tolerance": 3}}
	var start: PuzzleState = PuzzleState.new([[1], [], [2], []])
	var goal: PuzzleState = PuzzleState.new([[], [1], [], [2]])
	var path: Array[Move] = Solver.solve(start, goal, RuleSet.from_ids(rule_ids, params))["path"]
	var balance: Level = Level.create(17001, "easy", start, goal, rule_ids, path, params)
	board.start_level(balance)
	var tolerance: int = (balance.get_rule_set().active_rules[1] as BalanceRule).tolerance
	assert_eq((board.get_node("%RuleText") as Label).text, tr("MODE_BALANCE_RULE") % tolerance, "the balance names its limit")
	assert_eq((board.get_node("%StatusLabel") as Label).text, "", "the rule is not repeated in the status line")
