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
##   palace: crimson silk with gold lozenges (the king's palace; the gates are
##         drawn over the pegs, BoardMarks)
##   river: grassy banks and the river between them, its waves flowing (marks
##         "river": the banks, a ferry boat, stone bridges, fords with their
##         sizes, or a bonfire in the river's place)

## How far the panel reaches past the board on every side.
const BLEED: float = 12.0
const RADIUS: int = 24

## Height kept free under the pegs for the caravanserais.
const CARAVAN_ROOM: float = 44.0
## Height kept free under the pegs for the footprints (the scales keep
## BalanceScale.ROOM).
const TRAIL_ROOM: float = 30.0
## Height kept free under the pegs for the carpet's medallions.
const CARPET_ROOM: float = 40.0
## Height kept free under the pegs for Cəm's numbers.
const SUM_ROOM: float = 48.0

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
## Seconds the river's waves (or the bonfire's flames) have flowed.
var _time: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.theme_changed.connect(func(_mode: String) -> void: queue_redraw())


func _process(delta: float) -> void:
	if skin == "river":
		_time += delta
		queue_redraw()


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
		"carpet":
			return CARPET_ROOM
		"abacus":
			return SUM_ROOM
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
		"palace":
			_draw_lozenges(inner)
			_draw_band(inner)
		"river":
			_draw_river(inner)
		"carpet":
			_draw_carpet(inner)
		"goban":
			_draw_goban(inner)
		"quarry":
			_draw_quarry(inner)
		"wuxing":
			_draw_wuxing(inner)
		"abacus":
			_draw_abacus(inner)
		"marble", "lacquer", "night", "felt":
			_draw_grain(inner)


## Cəm: under each peg its sum now over the one it must reach ("=" when all
## must be equal; "tək"/"cüt" marks for parity), green once it is met; a
## doubled peg shows "x2"; with counts, the count too.
func _draw_abacus(area: Rect2) -> void:
	_draw_grain(area)
	var sums: Dictionary = marks.get("sums", {})
	var targets: Array = sums.get("targets", [])
	var now: Array = sums.get("now", [])
	var counts: Array = sums.get("counts", [])
	var count_now: Array = sums.get("count_now", [])
	var parity: Array = sums.get("parity", [])
	var font: Font = get_theme_default_font()
	var y: float = size.y - SUM_ROOM * 0.55
	for peg_index: int in mini(now.size(), peg_count):
		var current: int = now[peg_index]
		var aim: String = "="
		var met: bool = false
		if peg_index < targets.size() and int(targets[peg_index]) >= 0:
			aim = str(targets[peg_index])
			met = current == int(targets[peg_index])
		elif peg_index < parity.size() and int(parity[peg_index]) > 0:
			aim = tr("ODD_PEG") if int(parity[peg_index]) == 1 else tr("EVEN_PEG")
			met = current % 2 == int(parity[peg_index]) % 2
		elif sums.get("fair", false):
			met = now.all(func(value: int) -> bool: return value == int(now[0]))
		var text: String = "%d / %s" % [current, aim]
		if peg_index == int(sums.get("double", -1)):
			text += " ×2"
		if peg_index < counts.size():
			text += "  (%d/%d)" % [count_now[peg_index], counts[peg_index]]
		var color: Color = ThemeManager.mark_color("sum_met") if met else ThemeManager.mark_color("sum_target")
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(peg_x(peg_index) - width * 0.5, y + 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, color)


## A faint grain for the plain boards of World 8-9 (marble veins, lacquer,
## night, felt).
func _draw_grain(area: Rect2) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var y: float = area.position.y + 28.0
	var row: int = 0
	while y < area.end.y:
		var points: PackedVector2Array = PackedVector2Array()
		var x: float = area.position.x
		while x <= area.end.x:
			points.append(Vector2(x, y + sin(x * 0.015 + row * 2.3) * 6.0))
			x += 16.0
		draw_polyline(points, line, 2.0, true)
		y += 52.0
		row += 1


