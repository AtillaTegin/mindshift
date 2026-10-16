class_name BoardSkin
extends Control
## The dress behind the board of a level with a special mechanic (level
## structure addendum v3, section 3): a rounded panel in the skin's board
## colour with a code-drawn pattern, no textures. Draws nothing for classic
## levels. Purely visual: it ignores the mouse and knows nothing of the rules.
##   jade: soft jade veins under the nine rings on their bar, after the
##         Chinese Nine Rings puzzle
##   wood: wavy wood grain under a band of yosegi marquetry diamonds, after
##         Japanese karakuri puzzle boxes
##   caravan: sand dunes, and under every peg a small caravanserai on a dashed
##         road that links each stop only to its neighbours (the caravan
##         road's rule); the board keeps bottom_room() free for them
##   temple: sandstone courses with a gold band (unequal capacity, the Brahma
##         temple's towers of different heights)
##   stone: large ashlar blocks on a foundation course (the foundation stone)
##   scales: a market stall's planks; the balance scales themselves are their
##         own component (BalanceScale) in the room kept under the pegs
##   zodiac: a night dial of twelve marks around the circle of pegs, with a
##         clockwise arrow in the middle (the cyclic rule)
##   stripes: soft diagonal barber-pole stripes
##   chain: a row of chain links along the top
##   mirror: a mirror line between the two boards
##   trail: sand ripples and, under each peg the trail disk has stood on, a
##         pair of footprints (marks "visited")

## How far the panel reaches past the board on every side.
const BLEED: float = 12.0
const RADIUS: int = 24

## Height kept free under the pegs for the caravanserais.
const CARAVAN_ROOM: float = 44.0
## Height kept free under the pegs for the footprints (the scales keep
## BalanceScale.ROOM).
const TRAIL_ROOM: float = 30.0

## Pegs on the board (the caravan road draws a stop under each).
var peg_count: int = 3:
	set(value):
		peg_count = value
		queue_redraw()
## ThemeManager.SKINS key, "" for none.
var skin: String = "":
	set(value):
		skin = value
		queue_redraw()
## Each peg's cell on the board and the y (inside a cell) of the bottom of its
## base, from the board's last layout pass (set_cells); empty before it.
var cells: Array[Rect2] = []
var base_bottom: float = 0.0
## What the position adds to the dress (BoardDress.skin_marks), e.g. the
## beams of the scales or the footprints of the trail.
var marks: Dictionary = {}:
	set(value):
		marks = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.theme_changed.connect(func(_mode: String) -> void: queue_redraw())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Height the board leaves free under its pegs for this dress.
func bottom_room() -> float:
	match skin:
		"caravan":
			return CARAVAN_ROOM
		"scales":
			return BalanceScale.ROOM
		"trail":
			return TRAIL_ROOM
	return 0.0


## Where the pegs stand now (board coordinates) and where their bases end.
func set_cells(p_cells: Array[Rect2], p_base_bottom: float) -> void:
	cells = p_cells.duplicate()
	base_bottom = p_base_bottom
	queue_redraw()


## The x of the middle of peg `peg_index` (an even spread before the first layout).
func peg_x(peg_index: int) -> float:
	if peg_index < cells.size():
		return cells[peg_index].get_center().x
	return size.x / maxi(peg_count, 1) * (peg_index + 0.5)


## The area the panel covers, in local coordinates.
func get_panel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(BLEED)


func _draw() -> void:
	if skin.is_empty():
		return
	var area: Rect2 = get_panel_rect()
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = ThemeManager.skin_color(skin, "board")
	panel.set_corner_radius_all(RADIUS)
	draw_style_box(panel, area)
	var inner: Rect2 = area.grow(-float(RADIUS) * 0.5)
	match skin:
		"jade":
			_draw_jade(inner)
		"wood":
			_draw_wood(inner)
		"caravan":
			_draw_caravan(inner)
		"temple":
			_draw_courses(inner, 26.0, 0.5)
			_draw_band(inner)
		"stone":
			_draw_courses(inner, 48.0, 0.38)
		"scales":
			_draw_planks(inner)
		"zodiac":
			_draw_dial()
		"stripes":
			_draw_stripes(inner)
		"chain":
			_draw_chain_band(inner)
		"mirror":
			_draw_mirror_line(inner)
		"trail":
			_draw_ripples(inner)
			_draw_footprints()


## Masonry: courses `course` high, the joints of every other course shifted by
## `shift` of a block (a block is twice as long as high).
func _draw_courses(area: Rect2, course: float, shift: float) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var y: float = area.position.y + course
	var row: int = 0
	while y < area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), line, 2.0, true)
		var block: float = course * 2.0
		var x: float = area.position.x + (block * shift if row % 2 == 1 else 0.0)
		while x < area.end.x:
			draw_line(Vector2(x, y - course), Vector2(x, y), line, 2.0, true)
			x += block
		y += course
		row += 1


