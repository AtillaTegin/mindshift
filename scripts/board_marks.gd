class_name BoardMarks
extends Control
## A mechanic's marks drawn over the disks (BoardDress.overlay_marks), so they
## follow the disks while they glide:
## - "chain": [disk, disk, can move now] a chain of small links between the two
##   linked disks, bright when both are on top and may go, faded otherwise;
## - "locked": [disks] a small padlock on each disk the foundation still holds;
## - "trail_disk": a dotted rim on the disk that leaves the trail;
## - chapter waves: "keys" a key on each key disk and a key place under its
##   peg, "links" a thin dotted thread from a key disk to the lock it opens,
##   "arches" a stone arch over a peg with its largest size, "holes" a hole in
##   a peg's base with its smallest size;
## - World 3-4: "disk_icons" {disk: "crown" | "broken" | "hourglass"} at a
##   disk's left end, "reset" a turning arrow under a peg, "bases" {peg:
##   "odd" | "even"} a coloured plate on a peg's base, "paint" a paint pot over
##   a peg (flash_paint() lets drops fall), "back" [peg, the one before] a
##   two-way arrow, "skip" [peg, target] an arrow over the peg it skips.
## - World 5: "disk_icons" also "elephant"; "gates" [pegs] a flagged arch over
##   each gate, "narrow" [[gate, entry]] an arrow from the entry into the gate,
##   "odd_even" [peg, peg] "Tək" and "Cüt" under them, "inn" a roof over the
##   caravanserai.
## Purely visual: it ignores the mouse and knows nothing of the rules.

const LINK_SPACING: float = 16.0
const LINK_RADIUS: float = 5.0
const NUMBER_SIZE: int = 20

## The board's disk views (id -> DiskView), shared with the board.
var disk_views: Dictionary[int, DiskView] = {}
## Each peg's rod, from its top to the bottom of its base (set by the board).
var peg_rects: Array[Rect2] = []:
	set(value):
		peg_rects = value
		queue_redraw()
## Güzgü: a blocked echo flashes the mirror line and a "✕" over its peg.
const FLASH_SECONDS: float = 0.6
var _flash_peg: int = -1
var _flash_left: float = 0.0


## Shows that the echo on `peg` (a bottom board peg) could not happen.
func flash_cross(peg: int) -> void:
	_flash_peg = peg
	_flash_left = FLASH_SECONDS
	queue_redraw()


## The paint peg painted a disk: a few drops fall from its pot.
const DRIP_SECONDS: float = 0.5
var _drip_left: float = 0.0


func flash_paint() -> void:
	_drip_left = DRIP_SECONDS
	queue_redraw()
var marks: Dictionary = {}:
	set(value):
		marks = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	# Disks glide after every move; keep the marks on them.
	if not marks.is_empty() or _flash_left > 0.0:
		_flash_left = maxf(_flash_left - delta, 0.0)
		_drip_left = maxf(_drip_left - delta, 0.0)
		queue_redraw()


