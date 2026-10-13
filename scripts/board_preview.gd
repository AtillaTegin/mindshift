class_name BoardPreview
extends Control
## Small read-only drawing of a position (the level goal). Every disk carries
## its size number on top of its colour (economy/UX addendum 6), so Hard and
## Expert goals stay readable when neighbouring colours look alike.
## A "Birləşmə Tapmacası" goal is a colour arrangement instead (set_color_goal):
## a pattern shows its colours on its peg, the other pegs faded (anything may
## stand there); a sort goal shows one stack per colour. Disks carry their
## colour's shape, and what is already done on the board (current_state) gets
## a check mark.

const DISK_HEIGHT: float = 24.0
const BASE_HEIGHT: float = 6.0
const MIN_HEIGHT: float = 130.0
const MIN_FONT_SIZE: int = 14
const MAX_FONT_SIZE: int = 20

## Disk size -> {fill, text} overriding the usual one colour per disk (the two
## caravans of a great exchange); empty for other levels.
var disk_palette: Dictionary = {}:
	set(value):
		disk_palette = value
		queue_redraw()
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
			custom_minimum_size.y = preferred_height(value.get_disk_count() if color_goal == null else _colour_stack())
		queue_redraw()
## The colour goal, the level's disk colours and its peg capacity; null / empty
## / 0 for a level with an exact goal position.
var color_goal: ColorGoal
var disk_colors: Array[String] = []
var capacity: int = 0
## The board's position, for the check marks of a colour goal.
var current_state: PuzzleState:
	set(value):
		current_state = value
		queue_redraw()


func set_color_goal(goal: ColorGoal, colours: Array[String], peg_capacity: int) -> void:
	color_goal = goal
	disk_colors = colours
	capacity = peg_capacity
	current_state = null


## How many slots of the pattern are done (PATTERN), or which colours sit
## finished on a peg of their own (SORT), on the board right now.
func pattern_done() -> int:
	if color_goal == null or current_state == null or color_goal.kind != ColorGoal.PATTERN:
		return 0
	return color_goal.progress(current_state, disk_colors)


func finished_colours() -> Array[String]:
	var done: Array[String] = []
	if color_goal == null or current_state == null or color_goal.kind != ColorGoal.SORT:
		return done
	var pegs: PackedStringArray = ColorGoal.letters_of(current_state, disk_colors)
	for peg_index: int in pegs.size():
		if ColorGoal.is_peg_finished(pegs, peg_index):
			done.append(ColorGoal.LETTERS.find_key(pegs[peg_index][0]))
	return done


## The colours of a sort goal, in the order their stacks are drawn.
func sort_colours() -> Array[String]:
	var colours: Array[String] = []
	for color_name: String in disk_colors:
		if not colours.has(color_name):
			colours.append(color_name)
	return colours


## Tallest stack a colour goal shows.
func _colour_stack() -> int:
	if color_goal.kind == ColorGoal.PATTERN:
		return maxi(capacity, color_goal.colors.size())
	var tallest: int = 1
	for color_name: String in sort_colours():
		tallest = maxi(tallest, disk_colors.count(color_name))
	return tallest


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
	if color_goal != null:
		_draw_colour_goal()
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
		var colors: Dictionary = disk_palette.get(label["disk"], {})
		draw_rect(rect, colors.get("fill", ThemeManager.disk_color(label["disk"], disk_count)))
		if colors.has("outline"):
			draw_rect(rect, colors["outline"], false, 1.5)
		var text: String = str(label["disk"])
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline: Vector2 = Vector2(rect.position.x + (rect.size.x - text_width) * 0.5,
				rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colors.get("text", text_color))
	_draw_fog(column, disk_height, base_top, font)


## A colour goal: PATTERN on its peg among faded pegs, SORT as one stack per
## colour; done parts carry a check mark.
func _draw_colour_goal() -> void:
	var stack: int = _colour_stack()
	var disk_height: float = _disk_height(stack)
	var base_top: float = size.y - BASE_HEIGHT
	var peg_color: Color = ThemeManager.skin_color(skin, "peg")
	var faded: Color = peg_color
	faded.a *= 0.3
	var columns: int = position_state.get_peg_count() if color_goal.kind == ColorGoal.PATTERN else sort_colours().size()
	var column: float = size.x / maxi(columns, 1)
	var width: float = column * BoardLayout.EQUAL_DISK_SHARE
	for index: int in columns:
		var center_x: float = column * (index + 0.5)
		var rod: Color = faded if color_goal.kind == ColorGoal.PATTERN and index != color_goal.peg else peg_color
		draw_rect(Rect2(center_x - 3.0, base_top - disk_height * (stack + 0.3), 6.0, disk_height * (stack + 0.3)), rod)
		draw_rect(Rect2(center_x - column * 0.45, base_top, column * 0.9, BASE_HEIGHT), rod)
		var colours: Array[String] = []
		var done: int = 0
		if color_goal.kind == ColorGoal.PATTERN:
			if index != color_goal.peg:
				continue
			colours = color_goal.colors
			done = pattern_done()
		else:
			var color_name: String = sort_colours()[index]
			for i: int in disk_colors.count(color_name):
				colours.append(color_name)
			done = colours.size() if finished_colours().has(color_name) else 0
		for level_index: int in colours.size():
			var rect: Rect2 = Rect2(center_x - width * 0.5, base_top - disk_height * (level_index + 1), width, disk_height - 2.0)
			var colors: Dictionary = ThemeManager.COMBINATION_DISKS[colours[level_index]]
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = colors["fill"]
			box.set_corner_radius_all(int(rect.size.y * 0.45))
			box.set_border_width_all(2)
			box.border_color = ThemeManager.color("success") if level_index < done else colors["outline"]
			draw_style_box(box, rect)
			DiskSymbols.draw(self, colours[level_index], rect.get_center(), rect.size.y * 0.24, colors["text"])
			if level_index < done:
				var side: float = rect.size.y * 0.7
				DiskSymbols.draw_check(self, Vector2(rect.end.x - side - rect.size.y * 0.25, rect.get_center().y - side * 0.5),
						side, colors["text"])


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
