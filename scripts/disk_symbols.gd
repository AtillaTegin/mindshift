class_name DiskSymbols
extends RefCounted
## The shape that goes with each disk colour of a "Birləşmə Tapmacası" level
## (red circle, blue square, yellow triangle, green diamond), drawn on the disk
## instead of a size number: those disks all have one size, and the shapes keep
## the colours apart for colour-blind players and on small screens.


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


## A check mark inside a `side`-sized square at `origin` (a finished part of a
## colour goal).
static func draw_check(canvas: CanvasItem, origin: Vector2, side: float, tint: Color) -> void:
	canvas.draw_polyline(PackedVector2Array([origin + Vector2(side * 0.15, side * 0.55),
			origin + Vector2(side * 0.4, side * 0.8), origin + Vector2(side * 0.88, side * 0.22)]), tint,
			maxf(side * 0.16, 2.0), true)
