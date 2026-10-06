class_name PegView
extends Control
## One peg column. The whole column is the tap target, which keeps it easy to
## hit on a phone. The board sets the rod and base geometry.

signal pressed(peg_index: int)

const FLASH_SECONDS: float = 0.35

var peg_index: int = 0
## Y of the top of the base, i.e. where the bottom disk sits.
var base_top: float = 0.0
var base_height: float = 14.0
var rod_top: float = 0.0
var rod_width: float = 10.0
var base_width: float = 100.0
## Marks the peg the selected disk came from.
var highlighted: bool = false:
	set(value):
		highlighted = value
		queue_redraw()
## 0..1, how red the peg is (illegal-move flash).
var flash_amount: float = 0.0:
	set(value):
		flash_amount = value
		queue_redraw()

var _flash_tween: Tween


func configure(p_base_top: float, p_base_height: float, p_rod_top: float, p_rod_width: float, p_base_width: float) -> void:
	base_top = p_base_top
	base_height = p_base_height
	rod_top = p_rod_top
	rod_width = p_rod_width
	base_width = p_base_width
	queue_redraw()


## Short red flash: the move onto this peg was rejected.
func flash_invalid() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	flash_amount = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "flash_amount", 0.0, FLASH_SECONDS)


func _draw() -> void:
	var base_color: Color = UIPalette.ACCENT if highlighted else UIPalette.PEG
	var peg_color: Color = base_color.lerp(UIPalette.ERROR, flash_amount)
	var center_x: float = size.x * 0.5
	var rod: StyleBoxFlat = StyleBoxFlat.new()
	rod.bg_color = peg_color
	rod.set_corner_radius_all(int(rod_width * 0.5))
	draw_style_box(rod, Rect2(center_x - rod_width * 0.5, rod_top, rod_width, base_top - rod_top + 1.0))
	var base: StyleBoxFlat = StyleBoxFlat.new()
	base.bg_color = peg_color
	base.set_corner_radius_all(int(base_height * 0.5))
	draw_style_box(base, Rect2(center_x - base_width * 0.5, base_top, base_width, base_height))


func _gui_input(event: InputEvent) -> void:
	# Touches arrive as emulated mouse clicks (Godot's default on mobile).
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(peg_index)
		accept_event()
