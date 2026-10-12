class_name SortDiskView
extends DiskView
## A disk of the colour-order prototype: the game's DiskView (glide, bounce,
## shadow, lift when selected) drawn with its colour's shape instead of a size
## number, since equal-sized disks share a size. `matched` marks a disk that
## already sits in its target place: a rim and a check mark.

## Disk id inside the SortPuzzle; the view follows this disk for good.
var disk_id: int = -1
var color_name: String = "red":
	set(value):
		color_name = value
		color = SortPalette.fill(value)
		queue_redraw()
var matched: bool = false:
	set(value):
		matched = value
		queue_redraw()


func _draw() -> void:
	var radius: float = _corner_radius()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color.lightened(0.15) if selected else color
	box.set_corner_radius_all(int(radius))
	box.set_border_width_all(4 if selected else 2)
	box.border_color = ThemeManager.color("text_primary") if selected else color.darkened(0.3)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	if matched:
		_draw_rim(ThemeManager.color("success"), 4.0)
	var ink: Color = SortPalette.ink(color_name)
	SortPalette.draw_symbol(self, color_name, size * 0.5, size.y * 0.24, ink)
	if matched:
		var side: float = size.y * 0.62
		SortPalette.draw_check(self, Vector2(size.x - radius - side * 0.6, (size.y - side) * 0.5), side, ink)
