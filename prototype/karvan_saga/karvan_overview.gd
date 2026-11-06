extends Control
## Preview the world map silhouette and its existing chapter view.

@onready var _overview: Control = %Overview
@onready var _detail: Control = %Detail
@onready var _back: Button = %Back


func _ready() -> void:
	%Island.pressed.connect(_show_detail.bind(true))
	_back.pressed.connect(_show_detail.bind(false))
	_show_detail(false)


func _show_detail(show_detail: bool) -> void:
	_overview.visible = not show_detail
	_detail.visible = show_detail
	_detail.process_mode = Node.PROCESS_MODE_INHERIT if show_detail else Node.PROCESS_MODE_DISABLED
	_back.visible = show_detail
