extends "res://tests/test_case.gd"
## Game feel (addendum 6B-5): bounce, shadow, confetti, button dip, transitions.

const SCENES_WITH_BUTTONS: Array[String] = [
	"res://scenes/main_menu.tscn",
	"res://scenes/level_select.tscn",
	"res://scenes/game_board.tscn",
	"res://scenes/level_complete_popup.tscn",
]

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		if is_instance_valid(node):
			node.get_parent().remove_child(node)
			node.free()
	_nodes.clear()


func _add(node: Node) -> Node:
	(Engine.get_main_loop() as SceneTree).root.add_child(node)
	_nodes.append(node)
	return node


func test_every_scene_button_is_polished() -> void:
	for path: String in SCENES_WITH_BUTTONS:
		var scene: Node = (load(path) as PackedScene).instantiate()
		var plain: Array[String] = []
		for node: Node in scene.find_children("*", "Button", true, false):
			if not node is PolishedButton and not node is CheckButton:
				plain.append(node.name)
		assert_eq(plain, [] as Array[String], "%s has plain buttons" % path.get_file())
		scene.free()


func test_polished_button_dips_while_pressed() -> void:
	var button: PolishedButton = _add(PolishedButton.new())
	button.size = Vector2(200, 80)
	button.button_down.emit()
	assert_eq(button.pivot_offset, Vector2(100, 40), "scales around its centre")
	assert_true(button._tween != null and button._tween.is_running())


func test_disk_has_shadow_and_bounces() -> void:
	var disk: DiskView = _add((load("res://scenes/components/disk.tscn") as PackedScene).instantiate())
	disk.size = Vector2(120, 40)
	var shadow: Polygon2D = disk.get_node("Shadow")
	assert_true(shadow.show_behind_parent, "drawn under the disk")
	assert_true(shadow.polygon.size() > 8, "rounded outline")
	assert_eq(shadow.position, DiskView.SHADOW_OFFSET)
	assert_true(shadow.color.a < 0.5, "semi-transparent")
	disk.move_to(Vector2(300, 0), true)
	assert_true(disk._move != null and disk._move.is_running(), "glides instead of jumping")
	disk.move_to(Vector2(10, 10), false)
	assert_eq(disk.position, Vector2(10, 10))


func test_popup_bursts_confetti_once() -> void:
	var popup: LevelCompletePopup = _add((load("res://scenes/level_complete_popup.tscn") as PackedScene).instantiate())
	assert_false(popup.is_confetti_emitting())
	popup.show_result(3, 7, 7, 12.0, true, true, 6)
	assert_true(popup.is_confetti_emitting())
	var confetti: CPUParticles2D = popup._confetti
	assert_true(confetti.one_shot, "a single burst")


func test_transition_autoload_is_registered() -> void:
	var transition: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("ScreenTransition")
	assert_not_null(transition, "ScreenTransition autoload")
	assert_false(transition.is_busy())
	assert_eq(transition.get_cover_alpha(), 0.0)
