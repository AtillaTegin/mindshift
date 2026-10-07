class_name StarView
extends Control
## A five-pointed star, gold when earned and grey otherwise. Drawn as a polygon
## so it does not depend on a font having a star glyph.

const GOLD: Color = Color("f4b400")
const EMPTY: Color = Color("d6d1c4")

var filled: bool = false:
	set(value):
		filled = value
		queue_redraw()


## Outline of a star centred on `center`.
static func star_points(center: Vector2, outer_radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	var inner_radius: float = outer_radius * 0.45
	for i: int in 10:
		var radius: float = outer_radius if i % 2 == 0 else inner_radius
		var angle: float = -PI / 2.0 + i * PI / 5.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points


func _ready() -> void:
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _draw() -> void:
	var radius: float = minf(size.x, size.y) * 0.5
	draw_colored_polygon(star_points(size * 0.5, radius), GOLD if filled else EMPTY)