func _draw() -> void:
	if marks.has("chain"):
		_draw_chain(marks["chain"])
	for disk: int in marks.get("locked", []):
		if disk_views.has(disk):
			_draw_lock(_rect_of(disk))
	if marks.has("trail_disk") and disk_views.has(marks["trail_disk"]):
		_draw_trail_rim(_rect_of(marks["trail_disk"]))
	for link: Array in marks.get("links", []):
		if disk_views.has(link[0]) and disk_views.has(link[1]):
			_draw_thread(_rect_of(link[0]).get_center(), _rect_of(link[1]).get_center())
	for key: Array in marks.get("keys", []):
		if disk_views.has(key[0]):
			_draw_key(_rect_of(key[0]))
		if key[1] < peg_rects.size():
			_draw_key_place(peg_rects[key[1]])
	var arches: Dictionary = marks.get("arches", {})
	for peg: int in arches:
		if peg < peg_rects.size():
			_draw_arch(peg_rects[peg], arches[peg])
	var holes: Dictionary = marks.get("holes", {})
	for peg: int in holes:
		if peg < peg_rects.size():
			_draw_hole(peg_rects[peg], holes[peg])
	if _flash_left > 0.0 and _flash_peg >= 0 and _flash_peg < peg_rects.size():
		_draw_blocked_echo(peg_rects[_flash_peg], _flash_left / FLASH_SECONDS)
	var icons: Dictionary = marks.get("disk_icons", {})
	for disk: int in icons:
		if disk_views.has(disk):
			_draw_disk_icon(_rect_of(disk), icons[disk])
	if marks.has("reset") and marks["reset"] < peg_rects.size():
		_draw_reset(peg_rects[marks["reset"]])
	var bases: Dictionary = marks.get("bases", {})
	for peg: int in bases:
		if peg < peg_rects.size():
			_draw_base_plate(peg_rects[peg], bases[peg])
	if marks.has("paint") and marks["paint"] < peg_rects.size():
		_draw_paint_pot(peg_rects[marks["paint"]])
	for key: String in ["back", "skip"]:
		var arrow: Array = marks.get(key, [])
		if arrow.size() == 2 and arrow[0] < peg_rects.size() and arrow[1] < peg_rects.size():
			_draw_dial_arrow(peg_rects[arrow[0]], peg_rects[arrow[1]], key == "back")
	for gate: int in marks.get("gates", []):
		if gate < peg_rects.size():
			_draw_gate(peg_rects[gate])
	for pair: Array in marks.get("narrow", []):
		if pair[0] < peg_rects.size() and pair[1] < peg_rects.size():
			_draw_entry_arrow(peg_rects[pair[1]], peg_rects[pair[0]])
	var sides: Array = marks.get("odd_even", [])
	if sides.size() == 2 and sides[0] < peg_rects.size() and sides[1] < peg_rects.size():
		_draw_odd_even(peg_rects[sides[0]], "ODD_PEG")
		_draw_odd_even(peg_rects[sides[1]], "EVEN_PEG")
	if marks.has("inn") and marks["inn"] < peg_rects.size():
		_draw_inn(peg_rects[marks["inn"]])


