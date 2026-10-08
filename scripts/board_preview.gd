class_name BoardPreview
extends Control
## Small read-only drawing of a position (the level goal). Every disk carries
## its size number on top of its colour (economy/UX addendum 6), so Hard and
## Expert goals stay readable when neighbouring colours look alike.

const DISK_HEIGHT: float = 24.0
const BASE_HEIGHT: float = 6.0
const MIN_HEIGHT: float = 130.0
const MIN_FONT_SIZE: int = 14
const MAX_FONT_SIZE: int = 20

var position_state: PuzzleState:
	set(value):
		position_state = value
		if value != null:
			# Tall enough for full-height disks, so the numbers stay legible.
			custom_minimum_size.y = preferred_height(value.get_disk_count())
		queue_redraw()


## Height that fits `disk_count` disks at DISK_HEIGHT plus the peg base.
static func preferred_height(disk_count: int) -> float:
	return maxf(MIN_HEIGHT, BASE_HEIGHT + 4.0 + DISK_HEIGHT * (maxi(disk_count, 1) + 1))


## Where each disk and its number go: [{ disk, rect, font_size }].
func get_disk_labels() -> Array[Dictionary]:
	var labels: Array[Dictionary] = []
	if position_state == null or position_state.get_peg_count() == 0:
		return labels
	var disk_count: int = maxi(position_state.get_disk_count(), 1)
	var column: float = size.x / position_state.get_peg_count()
	var disk_height: float = _disk_height(disk_count)
	var base_top: float = size.y - BASE_HEIGHT
	for peg_index: int in position_state.get_peg_count():
		var center_x: float = column * (peg_index + 0.5)
		var peg: Array = position_state.pegs[peg_index]
		for level_index: int in peg.size():
			var disk: int = peg[level_index]
			var width: float = BoardLayout.disk_width(disk, disk_count, column)
			var rect: Rect2 = Rect2(center_x - width * 0.5, base_top - disk_height * (level_index + 1), width, disk_height - 2.0)
			var font_size: int = clampi(int(rect.size.y * 0.9), MIN_FONT_SIZE, MAX_FONT_SIZE)
			labels.append({"disk": disk, "rect": rect, "font_size": font_size})
	return labels


func _disk_height(disk_count: int) -> float:
	return minf((size.y - BASE_HEIGHT - 4.0) / (disk_count + 1), DISK_HEIGHT)


func _draw() -> void:
	if position_state == null or position_state.get_peg_count() == 0:
		return
	var peg_count: int = position_state.get_peg_count()
	var disk_count: int = maxi(position_state.get_disk_count(), 1)
	var column: float = size.x / peg_count
	var disk_height: float = _disk_height(disk_count)
	var base_top: float = size.y - BASE_HEIGHT
	var peg_color: Color = ThemeManager.color("peg")
	for peg_index: int in peg_count:
		var center_x: float = column * (peg_index + 0.5)
		draw_rect(Rect2(center_x - 3.0, base_top - disk_height * (disk_count + 0.5), 6.0, disk_height * (disk_count + 0.5)), peg_color)
		draw_rect(Rect2(center_x - column * 0.45, base_top, column * 0.9, BASE_HEIGHT), peg_color)
	var font: Font = get_theme_default_font()
	var text_color: Color = ThemeManager.color("text_on_disk")
	for label: Dictionary in get_disk_labels():
		var rect: Rect2 = label["rect"]
		var font_size: int = label["font_size"]
		draw_rect(rect, ThemeManager.disk_color(label["disk"], disk_count))
		var text: String = str(label["disk"])
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline: Vector2 = Vector2(rect.position.x + (rect.size.x - text_width) * 0.5,
				rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
