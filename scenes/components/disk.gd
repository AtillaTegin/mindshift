class_name DiskView
extends Control
## One disk: a rounded bar with its size number. Position and size are set by
## the game board; input goes to the peg underneath.

var disk_size: int = 1:
	set(value):
		disk_size = value
		queue_redraw()
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()


func _draw() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color.lightened(0.15) if selected else color
	box.set_corner_radius_all(int(minf(size.y, size.x) * 0.45))
	if selected:
		box.set_border_width_all(4)
		box.border_color = UIPalette.TEXT_PRIMARY
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var font: Font = get_theme_default_font()
	var font_size: int = int(clampf(size.y * 0.55, 12.0, 28.0))
	var text: String = str(disk_size)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline: Vector2 = Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UIPalette.TEXT_PRIMARY)
