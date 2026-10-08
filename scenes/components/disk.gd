class_name DiskView
extends Control
## One disk: a rounded bar with its size number and a soft shadow underneath.
## Moves glide with a light bounce on landing. Position and size are set by
## the game board; input goes to the peg underneath.

const MOVE_SECONDS: float = 0.22
const SHADOW_OFFSET: Vector2 = Vector2(3.0, 5.0)

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
## Pinned by a rule (frozen disk): drawn with an ice rim and cracks, always,
## so the player sees it before trying to move it.
var frozen: bool = false:
	set(value):
		frozen = value
		queue_redraw()

const WOBBLE_SECONDS: float = 0.32
const WOBBLE_PIXELS: float = 7.0

var _move: Tween
var _wobble: Tween
## 0..1 while wobbling: how strongly the ice rim lights up.
var _ice_flash: float = 0.0:
	set(value):
		_ice_flash = value
		queue_redraw()

@onready var _shadow: Polygon2D = $Shadow


func _ready() -> void:
	_shadow.color = ThemeManager.color("shadow")
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


## "Cannot move" feedback for a frozen disk: a short sideways shake in place
## with the ice rim lighting up (ice blue, unlike the red illegal-move flash).
func wobble() -> void:
	if _wobble != null:
		_wobble.kill()
	var home: Vector2 = position
	_wobble = create_tween()
	_ice_flash = 1.0
	_wobble.parallel().tween_property(self, "_ice_flash", 0.0, WOBBLE_SECONDS)
	var step: float = WOBBLE_SECONDS / 5.0
	for offset: float in [WOBBLE_PIXELS, -WOBBLE_PIXELS, WOBBLE_PIXELS * 0.5, -WOBBLE_PIXELS * 0.5]:
		_wobble.tween_property(self, "position", home + Vector2(offset, 0.0), step).set_trans(Tween.TRANS_SINE)
	_wobble.tween_property(self, "position", home, step).set_trans(Tween.TRANS_SINE)


func is_wobbling() -> bool:
	return _wobble != null and _wobble.is_running()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_shadow.color = ThemeManager.color("shadow")


## Ice look: a frosted rim plus two small crack strokes at the ends.
func _draw_ice() -> void:
	var rim: StyleBoxFlat = StyleBoxFlat.new()
	rim.draw_center = false
	rim.set_corner_radius_all(int(_corner_radius()))
	rim.set_border_width_all(int(lerpf(4.0, 6.0, _ice_flash)))
	rim.border_color = ThemeManager.icon_color("ice_edge").lerp(ThemeManager.icon_color("ice"), _ice_flash)
	draw_style_box(rim, Rect2(Vector2.ZERO, size))
	var crack: Color = ThemeManager.icon_color("ice")
	var h: float = size.y
	for side: float in [1.0, -1.0]:
		var x: float = size.x * 0.5 + side * size.x * 0.32
		draw_polyline(PackedVector2Array([Vector2(x, h * 0.2), Vector2(x + side * h * 0.12, h * 0.45),
				Vector2(x - side * h * 0.05, h * 0.62), Vector2(x + side * h * 0.08, h * 0.82)]), crack, 2.0, true)


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
		box.border_color = ThemeManager.color("text_primary")
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if frozen:
		_draw_ice()
	var font: Font = get_theme_default_font()
	var font_size: int = int(clampf(size.y * 0.55, 12.0, 28.0))
	var text: String = str(disk_size)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeManager.color("text_on_disk"))
