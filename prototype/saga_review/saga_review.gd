extends ScrollContainer

@onready var _chapters: VBoxContainer = $Chapters


func _ready() -> void:
	resized.connect(_fit_chapters)
	_fit_chapters()


func _fit_chapters() -> void:
	for chapter: Control in _chapters.get_children():
		chapter.custom_minimum_size.y = size.y