## A gold band with small studs along the top.
func _draw_band(area: Rect2) -> void:
	var gold: Color = ThemeManager.skin_color(skin, "mark")
	draw_rect(Rect2(area.position, Vector2(area.size.x, 8.0)), gold)
	var x: float = area.position.x + 14.0
	while x < area.end.x:
		draw_circle(Vector2(x, area.position.y + 16.0), 3.0, gold, true, -1.0, true)
		x += 28.0


func _draw_planks(area: Rect2) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var y: float = area.position.y + 34.0
	while y < area.end.y:
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), line, 3.0, true)
		y += 34.0


## Twelve marks on a circle through the pegs, and a clockwise arrow in the
## room the pegs leave free (BoardLayout.circle_center).
func _draw_dial() -> void:
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var middle: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	draw_arc(middle, radius, 0.0, TAU, 72, line, 3.0, true)
	for i: int in 12:
		var angle: float = TAU * i / 12.0
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(middle + direction * (radius - 10.0), middle + direction * (radius + 6.0), line, 3.0, true)
	var center: Vector2 = BoardLayout.circle_center(cells, size) if not cells.is_empty() else middle
	var arrow: float = size.x * 0.055
	draw_arc(center, arrow, -PI * 0.5, PI * 1.1, 32, mark, 5.0, true)
	var tip: Vector2 = center + Vector2(cos(PI * 1.1), sin(PI * 1.1)) * arrow
	var along: Vector2 = Vector2(-sin(PI * 1.1), cos(PI * 1.1))
	var side: Vector2 = Vector2(cos(PI * 1.1), sin(PI * 1.1))
	draw_colored_polygon(PackedVector2Array([tip + along * 12.0, tip + side * 9.0 - along * 4.0, tip - side * 9.0 - along * 4.0]), mark)


