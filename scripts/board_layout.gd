class_name BoardLayout
extends RefCounted
## Geometry shared by the board and the goal preview.

const MIN_DISK_SHARE: float = 0.3
const MAX_DISK_SHARE: float = 0.94
## More pegs than this stand in two rows (BoardDress.layout_kind), on the board
## and in the goal preview.
const ONE_ROW_PEGS: int = 5
## Layout kinds (BoardDress.layout_kind): one row; two rows (the second one
## centred); pegs around a circle, clockwise from the top; pegs in pairs, the
## two of a pair closer together.
const ROW: String = "row"
const ROWS: String = "rows"
const CIRCLE: String = "circle"
const PAIRS: String = "pairs"
## The gap between two pairs, in peg columns.
const PAIR_GAP: float = 0.5


## Disk width inside a peg column: the smallest disk takes 30% of the column,
## the largest 94%.
static func disk_width(disk_size: int, disk_count: int, column_width: float) -> float:
	var share: float = MAX_DISK_SHARE
	if disk_count > 1:
		share = MIN_DISK_SHARE + (MAX_DISK_SHARE - MIN_DISK_SHARE) * float(disk_size - 1) / float(disk_count - 1)
	return column_width * share


## The cell of every peg (its column: rod, base and room above) inside `area`
## for a layout `kind`; all cells have the same size.
static func peg_cells(kind: String, peg_count: int, area: Vector2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var count: int = maxi(peg_count, 1)
	match kind:
		ROWS:
			var per_row: int = ceili(count / 2.0)
			var size: Vector2 = Vector2(area.x / per_row, area.y / 2.0)
			for i: int in peg_count:
				var row: int = i / per_row
				var in_row: int = per_row if row == 0 else peg_count - per_row
				cells.append(Rect2(Vector2(size.x * (i % per_row + (per_row - in_row) * 0.5), size.y * row), size))
		PAIRS:
			var unit: float = area.x / (count + (ceili(count / 2.0) - 1) * PAIR_GAP)
			for i: int in peg_count:
				cells.append(Rect2(Vector2(unit * (i + (i / 2) * PAIR_GAP), 0.0), Vector2(unit, area.y)))
		CIRCLE:
			# Small enough that neighbours never overlap and the middle stays free
			# for the dial's arrow (circle_center()).
			var size: Vector2 = Vector2(area.x * (0.4 if count <= 3 else 0.3 if count == 4 else 0.27),
					area.y * (0.44 if count <= 3 else 0.36 if count == 4 else 0.32))
			var center: Vector2 = area * 0.5
			var radius: Vector2 = (area - size) * 0.5
			for i: int in peg_count:
				var angle: float = -PI / 2.0 + TAU * i / count
				cells.append(Rect2(center + Vector2(cos(angle), sin(angle)) * radius - size * 0.5, size))
		_:
			var size: Vector2 = Vector2(area.x / count, area.y)
			for i: int in peg_count:
				cells.append(Rect2(Vector2(size.x * i, 0.0), size))
	return cells


## Where a circle of `cells` leaves room for the dial's arrow: the middle of
## the area, or with three pegs between the two lower ones.
static func circle_center(cells: Array[Rect2], area: Vector2) -> Vector2:
	if cells.size() == 3:
		return Vector2(area.x * 0.5, cells[1].get_center().y)
	return area * 0.5


## Whether pegs of this layout stand in more than one line (the disks then get
## a little less room each).
static func is_compact(kind: String) -> bool:
	return kind == ROWS or kind == CIRCLE