## Ağır Disk: a measuring track under the pegs, a tick at every peg; a slope
## rising to the right when uphill; the cart under its peg.
func _draw_quarry(area: Rect2) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	var quarry: Dictionary = marks.get("quarry", {})
	if quarry.get("uphill", false):
		draw_colored_polygon(PackedVector2Array([Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y),
				Vector2(area.end.x, area.position.y + area.size.y * 0.45)]), ThemeManager.mark_color("slope"))
	var y: float = (cells[0].end.y + 10.0) if not cells.is_empty() else size.y - 10.0
	draw_line(Vector2(area.position.x + 10.0, y), Vector2(area.end.x - 10.0, y), mark, 3.0, true)
	for peg_index: int in peg_count:
		draw_line(Vector2(peg_x(peg_index), y - 7.0), Vector2(peg_x(peg_index), y + 7.0), mark, 3.0, true)
	var cart: int = quarry.get("cart", -1)
	if cart >= 0 and cart < peg_count:
		var bottom: Vector2 = Vector2(peg_x(cart), y - 12.0)
		var color: Color = ThemeManager.mark_color("cart")
		draw_rect(Rect2(bottom + Vector2(-22.0, -10.0), Vector2(44.0, 12.0)), color)
		for side: float in [-1.0, 1.0]:
			draw_circle(bottom + Vector2(side * 14.0, 6.0), 6.0, color.darkened(0.3), true, -1.0, true)
	var x: float = area.position.x + 30.0
	while x < area.end.x:
		draw_circle(Vector2(x, area.position.y + 30.0 + fmod(x * 7.3, 40.0)), 2.0, line, true, -1.0, true)
		x += 23.0


## Beş Ünsür: the five elements around a small circle in the corner, each
## arrow of creation round it (Water Wood, Wood Fire, Fire Earth, Earth Metal,
## Metal Water).
func _draw_wuxing(area: Rect2) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var center: Vector2 = area.position + Vector2(46.0, 46.0)
	draw_arc(center, 30.0, 0.0, TAU, 40, line, 2.0, true)
	for i: int in 5:
		var angle: float = TAU * i / 5.0 - PI * 0.5
		draw_circle(center + Vector2(cos(angle), sin(angle)) * 30.0, 8.0, ThemeManager.ELEMENT_DISKS[i]["fill"], true, -1.0, true)
	# Brush strokes across the paper.
	var y: float = area.position.y + 110.0
	while y < area.end.y - 20.0:
		draw_line(Vector2(area.position.x + 20.0, y), Vector2(area.position.x + 20.0 + fmod(y * 3.7, 80.0) + 40.0, y), line, 2.0, true)
		y += 70.0


## Xalça: a rug along the bottom with a medallion under each peg showing how
## high it must stand; a peg that has its height fills its medallion with
## gold, so the pattern fills in as the silhouette is built.
func _draw_carpet(area: Rect2) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	# The field: a lattice of small diamonds, as on a carpet's ground.
	var step: float = 36.0
	var y: float = area.position.y + step
	while y < area.end.y - CARPET_ROOM:
		var x: float = area.position.x + step * 0.5
		while x < area.end.x:
			draw_polyline(PackedVector2Array([Vector2(x, y - 7.0), Vector2(x + 7.0, y), Vector2(x, y + 7.0), Vector2(x - 7.0, y),
					Vector2(x, y - 7.0)]), line, 2.0, true)
			x += step
		y += step
	var carpet: Dictionary = marks.get("carpet", {})
	var heights: Array = carpet.get("heights", [])
	var counts: Array = carpet.get("counts", [])
	var rug: Rect2 = Rect2(area.position.x + 6.0, size.y - CARPET_ROOM + 2.0, area.size.x - 12.0, CARPET_ROOM - 6.0)
	draw_rect(rug, ThemeManager.mark_color("rug"))
	draw_rect(rug.grow(-4.0), ThemeManager.mark_color("rug_border"), false, 3.0)
	var font: Font = get_theme_default_font()
	for peg_index: int in mini(heights.size(), peg_count):
		var center: Vector2 = Vector2(peg_x(peg_index), rug.get_center().y)
		var done: bool = peg_index < counts.size() and int(counts[peg_index]) == int(heights[peg_index])
		var medallion: PackedVector2Array = PackedVector2Array([center + Vector2(0.0, -14.0), center + Vector2(18.0, 0.0),
				center + Vector2(0.0, 14.0), center + Vector2(-18.0, 0.0)])
		draw_colored_polygon(medallion, ThemeManager.mark_color("rug_done") if done else ThemeManager.mark_color("rug_border"))
		var text: String = str(heights[peg_index])
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, center + Vector2(-width * 0.5, 6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
				ThemeManager.mark_color("rug_text"))


