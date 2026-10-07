extends "res://tests/test_case.gd"
## Level select and main menu screens.

const SELECT_SCENE: PackedScene = preload("res://scenes/level_select.tscn")
const MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const SAVE_PATH: String = "user://test_menus_save.json"

var _save: SaveSystem
var _nodes: Array[Node] = []


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


func _level_select() -> Control:
	var screen: Control = SELECT_SCENE.instantiate()
	screen.save_system = _save
	(Engine.get_main_loop() as SceneTree).root.add_child(screen)
	_nodes.append(screen)
	return screen


func test_level_select_shows_stars_and_locks() -> void:
	_save.record_completion(1001, 3, 5, 5.0)
	_save.record_completion(1002, 1, 20, 5.0)
	var screen: Control = _level_select()
	screen.show_tier("easy")
	var grid: GridContainer = screen.get_node("%Grid")
	assert_eq(grid.get_child_count(), 50)
	assert_eq(screen.get_cell(1).stars, 3)
	assert_eq(screen.get_cell(2).stars, 1)
	assert_false(screen.get_cell(3).locked, "unlocked by level 2")
	assert_eq(screen.get_cell(3).stars, 0)
	assert_true(screen.get_cell(4).locked)
	assert_true(screen.get_cell(4).disabled)
	assert_eq((screen.get_node("%StarsLabel") as Label).text, "Ulduz: 4")


func test_level_select_tabs() -> void:
	var screen: Control = _level_select()
	screen.show_tier("expert")
	assert_eq(screen.current_tier, "expert")
	assert_eq(screen.get_node("%Grid").get_child_count(), 50)
	assert_false(screen.get_cell(1).locked)
	assert_true(screen.get_cell(2).locked)
	assert_eq((screen.get_node("%TierInfo") as Label).text, "36+ gediş · 4 qüllə · 9-10 disk")
	screen.show_tier("medium")
	assert_eq((screen.get_node("%TierInfo") as Label).text, "9-18 gediş · 3-4 qüllə · 5-6 disk")


func test_level_select_emits_choice() -> void:
	var screen: Control = _level_select()
	screen.show_tier("hard")
	var chosen: Array = []
	screen.level_chosen.connect(func(tier: String, index: int) -> void: chosen.append([tier, index]))
	# Without the App autoload nothing else happens; with it this would switch scenes.
	if screen.get_node_or_null("/root/App") == null:
		screen.get_cell(1).pressed.emit()
		assert_eq(chosen, [["hard", 1]])


func test_main_menu_builds() -> void:
	var menu: Control = MENU_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	_nodes.append(menu)
	assert_true((menu.get_node("%ProgressLabel") as Label).text.ends_with("/ 600"))
	assert_false((menu.get_node("%SettingsPanel") as Control).visible)
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	assert_true((menu.get_node("%SettingsPanel") as Control).visible)
	(menu.get_node("%CloseSettingsButton") as Button).pressed.emit()
	assert_false((menu.get_node("%SettingsPanel") as Control).visible)
