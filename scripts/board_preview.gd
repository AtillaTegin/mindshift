class_name BoardPreview
extends Control
## Small read-only drawing of a position (the level goal). Every disk carries
## its size number on top of its colour (economy/UX addendum 6), so Hard and
## Expert goals stay readable when neighbouring colours look alike. The pegs
## stand in the board's own layout (BoardDress.layout_kind: a row, two rows, a
## circle or pairs), so each goal peg is where its board peg is. The goal is
## always shown whole, even on a karakuri level (current decisions 2026-10-16,
## B.3: the boxes hide the position, never the aim).

const DISK_HEIGHT: float = 24.0
const BASE_HEIGHT: float = 6.0
const MIN_HEIGHT: float = 130.0
const MIN_FONT_SIZE: int = 14
const MAX_FONT_SIZE: int = 20

## Disk id -> {fill, text, outline} overriding the usual one colour per disk,
## optionally with `label` (the number shown), `size` and `sizes` (its width
## among that many sizes); see BoardDress.disk_palette. Empty for most levels.
var disk_palette: Dictionary = {}:
	set(value):
		disk_palette = value
		queue_redraw()
## Dress of the level (ThemeManager.SKINS): the pegs take its colour, "" for none.
var skin: String = "":
	set(value):
		skin = value
		queue_redraw()
## The board's peg layout (BoardLayout kinds) and the most disks one peg can
## hold (the rods are drawn for it); set before position_state.
var layout_kind: String = BoardLayout.ROW
var stack_room: int = 0
## Per peg, how many disks its rod is drawn for (unequal capacity); empty: every
## rod is drawn for stack_room.
var rod_rooms: Array[int] = []
## How many disks the level has (their widths and colours) when the preview
## shows only some of them (a goal condition: the crowned disks on their
## gates); 0: the shown position's own count.
var disk_total: int = 0
## Pegs marked with a gate's flag (the king's gates, ICRA 3.1).
var gates: Array[int] = []:
	set(value):
		gates = value
		queue_redraw()
## A carpet's aim (BoardDress.goal_silhouette, ICRA 3.4): {heights, tops,
## navel}, drawn as empty slots of each peg's height, the marked tops' colours
## and the navel's disk; {} for every other level.
var silhouette: Dictionary = {}:
	set(value):
		silhouette = value
		queue_redraw()
var position_state: PuzzleState:
	set(value):
		position_state = value
		if value != null:
			# Tall enough for full-height disks, so the numbers stay legible.
			custom_minimum_size.y = preferred_height(_stack(), layout_kind)
		queue_redraw()


## Height that fits a peg of `stack` disks at DISK_HEIGHT plus the base, for
## every line of pegs of the layout `kind`.
static func preferred_height(stack: int, kind: String = BoardLayout.ROW) -> float:
	var line: float = BASE_HEIGHT + 4.0 + DISK_HEIGHT * (maxi(stack, 1) + 1)
	if kind == BoardLayout.ROWS:
		line *= 1.6
	elif kind == BoardLayout.CIRCLE:
		line *= 1.8
	return maxf(MIN_HEIGHT, line)


## Each peg's cell in the preview.
func get_cells() -> Array[Rect2]:
	return BoardLayout.peg_cells(layout_kind, position_state.get_peg_count(), size)


## Where each disk and its number go: [{ disk, rect, font_size }].
func get_disk_labels() -> Array[Dictionary]:
	var labels: Array[Dictionary] = []
	if position_state == null or position_state.get_peg_count() == 0:
		return labels
	var disk_count: int = _disk_total()
	var cells: Array[Rect2] = get_cells()
	var disk_height: float = _disk_height(cells[0].size.y)
	for peg_index: int in position_state.get_peg_count():
		var cell: Rect2 = cells[peg_index]
		var base_top: float = cell.end.y - BASE_HEIGHT
		var peg: Array = position_state.pegs[peg_index]
		for level_index: int in peg.size():
			var disk: int = peg[level_index]
			var colors: Dictionary = disk_palette.get(disk, {})
			var width: float = BoardLayout.disk_width(colors["size"], colors["sizes"], cell.size.x) if colors.has("size") \
					else BoardLayout.disk_width(disk, disk_count, cell.size.x)
			var rect: Rect2 = Rect2(cell.get_center().x - width * 0.5, base_top - disk_height * (level_index + 1), width,
					disk_height - 2.0)
			var font_size: int = clampi(int(rect.size.y * 0.9), MIN_FONT_SIZE, MAX_FONT_SIZE)
			labels.append({"disk": disk, "rect": rect, "font_size": font_size})
	return labels


func _disk_total() -> int:
	return disk_total if disk_total > 0 else maxi(position_state.get_disk_count(), 1)


