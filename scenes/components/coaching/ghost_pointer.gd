class_name GhostPointer
extends Control
## Imitates a fingertip: appears at one point, glides to another, "presses"
## there (scale down and up), fades out, and repeats until stopped.

const RADIUS: float = 26.0
const APPEAR_SECONDS: float = 0.2
const GLIDE_SECONDS: float = 0.7
const PRESS_SECONDS: float = 0.12
const PAUSE_SECONDS: float = 0.45

var _loop: Tween
var _from: Vector2
var _to: Vector2


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	size = Vector2(RADIUS, RADIUS) * 2.0
	pivot_offset = size * 0.5
	visible = false


## Repeats the gesture from `from` to `to` (viewport coordinates). With equal
## points it just taps there.
func play(from: Vector2, to: Vector2) -> void:
	stop()
	_from = from
	_to = to
	visible = true
	_loop = create_tween().set_loops()
	_loop.tween_callback(func() -> void:
		position = _from - size * 0.5
		scale = Vector2.ONE
		modulate.a = 0.0)
	_loop.tween_property(self, "modulate:a", 1.0, APPEAR_SECONDS)
	_loop.tween_property(self, "position", _to - size * 0.5, GLIDE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.tween_property(self, "scale", Vector2(0.75, 0.75), PRESS_SECONDS)
	_loop.tween_property(self, "scale", Vector2.ONE, PRESS_SECONDS)
	_loop.tween_property(self, "modulate:a", 0.0, APPEAR_SECONDS)
	_loop.tween_interval(PAUSE_SECONDS)


func stop() -> void:
	if _loop != null:
		_loop.kill()
		_loop = null
	visible = false


func is_playing() -> bool:
	return _loop != null


## [from, to] of the current gesture.
func get_gesture() -> Array[Vector2]:
	return [_from, _to]


func _draw() -> void:
	var center: Vector2 = size * 0.5
	draw_circle(center, RADIUS, Color(1, 1, 1, 0.85))
	draw_arc(center, RADIUS - 2.0, 0.0, TAU, 32, Color(0.17, 0.18, 0.26, 0.8), 4.0, true)
	draw_circle(center, RADIUS * 0.35, Color(0.17, 0.18, 0.26, 0.35))
