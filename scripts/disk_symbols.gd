class_name DiskSymbols
extends RefCounted
## The pips that go with each disk colour of a "Birləşmə Tapmacası" level
## (correction v3, section 5): domino-style dots, drawn on the disk instead of
## a size number (those disks all have one size). Colour number k (its place in
## ColorGoal.LETTERS) shows k pips in the dice layout for k <= 6; past six it
## shows two groups like a domino tile, six pips | k - 6 pips with a line
## between, so no two colours share a pattern. They keep the colours apart for
## colour-blind players and on small screens.


## The pip count of `color_name` (1 for the first colour of ColorGoal.LETTERS).
static func pips_of(color_name: String) -> int:
	return ColorGoal.LETTERS.keys().find(color_name) + 1


## Draws the pips of `color_name` centred on `center`; `radius` is half the
## height they may take.
static func draw(canvas: CanvasItem, color_name: String, center: Vector2, radius: float, tint: Color) -> void:
	var pips: int = pips_of(color_name)
	var side: float = radius * 2.0
	if pips <= 6:
		_draw_face(canvas, pips, center, side, tint)
		return
	var gap: float = side * 0.35
	var left: Vector2 = center - Vector2((side + gap) * 0.5, 0.0)
	var right: Vector2 = center + Vector2((side + gap) * 0.5, 0.0)
	_draw_face(canvas, 6, left, side, tint)
	_draw_face(canvas, pips - 6, right, side, tint)
	canvas.draw_line(center - Vector2(0.0, side * 0.5), center + Vector2(0.0, side * 0.5), tint, maxf(side * 0.07, 1.0), true)


## Width the pips of `color_name` take for a given `radius` (two faces past six).
static func width_of(color_name: String, radius: float) -> float:
	return radius * 2.0 if pips_of(color_name) <= 6 else radius * 4.7


## One dice face of `count` (1-6) pips in a `side`-sized square at `center`.
static func _draw_face(canvas: CanvasItem, count: int, center: Vector2, side: float, tint: Color) -> void:
	var d: float = side * 0.32
	var spots: Array[Vector2] = []
	match count:
		1:
			spots = [Vector2.ZERO]
		2:
			spots = [Vector2(-d, -d), Vector2(d, d)]
		3:
			spots = [Vector2(-d, -d), Vector2.ZERO, Vector2(d, d)]
		4:
			spots = [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)]
		5:
			spots = [Vector2(-d, -d), Vector2(d, -d), Vector2.ZERO, Vector2(-d, d), Vector2(d, d)]
		_:
			spots = [Vector2(-d, -d), Vector2(-d, 0.0), Vector2(-d, d), Vector2(d, -d), Vector2(d, 0.0), Vector2(d, d)]
	var pip: float = maxf(side * 0.13, 1.5)
	for spot: Vector2 in spots:
		canvas.draw_circle(center + spot, pip, tint, true, -1.0, true)


## A check mark inside a `side`-sized square at `origin` (a finished part of a
## colour goal).
static func draw_check(canvas: CanvasItem, origin: Vector2, side: float, tint: Color) -> void:
	canvas.draw_polyline(PackedVector2Array([origin + Vector2(side * 0.15, side * 0.55),
			origin + Vector2(side * 0.4, side * 0.8), origin + Vector2(side * 0.88, side * 0.22)]), tint,
			maxf(side * 0.16, 2.0), true)
