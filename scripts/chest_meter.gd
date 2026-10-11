class_name ChestMeter
extends Control
## The small chest meter (economy formulas addendum v3, section 2): the chest,
## the keys already collected toward it, and a bar of tokens toward the next
## key with "7/15 jeton". Code-drawn; follows the EconomySystem it is given.

const KEY_SIZE: float = 30.0
const FONT_SIZE: int = 22

## Where tokens and keys are read from.
var economy: EconomySystem:
	set(value):
		if economy != null and economy.chest_progress_changed.is_connected(queue_redraw):
			economy.chest_progress_changed.disconnect(queue_redraw)
		economy = value
		if economy != null:
			economy.chest_progress_changed.connect(queue_redraw)
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(380, 48)
	ThemeManager.theme_changed.connect(func(_mode: String) -> void: queue_redraw())


## The text on the bar, e.g. "7/15 jeton".
func get_text() -> String:
	if economy == null:
		return ""
	return tr("CHEST_METER") % [economy.tokens(), EconomySystem.TOKENS_PER_KEY]


func _draw() -> void:
	if economy == null:
		return
	var height: float = size.y
	GameIcons.draw(self, "chest", Rect2(0.0, 0.0, height, height))
	var x: float = height + 10.0
	for i: int in EconomySystem.KEYS_PER_CHEST:
		GameIcons.draw(self, "key", Rect2(x, (height - KEY_SIZE) * 0.5, KEY_SIZE, KEY_SIZE), i >= economy.keys())
		x += KEY_SIZE + 4.0
	x += 8.0
	var bar: Rect2 = Rect2(x, height * 0.5 - 15.0, maxf(size.x - x, 40.0), 30.0)
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = ThemeManager.color("surface")
	back.set_corner_radius_all(15)
	draw_style_box(back, bar)
	var share: float = clampf(float(economy.tokens()) / EconomySystem.TOKENS_PER_KEY, 0.0, 1.0)
	if share > 0.0:
		var fill: StyleBoxFlat = StyleBoxFlat.new()
		fill.bg_color = ThemeManager.color("accent")
		fill.set_corner_radius_all(15)
		draw_style_box(fill, Rect2(bar.position, Vector2(maxf(bar.size.x * share, 30.0), bar.size.y)))
	var font: Font = get_theme_default_font()
	var text: String = get_text()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var baseline: Vector2 = Vector2(bar.get_center().x - text_size.x * 0.5,
			bar.get_center().y + font.get_ascent(FONT_SIZE) * 0.5 - 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ThemeManager.color("text_primary"))
