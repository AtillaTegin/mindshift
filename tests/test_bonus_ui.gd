extends "res://tests/test_case.gd"
## Bonus levels in the UI (bonus mechanics addendum 3): gift cells at the end
## of every tab, always open, and bonus boards that lead back to their tab.

const SAVE_PATH: String = "res://.test_saves/test_bonus_ui_save.json"

var _nodes: Array[Node] = []
var _save: SaveSystem


func before_each() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_save = SaveSystem.new(SAVE_PATH)


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


func test_every_tab_ends_with_open_gift_cells() -> void:
	var screen: Control = (load("res://scenes/level_select.tscn") as PackedScene).instantiate()
	screen.save_system = _save
	_add(screen)
	_save.record_completion(9004, 2, 40, 60.0)
	for tier: String in Difficulty.ORDER:
		screen.show_tier(tier)
		var entries: Array[Dictionary] = LevelCatalog.bonus_for_tab(tier)
		assert_true(entries.size() >= 1 and entries.size() <= LevelCatalog.BONUS_PER_TAB, "%s: 1-2 bonus cells" % tier)
		for i: int in entries.size():
			var cell: LevelCell = screen.get_bonus_cell(i + 1)
			assert_true(cell.bonus, "%s bonus %d" % [tier, i + 1])
			assert_false(cell.locked or cell.disabled, "%s bonus %d is always open" % [tier, i + 1])
			assert_eq(cell.theme_type_variation, &"BonusButton", "its own colour")
			assert_true(cell is PolishedButton)
			var bound: Array = cell.pressed.get_connections()[0]["callable"].get_bound_arguments()
			assert_eq(bound, [entries[i]["file"]], "opens %s" % entries[i]["file"])
	screen.show_tier("expert")
	assert_true(screen.get_cell(1).locked, "the expert tab itself is locked on a fresh save")
	assert_eq(screen.get_bonus_cell(1).stars, 2, "stars of a played bonus level")


func test_gift_icon_is_known() -> void:
	assert_true(GameIcons.is_known("gift"))
	assert_true(ThemeManager.ICON_COLORS.has("gift") and ThemeManager.ICON_COLORS.has("gift_ribbon"))


func test_bonus_board_has_no_next_and_returns_to_its_tab() -> void:
	var board: GameBoard = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	board.save_system = _save
	board.tutorials_enabled = false
	board.animate_transitions = false
	board.level_path = LevelCatalog.bonus_dir() + "/fog_02.json"
	_add(board)
	assert_eq(LevelCatalog.economy_tier(board.session.level), "medium", "fog_02 lives in the medium tab")
	assert_eq((board.get_node("%LevelLabel") as Label).text, "Bonus · 6")
	for move: Move in board.session.level.solution_path:
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)
	assert_true(board.session.is_solved())
	assert_eq(board.last_result["stars"], 3)
	assert_eq(board.last_result["reward"], 8, "coins like any level")
	assert_eq(_save.get_stars(board.session.level.id), 3, "saved under its bonus id")
	var popup: LevelCompletePopup = board.get_popup()
	assert_false((popup.get_node("%NextButton") as Button).visible, "no next level after a bonus")
	assert_true((popup.get_node("%ReplayButton") as Button).visible)
	assert_true((popup.get_node("%LevelsButton") as Button).visible)
	board.restart()
	board.start_level(LevelCatalog.load_level("easy", 3))
	for move: Move in board.session.level.solution_path:
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)
	assert_true((popup.get_node("%NextButton") as Button).visible, "main levels keep their next button")


func test_bonus_stars_count_in_the_total_but_not_for_unlocking() -> void:
	for entry: Dictionary in LevelCatalog.bonus_entries():
		_save.record_completion(entry["id"], 3, 10, 10.0)
	assert_eq(_save.get_total_stars(), 3 * LevelCatalog.bonus_entries().size())
	assert_eq(LevelCatalog.next_to_play(_save), {"tier": "easy", "index": 1}, "Play still starts the main path")
	assert_false(LevelCatalog.is_tier_unlocked("medium", _save))
