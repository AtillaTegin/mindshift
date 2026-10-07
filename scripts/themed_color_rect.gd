class_name ThemedColorRect
extends ColorRect
## A ColorRect filled with a ThemeManager role (screen backgrounds, dimmers);
## it follows light/dark switches by itself.

@export var role: String = "background"


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED or what == NOTIFICATION_READY:
		color = ThemeManager.color(role)
