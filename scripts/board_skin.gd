class_name BoardSkin
extends Control
## The dress behind the board of a level with a special mechanic (level
## structure addendum v3, section 3): a rounded panel in the skin's board
## colour with a code-drawn pattern, no textures. Draws nothing for classic
## levels. Purely visual: it ignores the mouse and knows nothing of the rules.
##   jade: soft jade veins under the nine rings on their bar, after the
##         Chinese Nine Rings puzzle
##   wood: wavy wood grain under a band of yosegi marquetry diamonds, after
##         Japanese karakuri puzzle boxes

## How far the panel reaches past the board on every side.
const BLEED: float = 12.0
const RADIUS: int = 24

## ThemeManager.SKINS key, "" for none.
var skin: String = "":
	set(value):
		skin = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ThemeManager.theme_changed.connect(func(_mode: String) -> void: queue_redraw())


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## The area the panel covers, in local coordinates.
func get_panel_rect() -> Rect2:
	return Rect2(Vector2.ZERO, size).grow(BLEED)


func _draw() -> void:
	if skin.is_empty():
		return
	var area: Rect2 = get_panel_rect()
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = ThemeManager.skin_color(skin, "board")
	panel.set_corner_radius_all(RADIUS)
	draw_style_box(panel, area)
	var inner: Rect2 = area.grow(-float(RADIUS) * 0.5)
	match skin:
		"jade":
			_draw_jade(inner)
		"wood":
			_draw_wood(inner)


func _draw_jade(area: Rect2) -> void:
	var vein: Color = ThemeManager.skin_color(skin, "pattern")
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	# A few long, soft veins, like polished jade.
	for i: int in 4:
		var points: PackedVector2Array = PackedVector2Array()
		var base_y: float = area.position.y + area.size.y * (0.22 + i * 0.2)
		var x: float = area.position.x
		while x <= area.end.x:
			points.append(Vector2(x, base_y + sin(x * 0.011 + i * 2.1) * 18.0 + sin(x * 0.027 + i) * 7.0))
			x += 12.0
		draw_polyline(points, vein, 3.0, true)
	# The nine rings hanging from their bar along the top.
	var bar_y: float = area.position.y + 10.0
	draw_line(Vector2(area.position.x + 14.0, bar_y), Vector2(area.end.x - 14.0, bar_y), mark, 4.0, true)
	var spacing: float = (area.size.x - 64.0) / 8.0
	for i: int in 9:
		var center: Vector2 = Vector2(area.position.x + 32.0 + i * spacing, bar_y + 22.0)
		draw_line(Vector2(center.x, bar_y), center - Vector2(0.0, 12.0), mark, 3.0, true)
		draw_arc(center, 12.0, 0.0, TAU, 24, mark, 3.0, true)

func _draw_wood(area: Rect2) -> void:
	var grain: Color = ThemeManager.skin_color(skin, "pattern")
	var band: float = 26.0
	var y: float = area.position.y + band + 18.0
	var line: int = 0
	while y < area.end.y - 6.0:
		var points: PackedVector2Array = PackedVector2Array()
		var x: float = area.position.x
		while x <= area.end.x:
			points.append(Vector2(x, y + sin(x * 0.018 + line * 1.3) * 4.0))
			x += 14.0
		draw_polyline(points, grain, 2.0, true)
		y += 24.0
		line += 1
	# Yosegi band along the top: diamonds in two woods.
	var mark: Color = ThemeManager.skin_color(skin, "mark")
	var width: float = band * 1.2
	var left: float = area.position.x
	var index: int = 0
	while left + width <= area.end.x:
		var top: Vector2 = Vector2(left + width * 0.5, area.position.y)
		draw_colored_polygon(PackedVector2Array([top, Vector2(left + width, top.y + band * 0.5),
				Vector2(top.x, top.y + band), Vector2(left, top.y + band * 0.5)]), mark if index % 2 == 0 else grain)
		left += width
		index += 1
