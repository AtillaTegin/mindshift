class_name PathMap
extends Control
## The level path drawn as a winding road of numbered stops (level structure
## addendum v3), Candy Crush style: level 1 at the bottom, the road climbs.
## It shows every level up to the furthest one reached plus LOCKED_AHEAD locked
## stops; the rest of the road stays out of sight. On the main road each open
## island (one at the end of each chapter, chapter system v1) appears as a
## marker beside the stop that opened it.
## Every stop carries its mode's short label beside it (mode labels
## specification v1, section 1: ModeTexts), on an island with "· Ekspert" for
## an expert level (user decision 2026-10-15: only those).
## Lives inside a vertical ScrollContainer; its height grows with the road.

signal level_pressed(track: String, position: int)
signal island_pressed(island: String)

## Vertical distance between two stops.
const STEP: float = 150.0
const STOP_SIZE: float = 112.0
## A chapter's Böyük Sınaq (Fəsil Sistemi v1.2, 3.2a): a larger stop with a crown.
const BIG_STOP_SIZE: float = 140.0
## Sideways swing of the road, as a share of the width, and its turn per stop (radians).
const SWING: float = 0.3
const TURN: float = 0.85
const LOCKED_AHEAD: int = 3
const ROAD_WIDTH: float = 30.0
## Free space below the first and above the last stop.
const END_SPACE: float = 120.0
const ISLAND_SIZE: Vector2 = Vector2(190, 96)
## A stop's mode label: its font size and its gap from the stop (clear of the
## current stop's ring).
const LABEL_FONT_SIZE: int = 22
const LABEL_GAP: float = STOP_SIZE * 0.62 + 8.0
const LABEL_MARGIN: float = 4.0

var track: String = LevelCatalog.MAIN

var _cells: Array[LevelCell] = []
## The mode label of each shown stop.
var _labels: Array[Label] = []
## Main road position -> the marker of the island it opened.
var _islands: Dictionary = {}
## Next level to play on this track (0: none) and the last completed stop in a row from 1.
var _current: int = 0
var _done_in_a_row: int = 0