## Ko: the lines of a Go board on kaya wood, with its star points.
func _draw_goban(area: Rect2) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var step: float = 40.0
	var x: float = area.position.x + step * 0.5
	while x < area.end.x:
		draw_line(Vector2(x, area.position.y + 6.0), Vector2(x, area.end.y - 6.0), line, 1.5, true)
		x += step
	var y: float = area.position.y + step * 0.5
	while y < area.end.y:
		draw_line(Vector2(area.position.x + 6.0, y), Vector2(area.end.x - 6.0, y), line, 1.5, true)
		y += step
	for point: Vector2 in [area.get_center(), area.position + area.size * Vector2(0.25, 0.25),
			area.position + area.size * Vector2(0.75, 0.25), area.position + area.size * Vector2(0.25, 0.75),
			area.position + area.size * Vector2(0.75, 0.75)]:
		draw_circle(point, 4.0, line, true, -1.0, true)


## Gold lozenges on crimson silk, in rows.
func _draw_lozenges(area: Rect2) -> void:
	var line: Color = ThemeManager.skin_color(skin, "pattern")
	var step: float = 44.0
	var row: int = 0
	var y: float = area.position.y + step
	while y < area.end.y:
		var x: float = area.position.x + (step * 0.5 if row % 2 == 1 else 0.0)
		while x < area.end.x:
			draw_colored_polygon(PackedVector2Array([Vector2(x, y - 9.0), Vector2(x + 7.0, y), Vector2(x, y + 9.0),
					Vector2(x - 7.0, y)]), line)
			x += step
		y += step * 0.8
		row += 1


