class_name SortPatternView
extends Control
## The target of the colour-order prototype as a small tower, bottom -> top,
## drawn in the target peg's column so the two read together. Each slot shows
## its progress: in place (full colour, check mark), the next one to fill
## (accent rim), taken by a wrong disk on the target peg (danger rim and a
## cross), or still to come (pale). A slot that just fell into place pulses once.

const PULSE_SECONDS: float = 0.45
const MAX_SLOT_HEIGHT: float = 40.0
const BASE_HEIGHT: float = 10.0

var target_colors: Array[String] = []
## Width of each slot as a share of the column, bottom -> top.
var slot_shares: Array[float] = []
## Disks at the bottom of the target peg that already match.
var matched: int = 0
## Disks on the target peg.
var occupied: int = 0

var _pulse_slot: int = -1
var _pulse: float = 0.0:
	set(value):
		_pulse = value
		queue_redraw()
var _pulse_tween: Tween


func setup(p_target_colors: Array[String], p_slot_shares: Array[float]) -> void:
	target_colors = p_target_colors
	slot_shares = p_slot_shares
	matched = 0
	occupied = 0
	queue_redraw()


## New progress; a slot that has just come into place pulses.
func set_progress(p_matched: int, p_occupied: int) -> void:
	var gained: bool = p_matched > matched
	matched = p_matched
	occupied = p_occupied
	if gained and is_inside_tree():
		_pulse_slot = matched - 1
		if _pulse_tween != null:
			_pulse_tween.kill()
		_pulse = 1.0
		_pulse_tween = create_tween()
		_pulse_tween.tween_property(self, "_pulse", 0.0, PULSE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


## Rect of slot `index` (0 = bottom) in local coordinates.
func slot_rect(index: int) -> Rect2:
	var count: int = maxi(target_colors.size(), 1)
	var slot_height: float = minf((size.y - BASE_HEIGHT - 8.0) / count, MAX_SLOT_HEIGHT)
	var width: float = size.x * 0.96 * slot_shares[index]
	var bottom: float = size.y - BASE_HEIGHT - slot_height * index
	return Rect2(size.x * 0.5 - width * 0.5, bottom - slot_height + 2.0, width, slot_height - 4.0)


func _draw() -> void:
	if target_colors.is_empty():
		return
	var peg_color: Color = ThemeManager.color("peg")
	var top: float = slot_rect(target_colors.size() - 1).position.y - 6.0
	draw_rect(Rect2(size.x * 0.5 - 3.0, top, 6.0, size.y - BASE_HEIGHT - top), peg_color)
	var base: StyleBoxFlat = StyleBoxFlat.new()
	base.bg_color = peg_color
	base.set_corner_radius_all(int(BASE_HEIGHT * 0.5))
	draw_style_box(base, Rect2(size.x * 0.02, size.y - BASE_HEIGHT, size.x * 0.96, BASE_HEIGHT))
	for index: int in target_colors.size():
		_draw_slot(index)


func _draw_slot(index: int) -> void:
	var rect: Rect2 = slot_rect(index)
	if index == _pulse_slot and _pulse > 0.0:
		rect = rect.grow(_pulse * 6.0)
	var color_name: String = target_colors[index]
	var in_place: bool = index < matched
	var fill: Color = SortPalette.fill(color_name)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) * 0.45))
	# A slot still to fill is a pale, opaque version of its colour (the rod
	# does not show through) with its shape in the full colour.
	box.bg_color = fill if in_place else fill.lerp(ThemeManager.color("background"), 0.62)
	box.set_border_width_all(3)
	if in_place:
		box.border_color = ThemeManager.color("success")
	elif index < occupied:
		box.border_color = ThemeManager.color("danger")
	elif index == matched:
		box.border_color = ThemeManager.color("accent")
	else:
		box.border_color = fill
	draw_style_box(box, rect)
	var ink: Color = SortPalette.ink(color_name) if in_place else fill
	var center: Vector2 = rect.get_center()
	SortPalette.draw_symbol(self, color_name, center, rect.size.y * 0.24, ink)
	var side: float = rect.size.y * 0.62
	var mark: Vector2 = Vector2(rect.end.x - rect.size.y * 0.45 - side * 0.6, center.y - side * 0.5)
	if in_place:
		SortPalette.draw_check(self, mark, side, ink)
	elif index < occupied:
		SortPalette.draw_cross(self, mark, side, ThemeManager.color("danger"))
