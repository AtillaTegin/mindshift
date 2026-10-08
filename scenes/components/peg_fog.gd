class_name PegFog
extends Scrim
## Fog over one covered peg (bonus mechanics addendum 2): a small, opaque
## variant of the 6B Scrim that hides a peg's disks below the top one. It
## reuses the Scrim's fade (show_scrim / hide_scrim); only its size and look
## differ. Purely visual: the game state underneath is complete, and it never
## takes input. Coordinates are local to the parent (the board).

const CORNER_RADIUS: int = 14


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


## Covers `area` (shown at once, without a fade-in, so nothing peeks through
## when a level opens).
func cover(area: Rect2) -> void:
	position = area.position
	size = area.size
	color = ThemeManager.color("fog")
	show_scrim()
	if _fade != null:
		_fade.kill()
	modulate.a = 1.0


## Moves the fog with the board when the screen is laid out again.
func follow(area: Rect2) -> void:
	position = area.position
	size = area.size


## Fades the fog away (the peg was used by a move).
func reveal() -> void:
	hide_scrim()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		color = ThemeManager.color("fog")
		queue_redraw()


func _draw() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(CORNER_RADIUS)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	# A few soft puffs and a question mark: "something is hidden here".
	var puff: Color = ThemeManager.color("background")
	puff.a = 0.35
	for i: int in 3:
		var center: Vector2 = Vector2(size.x * (0.3 + 0.2 * i), size.y * (0.35 + 0.15 * (i % 2)))
		draw_circle(center, minf(size.x, size.y) * 0.18, puff, true, -1.0, true)
	var font: Font = get_theme_default_font()
	var font_size: int = int(clampf(minf(size.x, size.y) * 0.45, 18.0, 48.0))
	var mark: String = "?"
	var text_size: Vector2 = font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
			mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ThemeManager.color("text_secondary"))
