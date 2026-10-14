class_name LevelCell
extends PolishedButton
## One round stop on the level map: its number with the earned stars under it
## (none before the level is played), or a padlock when locked. The next level
## to play is filled with the accent colour; a level with a special mechanic
## wears a ring in its dress colour.

var level_index: int = 0
var stars: int = 0
var locked: bool = false
## The next level to play on its track.
var current: bool = false:
	set(value):
		current = value
		theme_type_variation = &"MapStopCurrent" if current else &"MapStop"
		queue_redraw()
## Visual dress (ThemeManager.SKINS), "" for a classic level.
var skin: String = "":
	set(value):
		skin = value
		queue_redraw()


func _init() -> void:
	theme_type_variation = &"MapStop"


func setup(p_level_index: int, p_stars: int, p_locked: bool) -> void:
	level_index = p_level_index
	stars = p_stars
	locked = p_locked
	text = "" if locked else str(level_index)
	disabled = locked
	queue_redraw()


func _draw() -> void:
	if not skin.is_empty():
		draw_arc(size * 0.5, size.x * 0.5 - 4.0, 0.0, TAU, 48, ThemeManager.skin_color(skin, "mark"), 8.0, true)
	if locked:
		_draw_padlock(size * Vector2(0.5, 0.5), size.y * 0.16)
		return
	if stars == 0:
		return  # not played yet: just the number
	var radius: float = size.y * 0.085
	var y: float = size.y * 0.78
	for i: int in 3:
		var center: Vector2 = Vector2(size.x * 0.5 + (i - 1) * radius * 2.4, y)
		draw_colored_polygon(StarView.star_points(center, radius), ThemeManager.color("star_filled" if i < stars else "star_empty"))


func _draw_padlock(center: Vector2, unit: float) -> void:
	var color: Color = ThemeManager.color("text_secondary")
	draw_arc(center - Vector2(0, unit * 0.4), unit * 0.75, PI, TAU, 16, color, unit * 0.3)
	draw_rect(Rect2(center.x - unit * 1.1, center.y - unit * 0.4, unit * 2.2, unit * 1.7), color)
