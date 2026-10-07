extends CanvasLayer
## Autoload "ScreenTransition" (addendum 2.4): every scene change goes through
## here as fade out -> switch -> fade in, so screens never jump. Input is
## blocked while the screen is covered.

signal finished

const FADE_SECONDS: float = 0.18

var _cover: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	_cover = ColorRect.new()
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	_cover.modulate.a = 0.0
	_cover.visible = false
	add_child(_cover)


func is_busy() -> bool:
	return _busy


## How much the cover hides the screen (0..1).
func get_cover_alpha() -> float:
	return _cover.modulate.a if _cover.visible else 0.0


func change_scene(path: String) -> void:
	run(func() -> void: get_tree().change_scene_to_file(path))


## Fades out, calls `switch` while the screen is covered, then fades back in.
## Ignored while another transition runs.
func run(switch: Callable) -> void:
	if _busy:
		return
	_busy = true
	# The cover matches the current (light or dark) background.
	_cover.color = ThemeManager.color("background")
	_cover.visible = true
	var tween: Tween = create_tween()
	tween.tween_property(_cover, "modulate:a", 1.0, FADE_SECONDS)
	await tween.finished
	switch.call()
	# Let the new scene build and lay out before revealing it.
	await get_tree().process_frame
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_cover, "modulate:a", 0.0, FADE_SECONDS)
	await tween.finished
	_cover.visible = false
	_busy = false
	finished.emit()
