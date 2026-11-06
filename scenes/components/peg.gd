class_name PegView
extends Control
## One peg column. The whole column is the tap target, which keeps it easy to
## hit on a phone. The board sets the rod and base geometry.

signal pressed(peg_index: int)

const FLASH_SECONDS: float = 0.35

var peg_index: int = 0
var sculpted_base: bool = false
var stone_color: Color
var inlay_color: Color
var needle_color: Color
## Dress of the level (ThemeManager.SKINS): the rod and base take its colour.
var skin: String = "":
	set(value):
		skin = value
		queue_redraw()
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
## How far the peg is drawn below its place (a balance scale's pan, Tərəzi);
## the tap area stays where it is.
var lift: float = 0.0:
	set(value):
		lift = value
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
	var base_color: Color = ThemeManager.color("accent") if highlighted else ThemeManager.skin_color(skin, "peg")
	var peg_color: Color = base_color.lerp(ThemeManager.color("danger"), flash_amount)
	var center_x: float = size.x * 0.5
	draw_set_transform(Vector2(0.0, lift))
	if sculpted_base:
		_draw_sculpted(center_x, peg_color)
		return
	var rod: StyleBoxFlat = StyleBoxFlat.new()
	rod.bg_color = peg_color
	rod.set_corner_radius_all(int(rod_width * 0.5))
	draw_style_box(rod, Rect2(center_x - rod_width * 0.5, rod_top, rod_width, base_top - rod_top + 1.0))
	var base: StyleBoxFlat = StyleBoxFlat.new()
	base.bg_color = peg_color
	base.set_corner_radius_all(int(base_height * 0.5))
	draw_style_box(base, Rect2(center_x - base_width * 0.5, base_top, base_width, base_height))


func _draw_sculpted(center_x: float, feedback: Color) -> void:
	var rod: Color = needle_color.lerp(feedback, maxf(flash_amount, 0.45 if highlighted else 0.0))
	var half_rod: float = rod_width * 0.55
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x, rod_top), Vector2(center_x + half_rod, rod_top + 10.0),
		Vector2(center_x + half_rod, base_top), Vector2(center_x - half_rod, base_top),
		Vector2(center_x - half_rod, rod_top + 10.0),
	]), rod)
	draw_line(Vector2(center_x, rod_top + 4.0), Vector2(center_x, base_top), rod.lightened(0.45), 2.0, true)
	var left: float = center_x - base_width * 0.5
	var stone: Color = stone_color.lerp(feedback, flash_amount)
	var cap: float = base_height * 0.32
	draw_rect(Rect2(left, base_top, base_width, base_height - cap), stone.darkened(0.18))
	draw_set_transform(Vector2(center_x, base_top + base_height - cap + lift), 0.0, Vector2(1.0, 2.0 * cap / base_width))
	draw_circle(Vector2.ZERO, base_width * 0.5, stone.darkened(0.18), true, -1.0, true)
	draw_set_transform(Vector2(center_x, base_top + lift), 0.0, Vector2(1.0, 2.0 * cap / base_width))
	draw_circle(Vector2.ZERO, base_width * 0.5, stone.lightened(0.22), true, -1.0, true)
	draw_set_transform(Vector2(0.0, lift))
	draw_rect(Rect2(left, base_top + base_height * 0.5, base_width, base_height * 0.22), inlay_color)
	draw_line(Vector2(left, base_top + 1.0), Vector2(left + base_width, base_top + 1.0), stone_color.lightened(0.5), 2.0, true)
	if highlighted:
		draw_line(Vector2(left, base_top + 1.0), Vector2(left + base_width, base_top + 1.0), feedback, 3.0, true)

func _gui_input(event: InputEvent) -> void:
	# Touches arrive as emulated mouse clicks (Godot's default on mobile).
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(peg_index)
		accept_event()
