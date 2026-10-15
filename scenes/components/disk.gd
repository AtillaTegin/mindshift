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
## The number shown when it is not disk_size (a great exchange disk shows its
## size, while its id also tells its colour); 0 for disk_size.
var label: int = 0:
	set(value):
		label = value
		queue_redraw()
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
## Colour of the size number; the theme's `text_on_disk` when not set (a dark
## caravan disk of a great exchange needs a light number).
var number_color: Variant = null:
	set(value):
		number_color = value
		queue_redraw()
## A thin outline (the light caravan of a great exchange on sand), or null.
var outline_color: Variant = null:
	set(value):
		outline_color = value
		queue_redraw()
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
## Free to move right now under a rule that looks at the last move (the Nine
## Rings alternation): drawn with a ring in `ring_color`, so the player sees
## which disks may go before trying.
var movable_ring: bool = false:
	set(value):
		movable_ring = value
		queue_redraw()
var ring_color: Color = Color.WHITE:
	set(value):
		ring_color = value
		queue_redraw()
## A glass disk (karakuri wave "Şüşə disk"): see-through with a light glint,
## and drawn above the boxes, so it shows even inside a closed one.
var glass: bool = false:
	set(value):
		glass = value
		z_index = 1 if glass else 0
		queue_redraw()
const GLASS_ALPHA: float = 0.55
const WOBBLE_SECONDS: float = 0.32
const WOBBLE_PIXELS: float = 7.0

var _move: Tween
var _wobble: Tween
## 0..1 while wobbling: how strongly the rim lights up.
var _flash: float = 0.0:
	set(value):
		_flash = value
		queue_redraw()

@onready var _shadow: Polygon2D = $Shadow


func _ready() -> void:
	_shadow.color = ThemeManager.color("shadow")
	_shadow.position = SHADOW_OFFSET
	_shadow.visible = not glass
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


## "Not now" feedback for a disk a rule holds back: a short sideways shake in
## place with a soft grey rim (no red: nothing is punished).
func wobble() -> void:
	if _wobble != null:
		_wobble.kill()
	var home: Vector2 = position
	_wobble = create_tween()
	_flash = 1.0
	_wobble.parallel().tween_property(self, "_flash", 0.0, WOBBLE_SECONDS)
	var step: float = WOBBLE_SECONDS / 5.0
	for offset: float in [WOBBLE_PIXELS, -WOBBLE_PIXELS, WOBBLE_PIXELS * 0.5, -WOBBLE_PIXELS * 0.5]:
		_wobble.tween_property(self, "position", home + Vector2(offset, 0.0), step).set_trans(Tween.TRANS_SINE)
	_wobble.tween_property(self, "position", home, step).set_trans(Tween.TRANS_SINE)


func is_wobbling() -> bool:
	return _wobble != null and _wobble.is_running()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_shadow.color = ThemeManager.color("shadow")


func _draw_rim(rim_color: Color, width: float) -> void:
	var rim: StyleBoxFlat = StyleBoxFlat.new()
	rim.draw_center = false
	rim.set_corner_radius_all(int(_corner_radius()))
	rim.set_border_width_all(int(width))
	rim.border_color = rim_color
	draw_style_box(rim, Rect2(Vector2.ZERO, size))

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
	if glass:
		box.bg_color.a = GLASS_ALPHA
		box.set_border_width_all(2)
		box.border_color = color.lightened(0.5)
	box.set_corner_radius_all(int(_corner_radius()))
	if selected:
		box.set_border_width_all(4)
		box.border_color = ThemeManager.color("text_primary")
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if glass:
		# A glint across the top, as on glass.
		var glint: Color = color.lightened(0.8)
		glint.a = 0.7
		draw_line(Vector2(_corner_radius(), size.y * 0.25), Vector2(size.x * 0.45, size.y * 0.25), glint, 2.0, true)
	if outline_color != null:
		_draw_rim(outline_color, 2.0)
	if movable_ring:
		_draw_rim(ring_color, 4.0)
	if _flash > 0.0:
		var soft: Color = ThemeManager.color("text_secondary")
		soft.a = _flash
		_draw_rim(soft, 5.0)
	var ink: Color = number_color if number_color != null else ThemeManager.color("text_on_disk")
	var font: Font = get_theme_default_font()
	var font_size: int = int(clampf(size.y * 0.55, 12.0, 28.0))
	var text: String = str(label if label > 0 else disk_size)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
