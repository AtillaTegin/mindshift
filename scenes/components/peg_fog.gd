class_name PegFog
extends Scrim
## The karakuri box over a covered peg (cultural integration addendum 2): a
## small, opaque variant of the 6B Scrim over the disks the player cannot see.
## The board sizes it: the whole peg while the box is closed, then only the
## disks still hidden at the bottom, shrinking a layer at a time. It reuses the
## Scrim's fade (show_scrim / hide_scrim). With the wood dress it looks like a
## wooden puzzle box. Purely visual: the game state underneath is complete, and
## it never takes input. Coordinates are local to the parent (the board).

const CORNER_RADIUS: int = 14
## How long opening one layer takes.
const LAYER_SECONDS: float = 0.25

## Dress of the level (ThemeManager.SKINS); "wood" draws a wooden box.
var skin: String = "":
	set(value):
		skin = value
		queue_redraw()

var _resize: Tween
## Where the box is (or is sliding to).
var _target: Rect2 = Rect2()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


## Covers `area` (shown at once, without a fade-in, so nothing peeks through
## when a level opens).
func cover(area: Rect2) -> void:
	_target = area
	position = area.position
	size = area.size
	color = ThemeManager.color("fog")
	show_scrim()
	if _fade != null:
		_fade.kill()
	modulate.a = 1.0


## Moves the fog with the board; `animated` slides it to the new area (a box
## layer opening).
func follow(area: Rect2, animated: bool = false) -> void:
	_target = area
	if _resize != null:
		_resize.kill()
		_resize = null
	if not animated or (position.is_equal_approx(area.position) and size.is_equal_approx(area.size)):
		position = area.position
		size = area.size
		return
	_resize = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_resize.tween_property(self, "position", area.position, LAYER_SECONDS)
	_resize.tween_property(self, "size", area.size, LAYER_SECONDS)


## The area the box covers once any layer animation has finished.
func get_target_area() -> Rect2:
	return _target


## Fades the box away (nothing hidden is left).
func reveal() -> void:
	hide_scrim()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		color = ThemeManager.color("fog")
		queue_redraw()


func _draw() -> void:
	if not skin.is_empty():
		_draw_box()
		return
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


## A wooden box in the level's dress: grain lines, a darker rim and a clasp
## with a question mark.
func _draw_box() -> void:
	var wood: Color = ThemeManager.skin_color(skin, "mark")
	var grain: Color = ThemeManager.skin_color(skin, "pattern")
	var light: Color = ThemeManager.skin_color(skin, "board")
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = wood
	box.set_corner_radius_all(CORNER_RADIUS)
	box.set_border_width_all(4)
	box.border_color = wood.darkened(0.25)
	draw_style_box(box, Rect2(Vector2.ZERO, size))
	var y: float = 14.0
	while y < size.y - 10.0:
		draw_line(Vector2(10.0, y), Vector2(size.x - 10.0, y + 3.0), grain, 2.0, true)
		y += 16.0
	var clasp: Vector2 = Vector2(size.x * 0.5, minf(size.y * 0.5, 60.0))
	draw_circle(clasp, 18.0, light, true, -1.0, true)
	var font: Font = get_theme_default_font()
	var font_size: int = 26
	var text_size: Vector2 = font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, clasp + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.38), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, wood)
