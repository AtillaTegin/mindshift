class_name FocusRing
extends Control
## A glowing ring around a target rectangle that "breathes" (scale 0.9 -> 1.1).
## The ring is a capsule built from arcs, so it hugs wide disks and tall pegs
## alike. The only glowing element in the game.

const COLOR: Color = Color("ffd166")
const PADDING: float = 14.0
const WIDTH: float = 5.0
const BREATH_SECONDS: float = 0.8
const MOVE_SECONDS: float = 0.25

var _breath: Tween
var _move: Tween
var _target: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	visible = false


## Shows the ring around `target` (viewport coordinates); glides there if it
## is already visible.
func show_around(target: Rect2) -> void:
	_target = target
	var rect: Rect2 = target.grow(PADDING)
	if visible and _move_needed(rect):
		if _move != null:
			_move.kill()
		_move = create_tween().set_parallel()
		_move.tween_property(self, "position", rect.position, MOVE_SECONDS).set_trans(Tween.TRANS_SINE)
		_move.tween_property(self, "size", rect.size, MOVE_SECONDS).set_trans(Tween.TRANS_SINE)
	else:
		position = rect.position
		size = rect.size
	visible = true
	_start_breathing()


func hide_ring() -> void:
	visible = false
	if _breath != null:
		_breath.kill()
		_breath = null


## The rectangle the ring surrounds (or is gliding to), without padding.
func get_target() -> Rect2:
	return _target


func _move_needed(rect: Rect2) -> bool:
	return not position.is_equal_approx(rect.position) or not size.is_equal_approx(rect.size)


func _start_breathing() -> void:
	if _breath != null and _breath.is_running():
		return
	scale = Vector2.ONE
	_breath = create_tween().set_loops()
	_breath.tween_property(self, "scale", Vector2(1.1, 1.1), BREATH_SECONDS).set_trans(Tween.TRANS_SINE)
	_breath.tween_property(self, "scale", Vector2(0.9, 0.9), BREATH_SECONDS).set_trans(Tween.TRANS_SINE)


func _process(_delta: float) -> void:
	pivot_offset = size * 0.5


func _draw() -> void:
	# Soft glow: wider, fainter outlines under the main one.
	for layer: int in [3, 2, 1]:
		_draw_capsule(WIDTH + layer * 5.0, Color(COLOR, 0.12))
	_draw_capsule(WIDTH, COLOR)


func _draw_capsule(width: float, color: Color) -> void:
	var horizontal: bool = size.x >= size.y
	var radius: float = (size.y if horizontal else size.x) * 0.5
	var center: Vector2 = size * 0.5
	var half_length: float = maxf((size.x if horizontal else size.y) * 0.5 - radius, 0.0)
	var axis: Vector2 = Vector2.RIGHT if horizontal else Vector2.DOWN
	var normal: Vector2 = Vector2(-axis.y, axis.x)
	var start_cap: Vector2 = center - axis * half_length
	var end_cap: Vector2 = center + axis * half_length
	var base_angle: float = axis.angle()
	draw_arc(end_cap, radius, base_angle - PI / 2.0, base_angle + PI / 2.0, 24, color, width, true)
	draw_arc(start_cap, radius, base_angle + PI / 2.0, base_angle + PI * 1.5, 24, color, width, true)
	if half_length > 0.0:
		draw_line(start_cap + normal * radius, end_cap + normal * radius, color, width, true)
		draw_line(start_cap - normal * radius, end_cap - normal * radius, color, width, true)
