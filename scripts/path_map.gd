class_name PathMap
extends Control
## The level path drawn as a winding road of numbered stops (level structure
## addendum v3), Candy Crush style: level 1 at the bottom, the road climbs.
## It shows every level up to the furthest one reached plus LOCKED_AHEAD locked
## stops; the rest of the road stays out of sight. On the main road the island
## (the side branch) appears as a marker beside the stop that opened it.
## Lives inside a vertical ScrollContainer; its height grows with the road.

signal level_pressed(track: String, position: int)
signal island_pressed

## Vertical distance between two stops.
const STEP: float = 150.0
const STOP_SIZE: float = 112.0
## Sideways swing of the road, as a share of the width, and its turn per stop (radians).
const SWING: float = 0.3
const TURN: float = 0.85
const LOCKED_AHEAD: int = 3
const ROAD_WIDTH: float = 30.0
## Free space below the first and above the last stop.
const END_SPACE: float = 120.0
const ISLAND_SIZE: Vector2 = Vector2(190, 96)

var track: String = LevelCatalog.MAIN

var _cells: Array[LevelCell] = []
var _island: Button
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
	_island = null
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
		cell.size = Vector2(STOP_SIZE, STOP_SIZE)
		cell.add_theme_font_size_override("font_size", 36)
		var level_id: int = LevelCatalog.level_id_at(track, position)
		cell.setup(position, save.get_stars(level_id), not LevelCatalog.is_unlocked(track, position, save))
		cell.current = position == _current
		cell.skin = ThemeManager.skin_for(LevelCatalog.mechanic_at(track, position))
		cell.pressed.connect(func() -> void: level_pressed.emit(track, position))
		add_child(cell)
		_cells.append(cell)
	if track == LevelCatalog.MAIN and LevelCatalog.is_branch_open(save) and LevelCatalog.branch_after() <= shown:
		_island = PolishedButton.new()
		_island.text = "MAP_ISLAND"
		_island.theme_type_variation = &"AccentButton"
		_island.size = ISLAND_SIZE
		_island.add_theme_font_size_override("font_size", 28)
		_island.pressed.connect(func() -> void: island_pressed.emit())
		add_child(_island)
	_place_children()
	queue_redraw()


## Stops on the map (shown ones only).
func shown_count() -> int:
	return _cells.size()


## The stop of `position` (1-based), or null if it is not shown.
func get_cell(position: int) -> LevelCell:
	return _cells[position - 1] if position >= 1 and position <= _cells.size() else null


## The island marker, or null while the island is closed (or on the island itself).
func get_island_button() -> Button:
	return _island


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
		_cells[i].position = stop_center(i + 1) - Vector2(STOP_SIZE, STOP_SIZE) * 0.5
	if _island != null:
		_island.position = _island_center() - ISLAND_SIZE * 0.5


## Beside the stop that opens the island, on the side the road swings away from.
func _island_center() -> Vector2:
	var stop: Vector2 = stop_center(LevelCatalog.branch_after())
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
	if _island != null:
		_draw_dashes(stop_center(LevelCatalog.branch_after()), _island_center(), ThemeManager.color("accent"))
	if _current > 0 and _current <= _cells.size():
		draw_arc(stop_center(_current), STOP_SIZE * 0.62, 0.0, TAU, 48, ThemeManager.color("accent"), 6.0, true)


func _draw_dashes(from: Vector2, to: Vector2, color: Color) -> void:
	var length: float = from.distance_to(to)
	var direction: Vector2 = from.direction_to(to)
	var travelled: float = STOP_SIZE * 0.5
	while travelled + 18.0 < length - ISLAND_SIZE.x * 0.5:
		draw_line(from + direction * travelled, from + direction * (travelled + 18.0), color, 8.0, true)
		travelled += 32.0

