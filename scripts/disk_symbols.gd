class_name DiskSymbols
extends RefCounted
## The shape that goes with each disk colour of a "Birləşmə Tapmacası" level
## (red circle, blue square, yellow triangle, green diamond, purple star,
## orange hexagon, pink cross), drawn on the disk instead of a size number:
## those disks all have one size, and the shapes keep the colours apart for
## colour-blind players and on small screens.


## Draws the shape of `color_name` centred on `center`; `radius` is the
## distance from the centre to its edge.
static func draw(canvas: CanvasItem, color_name: String, center: Vector2, radius: float, tint: Color) -> void:
	match color_name:
		"red":
			canvas.draw_circle(center, radius, tint, true, -1.0, true)
		"blue":
			var side: float = radius * 1.7
			canvas.draw_rect(Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), tint)
		"yellow":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -radius * 1.1),
					center + Vector2(radius * 1.05, radius * 0.8), center + Vector2(-radius * 1.05, radius * 0.8)]), tint)
		"green":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -radius * 1.15),
					center + Vector2(radius, 0.0), center + Vector2(0.0, radius * 1.15), center + Vector2(-radius, 0.0)]), tint)
		"purple":
			canvas.draw_colored_polygon(_star(center, radius * 1.2, radius * 0.5, 5), tint)
		"orange":
			canvas.draw_colored_polygon(_star(center, radius * 1.05, radius * 1.05, 3), tint)
		"pink":
			var arm: float = radius * 0.38
			canvas.draw_rect(Rect2(center - Vector2(radius, arm), Vector2(radius * 2.0, arm * 2.0)), tint)
			canvas.draw_rect(Rect2(center - Vector2(arm, radius), Vector2(arm * 2.0, radius * 2.0)), tint)


## A star of `points` points (with inner == outer radius: a 2*points-gon).
static func _star(center: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var polygon: PackedVector2Array = PackedVector2Array()
	for i: int in points * 2:
		var angle: float = -PI / 2.0 + i * PI / points
		polygon.append(center + Vector2(cos(angle), sin(angle)) * (outer if i % 2 == 0 else inner))
	return polygon


## A check mark inside a `side`-sized square at `origin` (a finished part of a
## colour goal).
static func draw_check(canvas: CanvasItem, origin: Vector2, side: float, tint: Color) -> void:
	canvas.draw_polyline(PackedVector2Array([origin + Vector2(side * 0.15, side * 0.55),
			origin + Vector2(side * 0.4, side * 0.8), origin + Vector2(side * 0.88, side * 0.22)]), tint,
			maxf(side * 0.16, 2.0), true)
