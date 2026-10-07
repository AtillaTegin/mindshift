class_name BoardPreview
extends Control
## Small read-only drawing of a position (the level goal).

var position_state: PuzzleState:
	set(value):
		position_state = value
		queue_redraw()


func _draw() -> void:
	if position_state == null or position_state.get_peg_count() == 0:
		return
	var peg_count: int = position_state.get_peg_count()
	var disk_count: int = maxi(position_state.get_disk_count(), 1)
	var column: float = size.x / peg_count
	var base_height: float = 6.0
	var disk_height: float = minf((size.y - base_height - 4.0) / (disk_count + 1), 18.0)
	var base_top: float = size.y - base_height
	var peg_color: Color = ThemeManager.color("peg")
	for peg_index: int in peg_count:
		var center_x: float = column * (peg_index + 0.5)
		draw_rect(Rect2(center_x - 3.0, base_top - disk_height * (disk_count + 0.5), 6.0, disk_height * (disk_count + 0.5)), peg_color)
		draw_rect(Rect2(center_x - column * 0.45, base_top, column * 0.9, base_height), peg_color)
		var peg: Array = position_state.pegs[peg_index]
		for level_index: int in peg.size():
			var disk: int = peg[level_index]
			var width: float = BoardLayout.disk_width(disk, disk_count, column)
			var rect: Rect2 = Rect2(center_x - width * 0.5, base_top - disk_height * (level_index + 1), width, disk_height - 2.0)
			draw_rect(rect, ThemeManager.disk_color(disk, disk_count))
