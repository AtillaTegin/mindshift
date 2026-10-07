extends Control
## Demo of the coaching primitives on their own (addendum Day 6B-1): two dummy
## targets and one button per component. Run this scene from the editor (F6).

const COMPONENTS: Array[String] = ["Scrim", "FocusRing", "GhostPointer", "CoachToast", "CoachToastLong", "Gizlət"]

var coaching: CoachingLayer
var disk_target: ColorRect
var peg_target: ColorRect


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = ThemeManager.color("background")
	background.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(background)
	disk_target = _target(Rect2(80, 640, 220, 50), ThemeManager.disk_color(3, 4))
	peg_target = _target(Rect2(500, 520, 16, 300), ThemeManager.color("peg"))
	var buttons: VBoxContainer = VBoxContainer.new()
	buttons.position = Vector2(40, 40)
	buttons.custom_minimum_size = Vector2(640, 0)
	buttons.add_theme_constant_override("separation", 10)
	add_child(buttons)
	for component: String in COMPONENTS:
		var button: Button = Button.new()
		button.text = component
		button.custom_minimum_size = Vector2(0, 64)
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(show_component.bind(component))
		buttons.add_child(button)
	coaching = preload("res://scenes/components/coaching/coaching_layer.tscn").instantiate()
	add_child(coaching)


## Shows one component on the dummy targets, hiding the others.
func show_component(component: String) -> void:
	coaching.clear()
	match component:
		"Scrim":
			coaching.scrim.show_scrim(disk_target.get_global_rect().grow(24))
		"FocusRing":
			coaching.ring.show_around(disk_target.get_global_rect())
		"GhostPointer":
			coaching.pointer.play(disk_target.get_global_rect().get_center(),
					Vector2(peg_target.get_global_rect().get_center().x, peg_target.get_global_rect().position.y))
		"CoachToast":
			coaching.toast.show_message("Əla!")
		"CoachToastLong":
			coaching.toast.show_message("Diqqət! Böyük disk kiçik diskin üstünə qoyula bilməz.")


func _target(rect: Rect2, color: Color) -> ColorRect:
	var target: ColorRect = ColorRect.new()
	target.position = rect.position
	target.size = rect.size
	target.color = color
	add_child(target)
	return target
