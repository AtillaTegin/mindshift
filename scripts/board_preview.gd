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

## Dress of the level (ThemeManager.SKINS): the pegs take its colour, "" for none.
var skin: String = "":
	set(value):
		skin = value
		queue_redraw()
## Covered pegs (bonus mechanics addendum 2): the goal shows the same fog,
## lifted together with the board's (reveal_peg), so the goal does not give
## the hidden disks away.
var covered_pegs: Array[int] = []:
	set(value):
		covered_pegs = value
		for fade: Tween in _fog_fades:
			fade.kill()
		_fog_fades.clear()
		_fog_alpha.clear()
		for peg_index: int in value:
			_fog_alpha[peg_index] = 1.0
		queue_redraw()
var _fog_alpha: Dictionary[int, float] = {}
var _fog_fades: Array[Tween] = []
var position_state: PuzzleState:
	set(value):
		position_state = value
		if value != null:
			# Tall enough for full-height disks, so the numbers stay legible.
			custom_minimum_size.y = preferred_height(value.get_disk_count())
		queue_redraw()


## Fades the goal fog of `peg_index` away (same timing as the board's PegFog).
func reveal_peg(peg_index: int) -> void:
	if not covered_pegs.has(peg_index):
		return
	covered_pegs.erase(peg_index)
	var fade: Tween = create_tween()
	fade.tween_method(func(alpha: float) -> void:
		_fog_alpha[peg_index] = alpha
		queue_redraw(), 1.0, 0.0, Scrim.FADE_SECONDS)
	_fog_fades.append(fade)


func is_peg_fogged(peg_index: int) -> bool:
	return _fog_alpha.get(peg_index, 0.0) > 0.0


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
	var peg_color: Color = ThemeManager.skin_color(skin, "peg")
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
	_draw_fog(column, disk_height, base_top, font)


## The goal's fog: covers a covered peg's goal disks below its top one.
func _draw_fog(column: float, disk_height: float, base_top: float, font: Font) -> void:
	for peg_index: int in _fog_alpha:
		var alpha: float = _fog_alpha[peg_index]
		var stack: int = position_state.pegs[peg_index].size() if peg_index < position_state.get_peg_count() else 0
		if alpha <= 0.0 or stack < 2:
			continue
		var top: float = base_top - disk_height * (stack - 1)
		# Wider than the widest disk (BoardLayout.MAX_DISK_SHARE) so no edge peeks out.
		var area: Rect2 = Rect2(column * peg_index + column * 0.01, top, column * 0.98, size.y - top)
		var fog: Color = ThemeManager.color("fog")
		fog.a *= alpha
		draw_rect(area, fog)
		var mark: Color = ThemeManager.color("text_secondary")
		mark.a *= alpha
		var mark_size: int = int(clampf(area.size.y * 0.5, MIN_FONT_SIZE, 28.0))
		var mark_width: float = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size).x
		draw_string(font, Vector2(area.get_center().x - mark_width * 0.5,
				area.position.y + (area.size.y + font.get_ascent(mark_size) - font.get_descent(mark_size)) * 0.5),
				"?", HORIZONTAL_ALIGNMENT_LEFT, -1, mark_size, mark)
