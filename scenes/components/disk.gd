class_name DiskView
extends Control
## One disk: a rounded bar with its size number and a soft shadow underneath.
## Moves glide with a light bounce on landing. Position and size are set by
## the game board; input goes to the peg underneath.

const MOVE_SECONDS: float = 0.22
const SHADOW_OFFSET: Vector2 = Vector2(3.0, 5.0)
const SHADOW_COLOR: Color = Color(0.1, 0.1, 0.15, 0.18)

var disk_size: int = 1:
	set(value):
		disk_size = value
		queue_redraw()
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _move: Tween

@onready var _shadow: Polygon2D = $Shadow


func _ready() -> void:
	_shadow.color = SHADOW_COLOR
	_shadow.position = SHADOW_OFFSET
	resized.connect(_update_shadow)
	_update_shadow()


## Moves the disk to `target` (top-left corner); with `animated` it glides there
## and settles with a small bounce (TRANS_BACK, EASE_OUT).
func move_to(target: Vector2, animated: bool) -> void:
	if _move != null:
		_move.kill()
		_move = null
	if not animated or position.distance_to(target) < 0.5:
		position = target
		return
	_move = create_tween()
	_move.tween_property(self, "position", target, MOVE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _corner_radius() -> float:
	return minf(size.y, size.x) * 0.45


## The shadow is the disk's own rounded outline, drawn behind and a little lower.
func _update_shadow() -> void:
	var radius: float = _corner_radius()
	var points: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [
		Vector2(size.x - radius, radius), Vector2(size.x - radius, size.y - radius),
		Vector2(radius, size.y - radius), Vector2(radius, radius)]
	for corner_index: int in corners.size():
		var start_angle: float = -PI / 2.0 + corner_index * PI / 2.0
		for step: int in 7:
			var angle: float = start_angle + step * (PI / 2.0) / 6.0
			points.append(corners[corner_index] + Vector2(cos(angle), sin(angle)) * radius)
	_shadow.polygon = points


func _draw() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color.lightened(0.15) if selected else color
	box.set_corner_radius_all(int(_corner_radius()))
	if selected:
		box.set_border_width_all(4)
		box.border_color = UIPalette.TEXT_PRIMARY
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var font: Font = get_theme_default_font()
	var font_size: int = int(clampf(size.y * 0.55, 12.0, 28.0))
	var text: String = str(disk_size)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UIPalette.TEXT_PRIMARY)