## Fil Çayı: the river (or the bonfire) between the last peg of the left bank
## and the first of the right one; a ferry peg stands in it on a boat.
func _draw_river(area: Rect2) -> void:
	var river: Dictionary = marks.get("river", {})
	var banks: Array = river.get("banks", [])
	if cells.size() != banks.size() or banks.is_empty():
		return
	var last_left: int = banks.rfind(RiverRule.LEFT)
	var first_right: int = banks.find(RiverRule.RIGHT)
	var ferry: int = banks.find(RiverRule.FERRY)
	var left_x: float = cells[last_left].end.x - cells[last_left].size.x * 0.12
	var right_x: float = cells[first_right].position.x + cells[first_right].size.x * 0.12
	if ferry < 0:
		var middle: float = (cells[last_left].end.x + cells[first_right].position.x) * 0.5
		var half: float = cells[last_left].size.x * 0.16
		left_x = middle - half
		right_x = middle + half
	var band: Rect2 = Rect2(left_x, area.position.y, right_x - left_x, area.size.y)
	if river.get("fire", false):
		_draw_bonfire(band)
	else:
		draw_rect(band, ThemeManager.mark_color("river_water"))
		var wave: Color = ThemeManager.mark_color("river_wave")
		var y: float = band.position.y + 24.0
		var row: int = 0
		while y < band.end.y - 10.0:
			var points: PackedVector2Array = PackedVector2Array()
			var x: float = band.position.x + 4.0
			while x <= band.end.x - 4.0:
				points.append(Vector2(x, y + sin(x * 0.12 + row * 1.9 - _time * 2.4) * 3.0))
				x += 6.0
			if points.size() > 1:
				draw_polyline(points, wave, 2.0, true)
			y += 34.0
			row += 1
	# The bottom of the pegs' bases (one row: every cell ends there).
	var floor_y: float = cells[0].end.y - 6.0
	if ferry >= 0:
		var boat: Color = ThemeManager.mark_color("boat")
		var center: float = cells[ferry].get_center().x
		var width: float = cells[ferry].size.x * 0.42
		draw_colored_polygon(PackedVector2Array([Vector2(center - width, floor_y - 6.0), Vector2(center + width, floor_y - 6.0),
				Vector2(center + width * 0.7, floor_y + 8.0), Vector2(center - width * 0.7, floor_y + 8.0)]), boat)
	var stone: Color = ThemeManager.mark_color("bridge_stone")
	for bridge: Array in river.get("bridges", []):
		var from: Vector2 = Vector2(peg_x(bridge[0]), floor_y + 4.0)
		var to: Vector2 = Vector2(peg_x(bridge[1]), floor_y + 4.0)
		var points: PackedVector2Array = PackedVector2Array()
		for i: int in 17:
			var t: float = i / 16.0
			points.append(from.lerp(to, t) + Vector2(0.0, -sin(t * PI) * 18.0))
		draw_polyline(points, stone, 8.0, true)
	var ford: Color = ThemeManager.mark_color("ford")
	var font: Font = get_theme_default_font()
	var depth: int = 0
	for crossing: Array in river.get("crossings", []):
		var y: float = floor_y - 30.0 - depth * 34.0
		var from: Vector2 = Vector2(peg_x(crossing[0]), y)
		var to: Vector2 = Vector2(peg_x(crossing[1]), y)
		_draw_dashes(from, to, ford, 3.0)
		for x: float in [band.position.x + band.size.x * 0.25, band.get_center().x, band.end.x - band.size.x * 0.25]:
			draw_circle(Vector2(x, y), 5.0, ford, true, -1.0, true)
		var text: String = "≤%d" % int(crossing[2])
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(band.get_center().x - width * 0.5, y - 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ford.darkened(0.4))
		depth += 1


## "Novruz tonqalı": a warm glow up the band and flames at its foot.
func _draw_bonfire(band: Rect2) -> void:
	draw_rect(band, ThemeManager.mark_color("fire_glow"))
	var foot: Vector2 = Vector2(band.get_center().x, (cells[0].end.y if not cells.is_empty() else size.y) - 10.0)
	var flame: Color = ThemeManager.mark_color("fire")
	var core: Color = ThemeManager.mark_color("fire_core")
	# The bonfire stands in the middle of the board's height, so the disks and
	# bases never hide it.
	foot.y = band.position.y + band.size.y * 0.62
	var half: float = band.size.x * 0.45
	for i: int in 3:
		var side: float = (i - 1) * half * 0.45
		var height: float = 70.0 + sin(_time * 6.0 + i * 2.0) * 10.0 - absf(i - 1) * 18.0
		draw_colored_polygon(PackedVector2Array([foot + Vector2(side - half * 0.4, 0.0), foot + Vector2(side, -height),
				foot + Vector2(side + half * 0.4, 0.0)]), flame)
		draw_colored_polygon(PackedVector2Array([foot + Vector2(side - half * 0.2, 0.0), foot + Vector2(side, -height * 0.55),
				foot + Vector2(side + half * 0.2, 0.0)]), core)
	draw_line(foot + Vector2(-band.size.x * 0.4, 4.0), foot + Vector2(band.size.x * 0.4, 4.0), ThemeManager.mark_color("boat"), 6.0, true)


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
	var dial: Dictionary = marks.get("dial", {})
	if not (dial.get("eight", []) as Array).is_empty():
		_draw_eight(dial["eight"], mark, line)
		return
	var middle: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	if int(dial.get("center", -1)) >= 0:
		# The centre peg: a soft glow in the middle instead of the arrow.
		draw_arc(middle, radius, 0.0, TAU, 72, line, 3.0, true)
		draw_circle(middle, minf(size.x, size.y) * 0.14, ThemeManager.mark_color("center_glow"), true, -1.0, true)
		if not cells.is_empty():
			for i: int in cells.size() - 1:
				_draw_ring_arrow(cells[i].get_center(), cells[(i + 1) % (cells.size() - 1)].get_center(), middle, mark)
		return
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


