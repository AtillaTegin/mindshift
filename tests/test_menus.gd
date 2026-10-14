extends "res://tests/test_case.gd"
## Main menu and shop screens (the level map: test_level_map.gd).

const MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const SAVE_PATH: String = "res://.test_saves/test_menus_save.json"

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


func test_main_menu_has_four_polished_buttons() -> void:
	# Economy/UX addendum 5: Play, Levels, Shop, Settings, in this order.
	var menu: Control = MENU_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	_nodes.append(menu)
	var buttons: Array[String] = []
	for child: Node in menu.get_node("Center/Layout").get_children():
		if child is Button:
			assert_true(child is PolishedButton, "%s dips when pressed" % child.name)
			buttons.append((child as Button).text)
	assert_eq(buttons, ["MENU_PLAY", "MENU_LEVELS", "MENU_SHOP", "MENU_SETTINGS"] as Array[String])
	assert_eq(menu.tr("MENU_SHOP"), "Mağaza")


func test_shop_screen_shows_coins() -> void:
	var shop: Control = (load("res://scenes/shop.tscn") as PackedScene).instantiate()
	var economy: EconomySystem = EconomySystem.new()
	_save.coins = 7
	economy.setup(_save)
	shop.economy = economy
	(Engine.get_main_loop() as SceneTree).root.add_child(shop)
	_nodes.append(shop)
	assert_eq((shop.get_node("%CoinLabel") as Label).text, "7")
	economy.earn(3, "test")
	assert_eq((shop.get_node("%CoinLabel") as Label).text, "10", "follows the balance")
	economy.free()


func test_main_menu_builds() -> void:
	var menu: Control = MENU_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	_nodes.append(menu)
	assert_true((menu.get_node("%ProgressLabel") as Label).text.ends_with("/ %d" % (LevelCatalog.total_levels() * 3)), "every level on the path, 3 stars each")
	assert_eq(LevelCatalog.total_levels(), 300, "194 classic + 106 mechanic levels")
	assert_false((menu.get_node("%SettingsPanel") as Control).visible)
	(menu.get_node("%SettingsButton") as Button).pressed.emit()
	assert_true((menu.get_node("%SettingsPanel") as Control).visible)
	(menu.get_node("%CloseSettingsButton") as Button).pressed.emit()
	assert_false((menu.get_node("%SettingsPanel") as Control).visible)
