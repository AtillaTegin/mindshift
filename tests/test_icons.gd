extends "res://tests/test_case.gd"
## Code-drawn icons (economy/UX addendum 7): coin, hint and undo, with fixed
## colours, shown through the PolishedButton icon slot and next to coin labels.

const BOARD_SCENE: PackedScene = preload("res://scenes/game_board.tscn")
const SAVE_PATH: String = "res://.test_saves/test_icons_save.json"

var _nodes: Array[Node] = []
var _mode_before: String = ""


func before_each() -> void:
	_mode_before = ThemeManager.mode


func after_each() -> void:
	for node: Node in _nodes:
		node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()
	ThemeManager.set_mode(_mode_before)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _add(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_nodes.append(node)
	return node


func test_icon_kinds() -> void:
	# The drawing itself is checked in a real window (see README, 7).
	assert_eq(GameIcons.KINDS, ["coin", "hint", "undo"] as Array[String])
	for kind: String in GameIcons.KINDS:
		assert_true(GameIcons.is_known(kind))
	assert_false(GameIcons.is_known(""))
	assert_false(GameIcons.is_known("star"))


func test_icon_colours_are_fixed_across_modes() -> void:
	var colours: Dictionary = {}
	ThemeManager.set_mode(ThemeManager.LIGHT)
	for role: String in ThemeManager.ICON_COLORS:
		colours[role] = ThemeManager.icon_color(role)
	ThemeManager.set_mode(ThemeManager.DARK)
	for role: String in ThemeManager.ICON_COLORS:
		assert_eq(ThemeManager.icon_color(role), colours[role], "%s is the same in dark mode" % role)
	var hint: Color = ThemeManager.icon_color("hint")
	var coin: Color = ThemeManager.icon_color("coin")
	assert_true(hint.b > hint.r and hint.b > hint.g, "hint is blue-violet")
	assert_true(coin.r > coin.b and coin.g > coin.b, "coin is warm gold")
	assert_ne(hint, ThemeManager.color("danger"), "hint never looks like a warning")


func test_icon_slot_sits_left_of_the_text_inside_the_button() -> void:
	var button: PolishedButton = _add(PolishedButton.new())
	button.text = "Hint · 1 coin"
	button.add_theme_font_size_override("font_size", 26)
	button.size = Vector2(320, 80)
	assert_eq(button.get_icon_rect(), Rect2(), "no icon by default")
	button.icon_kind = "hint"
	var icon: Rect2 = button.get_icon_rect()
	var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	assert_true(Rect2(Vector2.ZERO, button.size).encloses(icon), "inside the button")
	assert_true(icon.end.x <= (button.size.x - text_width) * 0.5, "left of the centred text")
	assert_true(absf(icon.get_center().y - button.size.y * 0.5) < 0.5, "vertically centred")


func test_board_shows_hint_undo_and_coin_icons() -> void:
	var board: GameBoard = BOARD_SCENE.instantiate()
	board.save_system = SaveSystem.new(SAVE_PATH)
	board.tutorials_enabled = false
	_add(board)
	assert_eq((board.get_node("%HintButton") as PolishedButton).icon_kind, "hint")
	assert_eq((board.get_node("%UndoButton") as PolishedButton).icon_kind, "undo")
	var coin_icon: IconView = board.get_node("%CoinIcon")
	assert_eq(coin_icon.kind, "coin")
	assert_eq(coin_icon.get_parent(), board.get_node("%CoinLabel").get_parent(), "next to the balance")


func test_shop_shows_the_coin_icon() -> void:
	var shop: Control = _add((load("res://scenes/shop.tscn") as PackedScene).instantiate())
	assert_eq((shop.get_node("%CoinIcon") as IconView).kind, "coin")
