class_name IconView
extends Control
## Shows one GameIcons icon on its own, e.g. next to the coin balance.

@export_enum("coin", "hint", "undo") var kind: String = "coin":
	set(value):
		kind = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	GameIcons.draw(self, kind, Rect2(Vector2.ZERO, size))