## The carpet's silhouette: on each peg as many outlined slots as it must
## hold, its height above them, a marked top's colour in its top slot and the
## navel's disk number on the middle peg.
func _draw_silhouette(cells: Array[Rect2], disk_height: float, font: Font) -> void:
	if silhouette.has("sums") or silhouette.get("fair", false):
		_draw_sums(cells, font)
		return
	var heights: Array = silhouette.get("heights", [])
	var tops: Array = silhouette.get("tops", [])
	var navel: Array = silhouette.get("navel", [])
	var outline: Color = ThemeManager.skin_color(skin, "peg")
	for peg_index: int in mini(heights.size(), cells.size()):
		var cell: Rect2 = cells[peg_index]
		var base_top: float = cell.end.y - BASE_HEIGHT
		var width: float = cell.size.x * 0.7
		var height: int = heights[peg_index]
		for slot: int in height:
			var rect: Rect2 = Rect2(cell.get_center().x - width * 0.5, base_top - disk_height * (slot + 1), width, disk_height - 2.0)
			var colour: int = int(tops[peg_index]) if peg_index < tops.size() and slot == height - 1 else -1
			if colour >= 0:
				draw_rect(rect, ThemeManager.CARPET_DISKS[colour]["fill"])
			draw_rect(rect, outline, false, 1.5)
			if slot == height - 1 and navel.size() == 2 and int(navel[0]) == peg_index:
				var text: String = str(navel[1])
				var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MIN_FONT_SIZE).x
				draw_string(font, rect.get_center() + Vector2(-text_width * 0.5, 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
						MIN_FONT_SIZE, outline)
		var number: String = str(height)
		var number_width: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, MAX_FONT_SIZE).x
		draw_string(font, Vector2(cell.get_center().x - number_width * 0.5, base_top - disk_height * (height + 1) + 6.0),
				number, HORIZONTAL_ALIGNMENT_LEFT, -1, MAX_FONT_SIZE, outline)


## Cəm's aim: over each peg the sum it must reach ("=" for equal sums, "tək"
## or "cüt" for parity, "x2" on a doubled peg), and its count where one is set.
func _draw_sums(cells: Array[Rect2], font: Font) -> void:
	var sums: Array = silhouette.get("sums", [])
	var counts: Array = silhouette.get("counts", [])
	var parity: Array = silhouette.get("parity", [])
	var color: Color = ThemeManager.skin_color(skin, "peg")
	for peg_index: int in cells.size():
		var text: String = "="
		if peg_index < sums.size() and int(sums[peg_index]) >= 0:
			text = str(sums[peg_index])
		elif peg_index < parity.size():
			text = tr("ODD_PEG") if int(parity[peg_index]) == 1 else tr("EVEN_PEG") if int(parity[peg_index]) == 2 else "·"
		if peg_index == int(silhouette.get("double", -1)):
			text += " ×2"
		if peg_index < counts.size():
			text += " (%d)" % int(counts[peg_index])
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, MAX_FONT_SIZE).x
		var cell: Rect2 = cells[peg_index]
		draw_string(font, Vector2(cell.get_center().x - width * 0.5, cell.get_center().y), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				MAX_FONT_SIZE, color)


## The most disks one peg can hold (every disk unless the board says less).
func _stack() -> int:
	if stack_room > 0:
		return stack_room
	return position_state.get_disk_count() if position_state != null else 1


func _disk_height(cell_height: float) -> float:
	return minf((cell_height - BASE_HEIGHT - 4.0) / (_stack() + 1), DISK_HEIGHT)


func _draw() -> void:
	if position_state == null or position_state.get_peg_count() == 0:
		return
	var disk_count: int = _disk_total()
	var stack: int = maxi(_stack(), 1)
	var cells: Array[Rect2] = get_cells()
	var disk_height: float = _disk_height(cells[0].size.y)
	var peg_color: Color = ThemeManager.skin_color(skin, "peg")
	for peg_index: int in cells.size():
		var cell: Rect2 = cells[peg_index]
		var center_x: float = cell.get_center().x
		var base_top: float = cell.end.y - BASE_HEIGHT
		var rod: float = disk_height * ((rod_rooms[peg_index] + 0.3) if peg_index < rod_rooms.size() else (stack + 0.5))
		draw_rect(Rect2(center_x - 3.0, base_top - rod, 6.0, rod), peg_color)
		draw_rect(Rect2(center_x - cell.size.x * 0.45, base_top, cell.size.x * 0.9, BASE_HEIGHT), peg_color)
		if gates.has(peg_index):
			# The gate's flag on top of its rod.
			var pole: Vector2 = Vector2(center_x, base_top - rod)
			draw_line(pole, pole + Vector2(0.0, -14.0), ThemeManager.mark_color("gate"), 2.0, true)
			draw_colored_polygon(PackedVector2Array([pole + Vector2(1.0, -14.0), pole + Vector2(12.0, -10.0),
					pole + Vector2(1.0, -6.0)]), ThemeManager.mark_color("flag"))
	var font: Font = get_theme_default_font()
	var text_color: Color = ThemeManager.color("text_on_disk")
	if not silhouette.is_empty():
		_draw_silhouette(cells, disk_height, font)
	for label: Dictionary in get_disk_labels():
		var rect: Rect2 = label["rect"]
		var font_size: int = label["font_size"]
		var colors: Dictionary = disk_palette.get(label["disk"], {})
		draw_rect(rect, colors.get("fill", ThemeManager.disk_color(label["disk"], disk_count)))
		if colors.has("outline"):
			draw_rect(rect, colors["outline"], false, 1.5)
		var text: String = str(colors.get("label", label["disk"]))
		var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline: Vector2 = Vector2(rect.position.x + (rect.size.x - text_width) * 0.5,
				rect.position.y + (rect.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colors.get("text", text_color))