## "Səkkiz": a circle through each loop's pegs (the shared peg on both) and a
## small arrow between each two pegs the way the loop runs.
func _draw_eight(loops: Array, mark: Color, line: Color) -> void:
	if cells.is_empty():
		return
	for loop: Array in loops:
		var centre: Vector2 = Vector2.ZERO
		for peg: int in loop:
			centre += cells[peg].get_center() / loop.size()
		var radius: float = cells[loop[0]].get_center().distance_to(centre)
		draw_arc(centre, radius, 0.0, TAU, 64, line, 3.0, true)
		for i: int in loop.size():
			_draw_ring_arrow(cells[loop[i]].get_center(), cells[loop[(i + 1) % loop.size()]].get_center(), centre, mark)


## A small arrow on the arc from peg centre `from` toward `to` around `centre`,
## half way between them.
func _draw_ring_arrow(from: Vector2, to: Vector2, centre: Vector2, color: Color) -> void:
	var start: float = (from - centre).angle()
	var finish: float = (to - centre).angle()
	var turn: float = wrapf(finish - start, -PI, PI)
	var radius: float = from.distance_to(centre)
	var at: float = start + turn * 0.5
	var tip: Vector2 = centre + Vector2(cos(at), sin(at)) * radius
	var along: Vector2 = Vector2(-sin(at), cos(at)) * signf(turn)
	var side: Vector2 = Vector2(cos(at), sin(at))
	draw_colored_polygon(PackedVector2Array([tip + along * 10.0, tip - along * 5.0 + side * 7.0, tip - along * 5.0 - side * 7.0]), color)


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
	# The road: a stop under every peg, each linked only to its neighbours (an
	# oasis beside the road is reached from its own stop only).
	var road: Dictionary = marks.get("road", {})
	var oasis: int = (road.get("oasis", [-1, -1]) as Array)[0]
	var road_y: float = size.y - CARAVAN_ROOM * 0.32
	var stops: Array[int] = []
	for i: int in peg_count:
		if i != oasis:
			stops.append(i)
	for k: int in stops.size() - 1:
		var from: Vector2 = Vector2(peg_x(stops[k]) + 22.0, road_y)
		var to: Vector2 = Vector2(peg_x(stops[k + 1]) - 22.0, road_y)
		_draw_dashes(from, to, mark, 4.0)
	for i: int in stops:
		_draw_caravanserai(Vector2(peg_x(i), size.y - 4.0), mark, dune)
	if oasis >= 0 and oasis < peg_count:
		_draw_oasis(oasis, road["oasis"][1], road_y)
	for tunnel: Array in road.get("tunnels", []):
		_draw_tunnel(tunnel[0], tunnel[1])
	for bridge: Array in road.get("bridges", []):
		_draw_bridge(bridge[0], bridge[1], bridge[2], road_y)
	for arrow: Array in road.get("one_way", []):
		_draw_road_arrow(arrow[0], arrow[1], road_y)


