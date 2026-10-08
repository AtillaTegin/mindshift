class_name PolishedButton
extends Button
## A button that dips slightly while pressed (addendum 2.4). The one place for
## button micro-interaction: change PRESSED_SCALE here to tune every button.
## Optional icon slot (economy/UX addendum 7): set `icon_kind` to a GameIcons
## kind and the icon is drawn just left of the button text, faded when the
## button is disabled.

const PRESSED_SCALE: float = 0.96
const SECONDS: float = 0.08
const ICON_GAP: float = 10.0

## "" for no icon, otherwise one of GameIcons.KINDS.
@export var icon_kind: String = "":
	set(value):
		icon_kind = value
		queue_redraw()

var _tween: Tween


func _ready() -> void:
	button_down.connect(_scale_to.bind(PRESSED_SCALE))
	button_up.connect(_scale_to.bind(1.0))
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


## Where the icon is drawn (local coordinates); empty without an icon.
func get_icon_rect() -> Rect2:
	if not GameIcons.is_known(icon_kind):
		return Rect2()
	var side: float = clampf(size.y * 0.5, 24.0, 44.0)
	var text_width: float = get_theme_font("font").get_string_size(atr(text), HORIZONTAL_ALIGNMENT_LEFT, -1,
			get_theme_font_size("font_size")).x
	var text_left: float = (size.x - text_width) * 0.5
	return Rect2(maxf(text_left - ICON_GAP - side, 4.0), (size.y - side) * 0.5, side, side)


func _draw() -> void:
	if GameIcons.is_known(icon_kind):
		GameIcons.draw(self, icon_kind, get_icon_rect(), disabled)


func _scale_to(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(target, target), SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
