class_name BoardMarks
extends Control
## A mechanic's marks drawn over the disks (BoardDress.overlay_marks), so they
## follow the disks while they glide:
## - "chain": [disk, disk, can move now] a chain of small links between the two
##   linked disks, bright when both are on top and may go, faded otherwise;
## - "locked": [disks] a small padlock on each disk the foundation still holds;
## - "trail_disk": a dotted rim on the disk that leaves the trail.
## Purely visual: it ignores the mouse and knows nothing of the rules.

const LINK_SPACING: float = 16.0
const LINK_RADIUS: float = 5.0

## The board's disk views (id -> DiskView), shared with the board.
var disk_views: Dictionary[int, DiskView] = {}
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


## Small dots around the disk that leaves the trail.
func _draw_trail_rim(rect: Rect2) -> void:
	var color: Color = ThemeManager.mark_color("footprint")
	var x: float = rect.position.x + 6.0
	while x < rect.end.x - 6.0:
		draw_circle(Vector2(x, rect.position.y - 4.0), 2.2, color, true, -1.0, true)
		x += 9.0