## Diagonal stripes, cut to the panel's inner area.
func _draw_stripes(area: Rect2) -> void:
	var stripe: Color = ThemeManager.skin_color(skin, "pattern")
	var width: float = 22.0
	var bounds: PackedVector2Array = PackedVector2Array([area.position, Vector2(area.end.x, area.position.y), area.end,
			Vector2(area.position.x, area.end.y)])
	var x: float = area.position.x - area.size.y
	while x < area.end.x:
		var band: PackedVector2Array = PackedVector2Array([Vector2(x, area.end.y), Vector2(x + width, area.end.y),
				Vector2(x + width + area.size.y * 0.6, area.position.y), Vector2(x + area.size.y * 0.6, area.position.y)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(band, bounds):
			draw_colored_polygon(piece, stripe)
		x += width * 3.0


func _draw_chain_band(area: Rect2) -> void:
	var link: Color = ThemeManager.skin_color(skin, "mark")
	var x: float = area.position.x + 16.0
	var index: int = 0
	while x < area.end.x - 10.0:
		var center: Vector2 = Vector2(x, area.position.y + 14.0)
		if index % 2 == 0:
			draw_arc(center, 9.0, 0.0, TAU, 16, link, 3.0, true)
		else:
			draw_line(center - Vector2(9.0, 0.0), center + Vector2(9.0, 0.0), link, 3.0, true)
		x += 16.0
		index += 1


## A line with a diamond in its middle where the first board's row ends.
func _draw_mirror_line(area: Rect2) -> void:
	if cells.is_empty():
		return
	# Just below the first board's bases.
	var y: float = cells[0].end.y + 10.0
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	draw_line(Vector2(area.position.x + 10.0, y), Vector2(area.end.x - 10.0, y), mark, 3.0, true)
	var middle: Vector2 = Vector2(area.get_center().x, y)
	draw_colored_polygon(PackedVector2Array([middle + Vector2(0.0, -9.0), middle + Vector2(9.0, 0.0),
			middle + Vector2(0.0, 9.0), middle + Vector2(-9.0, 0.0)]), mark)


func _draw_ripples(area: Rect2) -> void:
	var ripple: Color = ThemeManager.skin_color(skin, "pattern")
	var y: float = area.position.y + 36.0
	var row: int = 0
	while y < area.end.y - TRAIL_ROOM:
		var points: PackedVector2Array = PackedVector2Array()
		var x: float = area.position.x
		while x <= area.end.x:
			points.append(Vector2(x, y + sin(x * 0.02 + row * 1.3) * 5.0))
			x += 14.0
		draw_polyline(points, ripple, 2.0, true)
		y += 30.0
		row += 1


## Two footprints under each peg the trail disk has visited.
func _draw_footprints() -> void:
	var foot: Color = ThemeManager.mark_color("footprint")
	for peg_index: int in marks.get("visited", []):
		var bottom: Vector2 = Vector2(peg_x(peg_index), size.y - TRAIL_ROOM * 0.5)
		for side: float in [-1.0, 1.0]:
			var center: Vector2 = bottom + Vector2(side * 8.0, side * 4.0)
			draw_set_transform(center, 0.0, Vector2(0.6, 1.0))
			draw_circle(Vector2.ZERO, 7.0, foot, true, -1.0, true)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_jade(area: Rect2) -> void:
	var vein: Color = ThemeManager.skin_color(skin, "pattern")
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	# A few long, soft veins, like polished jade.
	for i: int in 4:
		var points: PackedVector2Array = PackedVector2Array()
		var base_y: float = area.position.y + area.size.y * (0.22 + i * 0.2)
		var x: float = area.position.x
		while x <= area.end.x:
			points.append(Vector2(x, base_y + sin(x * 0.011 + i * 2.1) * 18.0 + sin(x * 0.027 + i) * 7.0))
			x += 12.0
		draw_polyline(points, vein, 3.0, true)
	# The nine rings hanging from their bar along the top.
	var bar_y: float = area.position.y + 10.0
	draw_line(Vector2(area.position.x + 14.0, bar_y), Vector2(area.end.x - 14.0, bar_y), mark, 4.0, true)
	var spacing: float = (area.size.x - 64.0) / 8.0
	for i: int in 9:
		var center: Vector2 = Vector2(area.position.x + 32.0 + i * spacing, bar_y + 22.0)
		draw_line(Vector2(center.x, bar_y), center - Vector2(0.0, 12.0), mark, 3.0, true)
		draw_arc(center, 12.0, 0.0, TAU, 24, mark, 3.0, true)

func _draw_wood(area: Rect2) -> void:
	var grain: Color = ThemeManager.skin_color(skin, "pattern")
	var band: float = 26.0
	var y: float = area.position.y + band + 18.0
	var line: int = 0
	while y < area.end.y - 6.0:
		var points: PackedVector2Array = PackedVector2Array()
		var x: float = area.position.x
		while x <= area.end.x:
			points.append(Vector2(x, y + sin(x * 0.018 + line * 1.3) * 4.0))
			x += 14.0
		draw_polyline(points, grain, 2.0, true)
		y += 24.0
		line += 1
	# Yosegi band along the top: diamonds in two woods.
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	var width: float = band * 1.2
	var left: float = area.position.x
	var index: int = 0
	while left + width <= area.end.x:
		var top: Vector2 = Vector2(left + width * 0.5, area.position.y)
		draw_colored_polygon(PackedVector2Array([top, Vector2(left + width, top.y + band * 0.5),
				Vector2(top.x, top.y + band), Vector2(left, top.y + band * 0.5)]), mark if index % 2 == 0 else grain)
		left += width
		index += 1

func _draw_caravan(area: Rect2) -> void:
	var dune: Color = ThemeManager.skin_color(skin, "pattern")
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	# Soft dunes: long, shallow waves.
	var y: float = area.position.y + 40.0
	var row: int = 0
	while y < area.end.y - CARAVAN_ROOM - 10.0:
		var points: PackedVector2Array = PackedVector2Array()
		var x: float = area.position.x
		while x <= area.end.x:
			points.append(Vector2(x, y + sin(x * 0.01 + row * 1.7) * 9.0))
			x += 16.0
		draw_polyline(points, dune, 3.0, true)
		y += 46.0
		row += 1
	# The road: a stop under every peg, each linked only to its neighbours.
	var road_y: float = size.y - CARAVAN_ROOM * 0.32
	for i: int in peg_count - 1:
		var from: Vector2 = Vector2(peg_x(i) + 22.0, road_y)
		var to: Vector2 = Vector2(peg_x(i + 1) - 22.0, road_y)
		var travelled: float = 0.0
		var length: float = from.distance_to(to)
		while travelled < length:
			draw_line(from + Vector2(travelled, 0.0), from + Vector2(minf(travelled + 10.0, length), 0.0), mark, 4.0, true)
			travelled += 18.0
	for i: int in peg_count:
		_draw_caravanserai(Vector2(peg_x(i), size.y - 4.0), mark, dune)


## A small caravanserai seen from the front: a flat-roofed wall with an arched
## gate. `bottom` is the middle of its base.
func _draw_caravanserai(bottom: Vector2, wall: Color, gate: Color) -> void:
	var width: float = 40.0
	var height: float = 26.0
	draw_rect(Rect2(bottom + Vector2(-width * 0.5, -height), Vector2(width, height)), wall)
	draw_rect(Rect2(bottom + Vector2(-width * 0.5 - 3.0, -height - 4.0), Vector2(width + 6.0, 5.0)), wall.darkened(0.2))
	var door: Vector2 = bottom + Vector2(0.0, -9.0)
	draw_rect(Rect2(door + Vector2(-7.0, 0.0), Vector2(14.0, 9.0)), gate)
	draw_circle(door, 7.0, gate, true, -1.0, true)
