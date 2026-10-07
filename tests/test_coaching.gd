extends "res://tests/test_case.gd"
## Coaching primitives (addendum 6B-1): Scrim, FocusRing, GhostPointer,
## CoachToast, each driven on its own.

const LAYER_SCENE: PackedScene = preload("res://scenes/components/coaching/coaching_layer.tscn")
const COMPONENT_SCRIPTS: Array[String] = [
	"res://scenes/components/coaching/scrim.gd",
	"res://scenes/components/coaching/focus_ring.gd",
	"res://scenes/components/coaching/ghost_pointer.gd",
	"res://scenes/components/coaching/coach_toast.gd",
	"res://scenes/components/coaching/coaching_layer.gd",
]

var _layer: CoachingLayer


func before_each() -> void:
	_layer = LAYER_SCENE.instantiate()
	(Engine.get_main_loop() as SceneTree).root.add_child(_layer)


func after_each() -> void:
	_layer.get_parent().remove_child(_layer)
	_layer.free()


func test_all_hidden_at_start() -> void:
	assert_false(_layer.scrim.is_shown())
	assert_false(_layer.ring.visible)
	assert_false(_layer.pointer.is_playing())
	assert_false(_layer.toast.visible)
	assert_eq(_layer.layer, 10, "drawn above the game screen")


func test_scrim_shows_hole_and_never_takes_input() -> void:
	var hole: Rect2 = Rect2(100, 200, 300, 80)
	_layer.scrim.show_scrim(hole)
	assert_true(_layer.scrim.is_shown())
	assert_eq(_layer.scrim.hole, hole)
	assert_eq(_layer.scrim.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_layer.scrim.hide_scrim()
	assert_false(_layer.scrim.is_shown())


func test_focus_ring_surrounds_target() -> void:
	var target: Rect2 = Rect2(80, 640, 220, 50)
	_layer.ring.show_around(target)
	assert_true(_layer.ring.visible)
	assert_true(_layer.ring.get_target().is_equal_approx(target))
	assert_eq(_layer.ring.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_layer.ring.hide_ring()
	assert_false(_layer.ring.visible)


func test_ghost_pointer_plays_gesture_and_stops() -> void:
	_layer.pointer.play(Vector2(100, 600), Vector2(500, 300))
	assert_true(_layer.pointer.is_playing())
	assert_eq(_layer.pointer.get_gesture(), [Vector2(100, 600), Vector2(500, 300)] as Array[Vector2])
	assert_eq(_layer.pointer.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_layer.pointer.stop()
	assert_false(_layer.pointer.is_playing())
	assert_false(_layer.pointer.visible)


func test_toast_shows_text_and_wraps_long_messages() -> void:
	_layer.toast.show_message("Əla!")
	assert_true(_layer.toast.visible)
	assert_eq(_layer.toast.get_text(), "Əla!")
	var long_text: String = "Diqqət! Böyük disk kiçik diskin üstünə qoyula bilməz. Başqa qüllə seçin."
	_layer.toast.show_message(long_text)
	assert_eq(_layer.toast.get_text(), long_text, "words kept, only line breaks added")
	var viewport_width: float = _layer.get_viewport().get_visible_rect().size.x
	assert_true(_layer.toast.size.x <= viewport_width, "fits the screen width")
	assert_eq(_layer.toast.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	_layer.toast.hide_now()
	assert_false(_layer.toast.visible)


func test_clear_hides_scrim_ring_and_pointer() -> void:
	_layer.scrim.show_scrim()
	_layer.ring.show_around(Rect2(0, 0, 50, 50))
	_layer.pointer.play(Vector2.ZERO, Vector2(10, 10))
	_layer.clear()
	assert_false(_layer.scrim.is_shown())
	assert_false(_layer.ring.visible)
	assert_false(_layer.pointer.is_playing())


func test_components_know_nothing_about_tutorial_or_hint() -> void:
	# Addendum 2.1: the primitives only take coordinates and text.
	var forbidden: Array[String] = ["Tutorial", "Hint", "GameSession", "Level", "Solver", "Economy", "App"]
	for path: String in COMPONENT_SCRIPTS:
		var source: String = FileAccess.get_file_as_string(path)
		for word: String in forbidden:
			var regex: RegEx = RegEx.create_from_string("\\b%s\\b" % word)
			assert_null(regex.search(source), "%s mentions %s" % [path.get_file(), word])
