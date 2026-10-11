class_name GameIcons
extends RefCounted
## Code-drawn icons (economy/UX addendum 7), no image files. Each fits a
## square `rect` and uses the fixed ThemeManager.ICON_COLORS.
## - coin: a gold disc with a rim and a small shine stroke
## - hint: a light bulb (a circle on a narrowing base)
## - undo: a counter-clockwise curved arrow (a polyline with an arrowhead)
## - chest: a wooden chest with metal bands and a lock plate (chest meter)
## - key: a ring, a shaft and two teeth (chest meter)

const KINDS: Array[String] = ["coin", "hint", "undo", "chest", "key"]
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
		"chest":
			_draw_chest(canvas, square, alpha)
		"key":
			_draw_key(canvas, square, alpha)


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


static func _draw_chest(canvas: CanvasItem, square: Rect2, alpha: float) -> void:
	var s: float = square.size.x
	var o: Vector2 = square.position
	var wood: Color = _color("chest", alpha)
	var band: Color = _color("chest_band", alpha)
	var lid: StyleBoxFlat = StyleBoxFlat.new()
	lid.bg_color = wood.lightened(0.12)
	lid.corner_radius_top_left = int(0.16 * s)
	lid.corner_radius_top_right = int(0.16 * s)
	canvas.draw_style_box(lid, Rect2(o + Vector2(0.08, 0.18) * s, Vector2(0.84, 0.26) * s))
	canvas.draw_rect(Rect2(o + Vector2(0.08, 0.46) * s, Vector2(0.84, 0.42) * s), wood)
	for x: float in [0.2, 0.73]:
		canvas.draw_rect(Rect2(o + Vector2(x, 0.18) * s, Vector2(0.07, 0.7) * s), band)
	canvas.draw_rect(Rect2(o + Vector2(0.42, 0.38) * s, Vector2(0.16, 0.18) * s), band)


static func _draw_key(canvas: CanvasItem, square: Rect2, alpha: float) -> void:
	var s: float = square.size.x
	var o: Vector2 = square.position
	var gold: Color = _color("key", alpha)
	canvas.draw_arc(o + Vector2(0.28, 0.5) * s, 0.16 * s, 0.0, TAU, 20, gold, 0.08 * s, true)
	canvas.draw_line(o + Vector2(0.43, 0.5) * s, o + Vector2(0.9, 0.5) * s, gold, 0.09 * s, true)
	canvas.draw_rect(Rect2(o + Vector2(0.7, 0.5) * s, Vector2(0.07, 0.16) * s), gold)
	canvas.draw_rect(Rect2(o + Vector2(0.82, 0.5) * s, Vector2(0.07, 0.12) * s), gold)
