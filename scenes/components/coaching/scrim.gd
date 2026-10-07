class_name Scrim
extends Control
## Dims the screen except an optional rectangular hole (the focus area).
## Purely visual: it never takes input. Coordinates are viewport coordinates.

const FADE_SECONDS: float = 0.2

var color: Color = Color(0.04, 0.04, 0.1, 0.6)
## Area left undimmed; an empty Rect2 dims everything.
var hole: Rect2 = Rect2():
	set(value):
		hole = value
		queue_redraw()

var _fade: Tween
## True between show_scrim() and hide_scrim(), fades included.
var _shown: bool = false


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	modulate.a = 0.0
	visible = false


## Fades in, leaving `focus_hole` clear.
func show_scrim(focus_hole: Rect2 = Rect2()) -> void:
	hole = focus_hole
	visible = true
	_shown = true
	_fade_to(1.0)


func hide_scrim() -> void:
	if _shown:
		_shown = false
		_fade_to(0.0, true)


func is_shown() -> bool:
	return _shown


func _fade_to(alpha: float, hide_after: bool = false) -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", alpha, FADE_SECONDS)
	if hide_after:
		_fade.tween_callback(func() -> void: visible = false)


func _draw() -> void:
	var full: Rect2 = Rect2(Vector2.ZERO, size)
	if not hole.has_area():
		draw_rect(full, color)
		return
	var cut: Rect2 = hole.intersection(full)
	# Four bands around the hole.
	draw_rect(Rect2(0, 0, size.x, cut.position.y), color)
	draw_rect(Rect2(0, cut.end.y, size.x, size.y - cut.end.y), color)
	draw_rect(Rect2(0, cut.position.y, cut.position.x, cut.size.y), color)
	draw_rect(Rect2(cut.end.x, cut.position.y, size.x - cut.end.x, cut.size.y), color)
