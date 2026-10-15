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
##   a peg's base with its smallest size.
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
var marks: Dictionary = {}:
	set(value):
		marks = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	# Disks glide after every move; keep the marks on them.
	if not marks.is_empty():
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


## Small dots around the disk that leaves the trail.
func _draw_trail_rim(rect: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("footprint")
	var x: float = rect.position.x + 6.0
	while x < rect.end.x - 6.0:
		draw_circle(Vector2(x, rect.position.y - 4.0), 2.2, color, true, -1.0, true)
		x += 9.0
