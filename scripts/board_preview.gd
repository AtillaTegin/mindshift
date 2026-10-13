class_name BoardPreview
extends Control
## Small read-only drawing of a position (the level goal). Every disk carries
## its size number on top of its colour (economy/UX addendum 6), so Hard and
## Expert goals stay readable when neighbouring colours look alike.
## A "Birləşmə Tapmacası" goal is a colour arrangement instead (set_color_goal,
## correction v2: every colour on the board is shown): a sort goal is a row of
## colour icons, a pattern the full target of every peg. Disks carry their
## colour's shape, and what is already done on the board (current_state) is
## marked.

const DISK_HEIGHT: float = 24.0
const BASE_HEIGHT: float = 6.0
const MIN_HEIGHT: float = 130.0
const MIN_FONT_SIZE: int = 14
const MAX_FONT_SIZE: int = 20
## Colour goals: the size of a sort goal's colour icon, the height of a slot of
## a pattern's peg.
const SORT_ICON: float = 52.0
const SORT_CAPTION: float = 26.0
const PATTERN_SLOT: float = 16.0

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
			custom_minimum_size.y = preferred_height(value.get_disk_count()) if color_goal == null else _colour_goal_height()
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


## PATTERN: how many disks at the bottom of peg `peg_index` already match its
## target on the board right now.
func placed_on(peg_index: int) -> int:
	if color_goal == null or current_state == null or color_goal.kind != ColorGoal.PATTERN:
		return 0
	return color_goal.placed_on(ColorGoal.letters_of(current_state, disk_colors), peg_index)


## SORT: the colours that sit finished on a peg of their own right now.
func finished_colours() -> Array[String]:
	var done: Array[String] = []
	if color_goal == null or current_state == null or color_goal.kind != ColorGoal.SORT:
		return done
	var pegs: PackedStringArray = ColorGoal.letters_of(current_state, disk_colors)
	for peg_index: int in pegs.size():
		if ColorGoal.is_peg_finished(pegs, peg_index):
			done.append(ColorGoal.LETTERS.find_key(pegs[peg_index][0]))
	return done


## The colours of a sort goal, in the order their icons are drawn.
func sort_colours() -> Array[String]:
	var colours: Array[String] = []
	for color_name: String in disk_colors:
		if not colours.has(color_name):
			colours.append(color_name)
	return colours


## A sort goal is one row of colour icons with a caption; a pattern a small
## tower per peg, in the board's rows.
func _colour_goal_height() -> float:
	if color_goal.kind == ColorGoal.SORT:
		return SORT_ICON + SORT_CAPTION + 16.0
	return _pattern_rows() * _pattern_row_height()


## Rows of the pattern towers: the same as the board's (BoardLayout.ONE_ROW_PEGS),
## so each target stands where its peg stands.
func _pattern_rows() -> int:
	return 2 if position_state != null and position_state.get_peg_count() > BoardLayout.ONE_ROW_PEGS else 1


func _pattern_row_height() -> float:
	var slot: float = PATTERN_SLOT if _pattern_rows() == 1 else PATTERN_SLOT * 0.75
	return BASE_HEIGHT + 6.0 + slot * (maxi(capacity, 1) + 0.4)


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


## A colour goal. SORT: one icon per colour of the board (all of them, never
## cut off) over a caption, a check mark on each colour that sits finished on
## its own peg. PATTERN: a small tower per peg with its full target (an empty
## peg stays empty), standing in the board's rows and columns, the disks
## already in place on the board ringed in the success colour.
func _draw_colour_goal() -> void:
	if color_goal.kind == ColorGoal.SORT:
		_draw_sort_icons()
		return
	var peg_count: int = position_state.get_peg_count()
	var rows: int = _pattern_rows()
	var per_row: int = ceili(float(peg_count) / rows)
	var column: float = size.x / maxi(per_row, 1)
	var row_height: float = size.y / rows
	var slot: float = (row_height - BASE_HEIGHT - 6.0) / (maxi(capacity, 1) + 0.4)
	var peg_color: Color = ThemeManager.skin_color(skin, "peg")
	var width: float = column * BoardLayout.EQUAL_DISK_SHARE
	for peg_index: int in peg_count:
		var row: int = peg_index / per_row
		var in_row: int = per_row if row < rows - 1 else peg_count - per_row * (rows - 1)
		var center_x: float = column * (peg_index % per_row + (per_row - in_row) * 0.5 + 0.5)
		var base_top: float = row_height * (row + 1) - BASE_HEIGHT
		draw_rect(Rect2(center_x - 2.0, base_top - slot * (capacity + 0.3), 4.0, slot * (capacity + 0.3)), peg_color)
		draw_rect(Rect2(center_x - column * 0.45, base_top, column * 0.9, BASE_HEIGHT), peg_color)
		var target: Array = color_goal.targets[peg_index]
		var done: int = placed_on(peg_index)
		for level_index: int in target.size():
			var rect: Rect2 = Rect2(center_x - width * 0.5, base_top - slot * (level_index + 1) + 1.0, width, slot - 2.0)
			var colors: Dictionary = ThemeManager.COMBINATION_DISKS[target[level_index]]
			var box: StyleBoxFlat = StyleBoxFlat.new()
			box.bg_color = colors["fill"]
			box.set_corner_radius_all(int(rect.size.y * 0.45))
			box.set_border_width_all(2 if level_index < done else 1)
			box.border_color = ThemeManager.color("success") if level_index < done else colors["outline"]
			draw_style_box(box, rect)
			DiskSymbols.draw(self, target[level_index], rect.get_center(), rect.size.y * 0.3, colors["text"])


func _draw_sort_icons() -> void:
	var colours: Array[String] = sort_colours()
	var finished: Array[String] = finished_colours()
	var icon: float = minf(SORT_ICON, size.x / maxi(colours.size(), 1) - 10.0)
	var gap: float = minf(icon * 0.35, 16.0)
	var left: float = (size.x - colours.size() * icon - (colours.size() - 1) * gap) * 0.5
	var top: float = (size.y - icon - SORT_CAPTION) * 0.5
	for i: int in colours.size():
		var rect: Rect2 = Rect2(left + i * (icon + gap), top, icon, icon)
		var colors: Dictionary = ThemeManager.COMBINATION_DISKS[colours[i]]
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = colors["fill"]
		box.set_corner_radius_all(int(icon * 0.3))
		var done: bool = finished.has(colours[i])
		box.set_border_width_all(3 if done else 2)
		box.border_color = ThemeManager.color("success") if done else colors["outline"]
		draw_style_box(box, rect)
		DiskSymbols.draw(self, colours[i], rect.get_center(), icon * 0.22, colors["text"])
		if done:
			var side: float = icon * 0.42
			DiskSymbols.draw_check(self, rect.end - Vector2(side, side) - Vector2(2.0, 2.0), side, colors["text"])
	# Correction v2: the icons come with the words "each into its own peg".
	var font: Font = get_theme_default_font()
	var font_size: int = 20
	var caption: String = tr("COMBINATION_SORT_GOAL")
	var caption_width: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - caption_width) * 0.5, top + icon + SORT_CAPTION - 4.0), caption,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeManager.color("text_secondary"))

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