## The king's gate ("Darvaza", ICRA 3.1): an arch over the peg with a flag
## on its top.
func _draw_gate(rod: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("gate")
	var center: Vector2 = Vector2(rod.get_center().x, rod.position.y - 4.0)
	var radius: float = clampf(rod.size.x * 0.36, 18.0, 46.0)
	draw_arc(center, radius, PI, TAU, 24, color, 6.0, true)
	for side: float in [-1.0, 1.0]:
		draw_line(center + Vector2(radius * side, 0.0), center + Vector2(radius * side, 14.0), color, 6.0, true)
	var pole: Vector2 = center + Vector2(0.0, -radius)
	draw_line(pole, pole + Vector2(0.0, -22.0), color, 3.0, true)
	draw_colored_polygon(PackedVector2Array([pole + Vector2(1.5, -22.0), pole + Vector2(18.0, -16.0), pole + Vector2(1.5, -10.0)]),
			ThemeManager.mark_color("flag"))


## "Dar qapı": a short arrow from the only peg a disk may enter the gate from.
func _draw_entry_arrow(from_rod: Rect2, gate_rod: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("gate")
	var from: Vector2 = Vector2(from_rod.get_center().x, from_rod.position.y - 10.0)
	var to: Vector2 = Vector2(gate_rod.get_center().x, gate_rod.position.y - 10.0)
	var middle: Vector2 = (from + to) * 0.5 + Vector2(0.0, -26.0)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 13:
		var t: float = i / 12.0
		points.append(from.lerp(middle, t).lerp(middle.lerp(to, t), t))
	draw_polyline(points, color, 3.5, true)
	_draw_arrow_head(points[-2], points[-1], color)


## "Tək" or "Cüt" under a marked peg (the odd and even towers' goal).
func _draw_odd_even(rod: Rect2, key: String) -> void:
	_draw_number(tr(key), Vector2(rod.get_center().x, rod.end.y + 20.0), ThemeManager.mark_color("odd_even"))


## "Karvansara" (ICRA 3.3): a roof over the peg where colours may mix.
func _draw_inn(rod: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("inn_roof")
	var top: Vector2 = Vector2(rod.get_center().x, rod.position.y - 22.0)
	var half: float = clampf(rod.size.x * 0.4, 20.0, 50.0)
	draw_colored_polygon(PackedVector2Array([top, top + Vector2(half, 16.0), top + Vector2(-half, 16.0)]), color)
	draw_rect(Rect2(top + Vector2(-half * 0.7, 16.0), Vector2(half * 1.4, 5.0)), color.darkened(0.25))


func _rect_of(disk: int) -> Rect2:
	var view: DiskView = disk_views[disk]
	return Rect2(view.position, view.size)


## Links along a gentle downward curve between the two disks' centres.
func _draw_chain(chain: Array) -> void:
	if not disk_views.has(chain[0]) or not disk_views.has(chain[1]):
		return
	var from: Vector2 = _rect_of(chain[0]).get_center()
	var to: Vector2 = _rect_of(chain[1]).get_center()
	var sag: Vector2 = Vector2(0.0, minf(from.distance_to(to) * 0.18, 60.0))
	var middle: Vector2 = (from + to) * 0.5 + sag
	var color: Color = ThemeManager.mark_color("chain" if chain[2] else "chain_faded")
	var steps: int = maxi(int(from.distance_to(to) / LINK_SPACING), 2)
	for i: int in range(1, steps):
		var t: float = float(i) / steps
		var point: Vector2 = from.lerp(middle, t).lerp(middle.lerp(to, t), t)
		draw_arc(point, LINK_RADIUS, 0.0, TAU, 12, color, 2.5, true)


## A padlock at the right end of a locked disk.
func _draw_lock(rect: Rect2) -> void:
	var unit: float = clampf(rect.size.y * 0.32, 6.0, 14.0)
	var center: Vector2 = Vector2(rect.end.x - unit * 1.6, rect.get_center().y + unit * 0.2)
	draw_arc(center - Vector2(0.0, unit * 0.45), unit * 0.65, PI, TAU, 16, ThemeManager.mark_color("lock_shackle"), unit * 0.3, true)
	draw_rect(Rect2(center.x - unit, center.y - unit * 0.45, unit * 2.0, unit * 1.4), ThemeManager.mark_color("lock"))


## A small key at the left end of a key disk: a ring and a bit.
func _draw_key(rect: Rect2) -> void:
	var unit: float = clampf(rect.size.y * 0.3, 5.0, 12.0)
	var ring: Vector2 = Vector2(rect.position.x + unit * 2.0, rect.get_center().y)
	var color: Color = ThemeManager.mark_color("key")
	draw_arc(ring, unit * 0.7, 0.0, TAU, 14, color, unit * 0.35, true)
	draw_line(ring + Vector2(unit * 0.7, 0.0), ring + Vector2(unit * 2.4, 0.0), color, unit * 0.35, true)
	draw_line(ring + Vector2(unit * 2.0, 0.0), ring + Vector2(unit * 2.0, unit * 0.7), color, unit * 0.3, true)


## The key place under a peg: a keyhole in the base.
func _draw_key_place(rod: Rect2) -> void:
	var center: Vector2 = Vector2(rod.get_center().x, rod.end.y + 12.0)
	var color: Color = ThemeManager.mark_color("key")
	draw_circle(center, 6.0, color, true, -1.0, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(-3.0, 2.0), center + Vector2(3.0, 2.0),
			center + Vector2(5.0, 12.0), center + Vector2(-5.0, 12.0)]), color)


## A thin dotted thread between a key disk and the lock it opens.
func _draw_thread(from: Vector2, to: Vector2) -> void:
	var color: Color = ThemeManager.mark_color("key_link")
	var length: float = from.distance_to(to)
	var travelled: float = 0.0
	while travelled < length:
		draw_circle(from.lerp(to, travelled / maxf(length, 1.0)), 1.8, color, true, -1.0, true)
		travelled += 8.0


## A stone arch over a peg, with the largest size it lets through.
func _draw_arch(rod: Rect2, largest: int) -> void:
	var color: Color = ThemeManager.mark_color("arch")
	var center: Vector2 = Vector2(rod.get_center().x, rod.position.y - 6.0)
	var radius: float = rod.size.x * 0.32
	draw_arc(center, radius, PI, TAU, 24, color, 8.0, true)
	for side: float in [-1.0, 1.0]:
		draw_line(center + Vector2(radius * side, 0.0), center + Vector2(radius * side, 18.0), color, 8.0, true)
	_draw_number("≤%d" % largest, center + Vector2(0.0, -radius - 18.0), color)


## A hole in a peg's base, with the smallest size that stays on it.
func _draw_hole(rod: Rect2, smallest: int) -> void:
	var color: Color = ThemeManager.mark_color("hole")
	var center: Vector2 = Vector2(rod.get_center().x, rod.end.y - 6.0)
	draw_set_transform(center, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, rod.size.x * 0.22, color, true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	_draw_number("≥%d" % smallest, Vector2(center.x, rod.end.y + 20.0), color)


func _draw_number(text: String, center: Vector2, color: Color) -> void:
	var font: Font = get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE)
	draw_string(font, center + Vector2(-text_size.x * 0.5, font.get_ascent(NUMBER_SIZE) * 0.35), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, NUMBER_SIZE, color)


## Güzgü's blocked echo: the mirror line (half way between the boards) lights
## up and a "✕" ripples over the bottom peg, both fading with `strength`.
func _draw_blocked_echo(rod: Rect2, strength: float) -> void:
	var color: Color = ThemeManager.mark_color("echo_blocked")
	color.a *= strength
	var half: int = peg_rects.size() / 2
	var line_y: float = (peg_rects[0].end.y + peg_rects[half].position.y) * 0.5 if peg_rects.size() > half else rod.position.y
	draw_line(Vector2(0.0, line_y), Vector2(size.x, line_y), color, 4.0, true)
	var center: Vector2 = Vector2(rod.get_center().x, rod.position.y - 8.0)
	var arm: float = 12.0 + 8.0 * (1.0 - strength)
	draw_line(center + Vector2(-arm, -arm), center + Vector2(arm, arm), color, 5.0, true)
	draw_line(center + Vector2(-arm, arm), center + Vector2(arm, -arm), color, 5.0, true)


## At a disk's left end: a crown (the new leader), a broken ring (it ignores
## the turns) or an hourglass (it waits for the leader).
func _draw_disk_icon(rect: Rect2, kind: String) -> void:
	var unit: float = clampf(rect.size.y * 0.32, 6.0, 13.0)
	var center: Vector2 = Vector2(rect.position.x + unit * 1.8, rect.get_center().y)
	match kind:
		"crown":
			var color: Color = ThemeManager.mark_color("crown")
			draw_colored_polygon(PackedVector2Array([center + Vector2(-unit, unit * 0.6), center + Vector2(-unit, -unit * 0.4),
					center + Vector2(-unit * 0.5, unit * 0.1), center + Vector2(0.0, -unit * 0.7), center + Vector2(unit * 0.5, unit * 0.1),
					center + Vector2(unit, -unit * 0.4), center + Vector2(unit, unit * 0.6)]), color)
		"broken":
			draw_arc(center, unit * 0.75, 0.6, TAU - 0.4, 18, ThemeManager.mark_color("broken_ring"), unit * 0.3, true)
		"hourglass":
			var color: Color = ThemeManager.mark_color("hourglass")
			draw_colored_polygon(PackedVector2Array([center + Vector2(-unit * 0.7, -unit * 0.8), center + Vector2(unit * 0.7, -unit * 0.8),
					center, ]), color)
			draw_colored_polygon(PackedVector2Array([center, center + Vector2(unit * 0.7, unit * 0.8),
					center + Vector2(-unit * 0.7, unit * 0.8)]), color)
		"elephant":
			# Fil Çayı: a round body, a head with a trunk curling down, two legs.
			var color: Color = ThemeManager.mark_color("elephant")
			draw_circle(center, unit * 0.65, color, true, -1.0, true)
			draw_circle(center + Vector2(-unit * 0.7, -unit * 0.25), unit * 0.4, color, true, -1.0, true)
			draw_line(center + Vector2(-unit * 1.0, -unit * 0.1), center + Vector2(-unit * 1.15, unit * 0.6), color, unit * 0.22, true)
			for x: float in [-0.35, 0.35]:
				draw_line(center + Vector2(unit * x, unit * 0.4), center + Vector2(unit * x, unit * 0.85), color, unit * 0.25, true)


## A turning arrow under a peg's base: after a disk lands here, any disk may go.
func _draw_reset(rod: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("reset")
	var center: Vector2 = Vector2(rod.get_center().x, rod.end.y + 16.0)
	draw_arc(center, 10.0, -PI * 0.3, PI * 1.5, 24, color, 3.5, true)
	var tip: Vector2 = center + Vector2(cos(-PI * 0.3), sin(-PI * 0.3)) * 10.0
	draw_colored_polygon(PackedVector2Array([tip + Vector2(6.0, 2.0), tip + Vector2(-2.0, -6.0), tip + Vector2(-3.0, 5.0)]), color)


## A plate in a stripe colour on a peg's base: it counts as a disk under the
## first one.
func _draw_base_plate(rod: Rect2, role: String) -> void:
	var colors: Dictionary = ThemeManager.STRIPE_DISKS[role]
	var plate: Rect2 = Rect2(rod.position.x + rod.size.x * 0.12, rod.end.y - 12.0, rod.size.x * 0.76, 9.0)
	draw_rect(plate, colors["fill"])
	draw_rect(plate, colors["outline"], false, 2.0)


## A paint pot hanging over a peg, dripping while a disk is painted.
func _draw_paint_pot(rod: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("paint")
	var top: Vector2 = Vector2(rod.get_center().x, rod.position.y - 26.0)
	draw_colored_polygon(PackedVector2Array([top + Vector2(-14.0, -10.0), top + Vector2(14.0, -10.0), top + Vector2(10.0, 8.0),
			top + Vector2(-10.0, 8.0)]), color)
	draw_arc(top + Vector2(0.0, -10.0), 13.0, PI, TAU, 16, color.darkened(0.3), 2.0, true)
	if _drip_left > 0.0:
		var fall: float = 1.0 - _drip_left / DRIP_SECONDS
		for i: int in 3:
			var drop: Vector2 = top + Vector2(-6.0 + i * 6.0, 10.0 + fall * (30.0 + i * 8.0))
			draw_circle(drop, 3.0, color, true, -1.0, true)


## The dial's extra way from one peg: a two-way arrow to the one before (the
## back step) or an arrow arching over the skipped peg (the shortcut).
func _draw_dial_arrow(from_rod: Rect2, to_rod: Rect2, two_way: bool) -> void:
	var color: Color = ThemeManager.mark_color("dial_extra")
	var from: Vector2 = Vector2(from_rod.get_center().x, from_rod.end.y - 4.0)
	var to: Vector2 = Vector2(to_rod.get_center().x, to_rod.end.y - 4.0)
	var middle: Vector2 = (from + to) * 0.5
	var bend: Vector2 = (size * 0.5 - middle) * (0.35 if not two_way else 0.15)
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 17:
		var t: float = i / 16.0
		points.append(from.lerp(middle + bend, t).lerp((middle + bend).lerp(to, t), t))
	draw_polyline(points, color, 4.0, true)
	_draw_arrow_head(points[-2], points[-1], color)
	if two_way:
		_draw_arrow_head(points[1], points[0], color)


func _draw_arrow_head(before: Vector2, tip: Vector2, color: Color) -> void:
	var along: Vector2 = (tip - before).normalized()
	var side: Vector2 = Vector2(-along.y, along.x)
	draw_colored_polygon(PackedVector2Array([tip + along * 6.0, tip - along * 8.0 + side * 7.0, tip - along * 8.0 - side * 7.0]), color)


## Small dots around the disk that leaves the trail.
func _draw_trail_rim(rect: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("footprint")
	var x: float = rect.position.x + 6.0
	while x < rect.end.x - 6.0:
		draw_circle(Vector2(x, rect.position.y - 4.0), 2.2, color, true, -1.0, true)
		x += 9.0
