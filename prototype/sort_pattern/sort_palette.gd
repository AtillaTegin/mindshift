class_name SortPalette
extends RefCounted
## Disk colours of the colour-order prototype and the shape that goes with each
## (circle, square, triangle, diamond), so the colours stay readable for
## colour-blind players and on small screens. Game pieces: the same in light
## and dark mode, like ThemeManager.EXCHANGE_DISKS. Kept here, not in the
## ThemeManager, while the mechanic is a prototype.

const PIECES: Dictionary = {
	"red": {"fill": Color("e5484d"), "ink": Color("fff4f0")},
	"blue": {"fill": Color("3b7fd6"), "ink": Color("f2f7ff")},
	"yellow": {"fill": Color("f2c230"), "ink": Color("4a3a05")},
	"green": {"fill": Color("34a065"), "ink": Color("effcf3")},
}


static func fill(color_name: String) -> Color:
	return PIECES[color_name]["fill"]


static func ink(color_name: String) -> Color:
	return PIECES[color_name]["ink"]


## The colour's shape, centred on `center`, `radius` from centre to edge.
static func draw_symbol(canvas: CanvasItem, color_name: String, center: Vector2, radius: float, tint: Color) -> void:
	match color_name:
		"red":
			canvas.draw_circle(center, radius, tint)
		"blue":
			var side: float = radius * 1.7
			canvas.draw_rect(Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), tint)
		"yellow":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -radius * 1.1),
					center + Vector2(radius * 1.05, radius * 0.8), center + Vector2(-radius * 1.05, radius * 0.8)]), tint)
		"green":
			canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(0.0, -radius * 1.15),
					center + Vector2(radius * 1.0, 0.0), center + Vector2(0.0, radius * 1.15),
					center + Vector2(-radius * 1.0, 0.0)]), tint)


## A cross inside a `side`-sized square at `origin`.
static func draw_cross(canvas: CanvasItem, origin: Vector2, side: float, tint: Color) -> void:
	var width: float = maxf(side * 0.16, 2.0)
	canvas.draw_line(origin + Vector2(side * 0.2, side * 0.2), origin + Vector2(side * 0.8, side * 0.8), tint, width, true)
	canvas.draw_line(origin + Vector2(side * 0.8, side * 0.2), origin + Vector2(side * 0.2, side * 0.8), tint, width, true)


## A check mark inside a `side`-sized square at `origin`.
static func draw_check(canvas: CanvasItem, origin: Vector2, side: float, tint: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([origin + Vector2(side * 0.15, side * 0.55),
			origin + Vector2(side * 0.4, side * 0.8), origin + Vector2(side * 0.88, side * 0.22)])
	canvas.draw_polyline(points, tint, maxf(side * 0.16, 2.0), true)
