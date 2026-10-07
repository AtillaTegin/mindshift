class_name PolishedButton
extends Button
## A button that dips slightly while pressed (addendum 2.4). The one place for
## button micro-interaction: change PRESSED_SCALE here to tune every button.

const PRESSED_SCALE: float = 0.96
const SECONDS: float = 0.08

var _tween: Tween


func _ready() -> void:
	button_down.connect(_scale_to.bind(PRESSED_SCALE))
	button_up.connect(_scale_to.bind(1.0))
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _scale_to(target: float) -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2(target, target), SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
