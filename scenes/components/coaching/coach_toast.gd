class_name CoachToast
extends PanelContainer
## A short message near the bottom of the screen: slides up and fades in,
## stays for a moment, then fades away by itself.

const DEFAULT_SECONDS: float = 1.4
const SLIDE: float = 30.0
const FADE_SECONDS: float = 0.2
const BOTTOM_MARGIN: float = 150.0

var _label: Label
var _tween: Tween


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.17, 0.18, 0.26, 0.94)
	box.set_corner_radius_all(22)
	box.content_margin_left = 30.0
	box.content_margin_right = 30.0
	box.content_margin_top = 16.0
	box.content_margin_bottom = 16.0
	add_theme_stylebox_override("panel", box)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_label)
	visible = false


## Shows `text` for `seconds` (plus the fades). A new message replaces the old.
func show_message(text: String, seconds: float = DEFAULT_SECONDS) -> void:
	if _tween != null:
		_tween.kill()
	var viewport_size: Vector2 = get_viewport_rect().size
	# Wrap by hand: an autowrapping Label only knows its height after layout,
	# which would leave the panel oversized on the first frame.
	_label.text = _wrap(text, viewport_size.x - 140.0)
	size = Vector2.ZERO
	reset_size()
	var resting: Vector2 = Vector2((viewport_size.x - size.x) * 0.5, viewport_size.y - BOTTOM_MARGIN - size.y)
	position = resting + Vector2(0, SLIDE)
	modulate.a = 0.0
	visible = true
	_tween = create_tween()
	_tween.set_parallel()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	_tween.tween_property(self, "position", resting, FADE_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.set_parallel(false)
	_tween.tween_interval(seconds)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	_tween.tween_callback(func() -> void: visible = false)


## The message as given (without the line breaks added for wrapping).
func get_text() -> String:
	return _label.text.replace("\n", " ")


## Greedy word wrap of `text` to lines no wider than `max_width`.
func _wrap(text: String, max_width: float) -> String:
	var font: Font = _label.get_theme_font("font")
	var font_size: int = _label.get_theme_font_size("font_size")
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in text.split(" ", false):
		var candidate: String = word if line.is_empty() else line + " " + word
		if line.is_empty() or font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			line = candidate
		else:
			lines.append(line)
			line = word
	if not line.is_empty():
		lines.append(line)
	return "\n".join(lines)


func hide_now() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