## A dashed line from `from` to `to`.
func _draw_dashes(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var length: float = from.distance_to(to)
	var along: Vector2 = (to - from) / maxf(length, 1.0)
	var travelled: float = 0.0
	while travelled < length:
		draw_line(from + along * travelled, from + along * minf(travelled + 10.0, length), color, width, true)
		travelled += 18.0


## The oasis beside the road: a pool and a palm, a short path to its stop.
func _draw_oasis(peg: int, stop: int, road_y: float) -> void:
	var water: Color = ThemeManager.mark_color("oasis_water")
	var palm: Color = ThemeManager.mark_color("palm")
	var bottom: Vector2 = Vector2(peg_x(peg), size.y - 8.0)
	draw_set_transform(bottom, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 26.0, water, true, -1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var trunk: Vector2 = bottom + Vector2(18.0, -4.0)
	draw_line(trunk, trunk + Vector2(4.0, -30.0), ThemeManager.skin_color(skin, "mark"), 4.0, true)
	for angle: float in [-2.6, -2.0, -1.2, -0.6]:
		draw_line(trunk + Vector2(4.0, -30.0), trunk + Vector2(4.0, -30.0) + Vector2(cos(angle), sin(angle) * 0.6) * 18.0,
				palm, 4.0, true)
	_draw_dashes(Vector2(peg_x(stop), road_y + 6.0), Vector2(peg_x(peg) - 20.0, size.y - 10.0), palm, 3.0)


## A kəhriz: a well mouth under each of its two stops and the tunnel between
## them, dashed under the sand.
func _draw_tunnel(a: int, b: int) -> void:
	var well: Color = ThemeManager.mark_color("well")
	var line: Color = ThemeManager.mark_color("tunnel")
	var y: float = size.y + 4.0
	for peg: int in [a, b]:
		draw_arc(Vector2(peg_x(peg) - 26.0, y - 10.0), 7.0, 0.0, TAU, 16, well, 3.0, true)
	var from: Vector2 = Vector2(peg_x(a) - 26.0, y - 2.0)
	var to: Vector2 = Vector2(peg_x(b) - 26.0, y - 2.0)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var t: float = i / 16.0
		points.append(from.lerp(to, t) + Vector2(0.0, sin(t * PI) * 8.0))
	for i: int in range(0, points.size() - 1, 2):
		draw_line(points[i], points[i + 1], line, 3.0, true)


## A rope bridge on the road between neighbouring stops, with the largest size
## that may cross.
func _draw_bridge(a: int, b: int, largest: int, road_y: float) -> void:
	var rope: Color = ThemeManager.mark_color("rope")
	var left: float = minf(peg_x(a), peg_x(b)) + 26.0
	var right: float = maxf(peg_x(a), peg_x(b)) - 26.0
	for offset: float in [-6.0, 6.0]:
		draw_line(Vector2(left, road_y + offset), Vector2(right, road_y + offset), rope, 2.5, true)
	var x: float = left + 6.0
	while x < right:
		draw_line(Vector2(x, road_y - 6.0), Vector2(x, road_y + 6.0), rope, 3.0, true)
		x += 10.0
	var font: Font = get_theme_default_font()
	var text: String = "≤%d" % largest
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(font, Vector2((left + right - width) * 0.5, road_y - 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, rope)


## An arrow on a one-way road, pointing the way it may be crossed.
func _draw_road_arrow(from_peg: int, to_peg: int, road_y: float) -> void:
	var color: Color = ThemeManager.mark_color("road_arrow")
	var middle: float = (peg_x(from_peg) + peg_x(to_peg)) * 0.5
	var way: float = 1.0 if peg_x(to_peg) > peg_x(from_peg) else -1.0
	draw_line(Vector2(middle - 16.0 * way, road_y - 12.0), Vector2(middle + 10.0 * way, road_y - 12.0), color, 4.0, true)
	draw_colored_polygon(PackedVector2Array([Vector2(middle + 18.0 * way, road_y - 12.0), Vector2(middle + 6.0 * way, road_y - 20.0),
			Vector2(middle + 6.0 * way, road_y - 4.0)]), color)


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
