class_name GameIcons
extends RefCounted
## Code-drawn icons (economy/UX addendum 7), no image files. Each fits a
## square `rect` and uses the fixed ThemeManager.ICON_COLORS.
## - coin: a gold disc with a rim and a small shine stroke
## - hint: a light bulb (a circle on a narrowing base)
## - undo: a counter-clockwise curved arrow (a polyline with an arrowhead)

const KINDS: Array[String] = ["coin", "hint", "undo", "gift"]
## Alpha of an icon on a disabled button.
const DIMMED_ALPHA: float = 0.4


static func is_known(kind: String) -> bool:
	return KINDS.has(kind)


## Draws icon `kind` into `rect` on `canvas`. Unknown kinds draw nothing.
static func draw(canvas: CanvasItem, kind: String, rect: Rect2, dimmed: bool = false) -> void:
	var square: Rect2 = _square(rect)
	var alpha: float = DIMMED_ALPHA if dimmed else 1.0
	match kind:
		"coin":
			_draw_coin(canvas, square, alpha)
		"hint":
			_draw_hint(canvas, square, alpha)
		"undo":
			_draw_undo(canvas, square, alpha)
		"gift":
			_draw_gift(canvas, square, alpha)


static func _square(rect: Rect2) -> Rect2:
	var side: float = minf(rect.size.x, rect.size.y)
	return Rect2(rect.get_center() - Vector2(side, side) * 0.5, Vector2(side, side))


static func _color(role: String, alpha: float) -> Color:
	var tinted: Color = ThemeManager.icon_color(role)
	tinted.a *= alpha
	return tinted


static func _draw_coin(canvas: CanvasItem, square: Rect2, alpha: float) -> void:
	var center: Vector2 = square.get_center()
	var radius: float = square.size.x * 0.46
	canvas.draw_circle(center, radius, _color("coin_rim", alpha), true, -1.0, true)
	canvas.draw_circle(center, radius * 0.8, _color("coin", alpha), true, -1.0, true)
	# Shine: a short arc in the upper-left of the face.
	canvas.draw_arc(center, radius * 0.5, deg_to_rad(195.0), deg_to_rad(250.0), 8,
			_color("coin_shine", alpha), radius * 0.16, true)


static func _draw_hint(canvas: CanvasItem, square: Rect2, alpha: float) -> void:
	var s: float = square.size.x
	var center: Vector2 = square.get_center()
	var bulb_center: Vector2 = center + Vector2(0.0, -0.1 * s)
	var bulb_radius: float = 0.3 * s
	var base_color: Color = _color("hint_base", alpha)
	# Neck: a trapezoid narrowing from the bulb down to the screw.
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-0.19 * s, 0.08 * s), center + Vector2(0.19 * s, 0.08 * s),
		center + Vector2(0.11 * s, 0.3 * s), center + Vector2(-0.11 * s, 0.3 * s)]), _color("hint", alpha))
	canvas.draw_circle(bulb_center, bulb_radius, _color("hint", alpha), true, -1.0, true)
	# Screw base.
	canvas.draw_rect(Rect2(center + Vector2(-0.11 * s, 0.31 * s), Vector2(0.22 * s, 0.07 * s)), base_color)
	canvas.draw_rect(Rect2(center + Vector2(-0.08 * s, 0.4 * s), Vector2(0.16 * s, 0.06 * s)), base_color)
	# Small reflection.
	canvas.draw_arc(bulb_center, bulb_radius * 0.6, deg_to_rad(200.0), deg_to_rad(250.0), 6,
			_color("coin_shine", 0.8 * alpha), 0.05 * s, true)


## Gift (bonus levels): a box with a lid, a ribbon cross and a two-loop bow.
static func _draw_gift(canvas: CanvasItem, square: Rect2, alpha: float) -> void:
	var s: float = square.size.x
	var o: Vector2 = square.position
	var box: Color = _color("gift", alpha)
	var ribbon: Color = _color("gift_ribbon", alpha)
	canvas.draw_rect(Rect2(o + Vector2(0.14, 0.42) * s, Vector2(0.72, 0.48) * s), box)
	canvas.draw_rect(Rect2(o + Vector2(0.08, 0.3) * s, Vector2(0.84, 0.16) * s), box.lightened(0.15))
	canvas.draw_rect(Rect2(o + Vector2(0.44, 0.3) * s, Vector2(0.12, 0.6) * s), ribbon)
	canvas.draw_rect(Rect2(o + Vector2(0.08, 0.34) * s, Vector2(0.84, 0.07) * s), ribbon)
	for side: float in [-1.0, 1.0]:
		canvas.draw_circle(o + Vector2(0.5 + side * 0.13, 0.22) * s, 0.1 * s, ribbon, false, 0.05 * s, true)


static func _draw_undo(canvas: CanvasItem, square: Rect2, alpha: float) -> void:
	var s: float = square.size.x
	var center: Vector2 = square.get_center() + Vector2(0.03 * s, 0.06 * s)
	var radius: float = 0.3 * s
	var width: float = 0.1 * s
	var color: Color = _color("undo", alpha)
	# The arc runs counter-clockwise (on screen) from the right, over the top,
	# to the left, where the arrowhead points back down.
	var start_angle: float = deg_to_rad(40.0)
	var end_angle: float = deg_to_rad(-190.0)
	var points: PackedVector2Array = PackedVector2Array()
	var steps: int = 16
	for i: int in steps + 1:
		var angle: float = lerpf(start_angle, end_angle, float(i) / steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	canvas.draw_polyline(points, color, width, true)
	var tip_base: Vector2 = points[steps]
	# Direction of travel at the end of the arc (angle decreasing).
	var direction: Vector2 = Vector2(sin(end_angle), -cos(end_angle))
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	canvas.draw_colored_polygon(PackedVector2Array([
		tip_base + direction * 0.17 * s,
		tip_base + normal * 0.15 * s,
		tip_base - normal * 0.15 * s]), color)