## Builds the stops of `p_track` for the progress in `save`.
func setup(p_track: String, save: SaveSystem) -> void:
	track = p_track
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_cells.clear()
	_labels.clear()
	_islands.clear()
	var length: int = LevelCatalog.track_length(track)
	var furthest: int = 0
	_current = 0
	_done_in_a_row = 0
	for position: int in range(1, length + 1):
		var level_id: int = LevelCatalog.level_id_at(track, position)
		if LevelCatalog.is_unlocked(track, position, save):
			furthest = position
			if _current == 0 and not save.is_completed(level_id):
				_current = position
		if save.is_completed(level_id) and _done_in_a_row == position - 1:
			_done_in_a_row = position
	var shown: int = mini(length, furthest + LOCKED_AHEAD)
	custom_minimum_size.y = END_SPACE * 2.0 + STOP_SIZE + maxf(shown - 1, 0) * STEP
	for position: int in range(1, shown + 1):
		var cell: LevelCell = LevelCell.new()
		var mechanic: String = LevelCatalog.mechanic_at(track, position)
		cell.crown = track == LevelCatalog.MAIN and ChapterPlan.is_big_test(position)
		cell.size = Vector2.ONE * (BIG_STOP_SIZE if cell.crown else STOP_SIZE)
		cell.add_theme_font_size_override("font_size", 36)
		var level_id: int = LevelCatalog.level_id_at(track, position)
		cell.setup(position, save.get_stars(level_id), not LevelCatalog.is_unlocked(track, position, save))
		cell.current = position == _current
		cell.skin = ThemeManager.skin_for(mechanic)
		cell.pressed.connect(func() -> void: level_pressed.emit(track, position))
		add_child(cell)
		_cells.append(cell)
		var label: Label = Label.new()
		label.text = stop_label(track, position)
		label.theme_type_variation = &"SecondaryLabel"
		label.add_theme_font_size_override("font_size", LABEL_FONT_SIZE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_labels.append(label)
	if track == LevelCatalog.MAIN:
		for island: String in LevelCatalog.open_islands(save):
			var after: int = LevelCatalog.island_after(island)
			if after > shown:
				continue
			var marker: Button = PolishedButton.new()
			marker.text = "MAP_ISLAND"
			marker.theme_type_variation = &"AccentButton"
			marker.size = ISLAND_SIZE
			marker.add_theme_font_size_override("font_size", 28)
			marker.pressed.connect(func() -> void: island_pressed.emit(island))
			add_child(marker)
			_islands[after] = marker
	_place_children()
	queue_redraw()


## Stops on the map (shown ones only).
func shown_count() -> int:
	return _cells.size()


## The mode label of the stop at `position` on `p_track`: its mode's short
## name ("Tutum + Kilid" for a combination), plus "· Ekspert" for an expert
## level on an island.
static func stop_label(p_track: String, position: int) -> String:
	var text: String = ModeTexts.label(LevelCatalog.lesson_at(p_track, position))
	if LevelCatalog.is_island(p_track) and _is_expert(p_track, position):
		text += " " + Languages.text("MAP_EXPERT_SUFFIX")
	return text


## Whether the level at a path position is of the expert tier: a classic one
## by its id, a mechanic one by its file.
static func _is_expert(p_track: String, position: int) -> bool:
	var level_id: int = LevelCatalog.level_id_at(p_track, position)
	if not Difficulty.is_mechanic_id(level_id):
		return Difficulty.tier_of_id(level_id) == "expert"
	var level: Level = LevelCatalog.load_at(p_track, position)
	return level != null and level.difficulty == "expert"


## The label beside the stop of `position` (1-based), or null if not shown.
func get_label(position: int) -> Label:
	return _labels[position - 1] if position >= 1 and position <= _labels.size() else null


## The stop of `position` (1-based), or null if it is not shown.
func get_cell(position: int) -> LevelCell:
	return _cells[position - 1] if position >= 1 and position <= _cells.size() else null


## The marker of `island` (the first shown one when ""), or null while it is
## closed, out of sight or on an island track itself.
func get_island_button(island: String = "") -> Button:
	if island.is_empty():
		return _islands[_islands.keys().min()] if not _islands.is_empty() else null
	return _islands.get(LevelCatalog.island_after(island))


## How many island markers the road shows.
func island_marker_count() -> int:
	return _islands.size()


## Next level to play on this track, 0 if every shown level is completed.
func current_position() -> int:
	return _current


## Centre of stop `position` (may be fractional, for the road in between).
func stop_center(position: float) -> Vector2:
	var height: float = maxf(size.y, custom_minimum_size.y)
	var y: float = height - END_SPACE - STOP_SIZE * 0.5 - (position - 1.0) * STEP
	return Vector2(size.x * 0.5 + sin((position - 1.0) * TURN) * size.x * SWING, y)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_place_children()
		queue_redraw()


func _place_children() -> void:
	for i: int in _cells.size():
		_cells[i].position = stop_center(i + 1) - _cells[i].size * 0.5
	for after: int in _islands:
		(_islands[after] as Button).position = _island_center(after) - ISLAND_SIZE * 0.5
	for i: int in _labels.size():
		_labels[i].size = _labels[i].get_combined_minimum_size()
		_labels[i].position = _label_position(i + 1, _labels[i].size)


## Where the label of stop `position` goes: level with the stop, on the side
## toward the middle of the map (the road leaves the stop up and down, so that
## side is free at the stop's height), alternating for a stop in the middle,
## on the far side of the island marker; on the other side if it does not
## fit, under the stop if neither does.
func _label_position(position: int, label_size: Vector2) -> Vector2:
	var center: Vector2 = stop_center(position)
	var middle: float = size.x * 0.5
	var right_side: bool = center.x < middle - 1.0 or (absf(center.x - middle) <= 1.0 and position % 2 == 1)
	if _islands.has(position):
		right_side = _island_center(position).x < center.x
	var top: float = center.y - label_size.y * 0.5
	# A larger stop (Böyük Sınaq) keeps its label as far from its rim.
	var gap: float = LABEL_GAP + (_cells[position - 1].size.x - STOP_SIZE) * 0.5 if position <= _cells.size() else LABEL_GAP
	var right: Vector2 = Vector2(center.x + gap, top)
	var left: Vector2 = Vector2(center.x - gap - label_size.x, top)
	var fits_right: bool = right.x + label_size.x <= size.x - LABEL_MARGIN
	var fits_left: bool = left.x >= LABEL_MARGIN
	if (right_side and fits_right) or (fits_right and not fits_left):
		return right
	if fits_left:
		return left
	return Vector2(center.x - label_size.x * 0.5, center.y + STOP_SIZE * 0.5 + LABEL_MARGIN)


## Beside the stop `after` that opens an island, on the side the road swings
## away from.
func _island_center(after: int) -> Vector2:
	var stop: Vector2 = stop_center(after)
	var x: float = size.x * (0.84 if stop.x < size.x * 0.5 else 0.16)
	return Vector2(x, stop.y)


func _draw() -> void:
	if _cells.is_empty():
		return
	# The road, sampled ten times per stop: the part already travelled (up to the
	# next level to play) in the accent colour, the rest muted.
	var done: PackedVector2Array = PackedVector2Array()
	var ahead: PackedVector2Array = PackedVector2Array()
	var reached: int = mini(_done_in_a_row + 1, _cells.size())
	for step: int in range((_cells.size() - 1) * 10 + 1):
		var point: Vector2 = stop_center(1.0 + step * 0.1)
		if _done_in_a_row > 0 and step <= (reached - 1) * 10:
			done.append(point)
		if step >= (reached - 1) * 10:
			ahead.append(point)
	if ahead.size() > 1:
		draw_polyline(ahead, ThemeManager.color("surface"), ROAD_WIDTH, true)
	if done.size() > 1:
		var travelled: Color = ThemeManager.color("accent")
		travelled.a = 0.55
		draw_polyline(done, travelled, ROAD_WIDTH, true)
	for after: int in _islands:
		_draw_dashes(stop_center(after), _island_center(after), ThemeManager.color("accent"))
	if _current > 0 and _current <= _cells.size():
		draw_arc(stop_center(_current), _cells[_current - 1].size.x * 0.62, 0.0, TAU, 48, ThemeManager.color("accent"), 6.0, true)


func _draw_dashes(from: Vector2, to: Vector2, color: Color) -> void:
	var length: float = from.distance_to(to)
	var direction: Vector2 = from.direction_to(to)
	var travelled: float = STOP_SIZE * 0.5
	while travelled + 18.0 < length - ISLAND_SIZE.x * 0.5:
		draw_line(from + direction * travelled, from + direction * (travelled + 18.0), color, 8.0, true)
		travelled += 32.0

