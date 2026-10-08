extends "res://tests/test_case.gd"
## Goal preview (economy/UX addendum 6): every disk shows its size number, and
## the number is legible and fits on the disk even for 10-disk Expert goals.

## Board width at the 720 px design size (viewport minus the 24 px margins).
const BOARD_WIDTH: float = 672.0

var _preview: BoardPreview


func before_each() -> void:
	_preview = BoardPreview.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_preview)


func after_each() -> void:
	_preview.get_parent().remove_child(_preview)
	_preview.free()


func _show(state: PuzzleState) -> void:
	_preview.position_state = state
	_preview.size = Vector2(BOARD_WIDTH, _preview.custom_minimum_size.y)


func test_every_disk_is_numbered_legibly_in_every_tier() -> void:
	var font: Font = _preview.get_theme_default_font()
	for tier: String in Difficulty.ORDER:
		for index: int in [1, LevelCatalog.level_count(tier)]:
			var goal: PuzzleState = LevelCatalog.load_level(tier, index).goal
			_show(goal)
			var labels: Array[Dictionary] = _preview.get_disk_labels()
			var numbers: Array[int] = []
			for label: Dictionary in labels:
				numbers.append(label["disk"])
				var rect: Rect2 = label["rect"]
				var font_size: int = label["font_size"]
				var where: String = "%s %d, disk %d" % [tier, index, label["disk"]]
				assert_true(font_size >= BoardPreview.MIN_FONT_SIZE, "%s: font %d" % [where, font_size])
				var text_size: Vector2 = font.get_string_size(str(label["disk"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				assert_true(text_size.x <= rect.size.x - 4.0, "%s: number fits the width" % where)
				assert_true(rect.size.y >= BoardPreview.DISK_HEIGHT - 2.0, "%s: full-height disk" % where)
			numbers.sort()
			var expected: Array[int] = []
			for disk: int in range(1, goal.get_disk_count() + 1):
				expected.append(disk)
			assert_eq(numbers, expected, "%s %d: one number per disk" % [tier, index])


func test_height_follows_the_disk_count() -> void:
	assert_eq(BoardPreview.preferred_height(3), BoardPreview.MIN_HEIGHT, "small goals keep the old compact size")
	assert_eq(BoardPreview.preferred_height(10), 10.0 + BoardPreview.DISK_HEIGHT * 11.0, "10 disks at full height")
	_show(LevelCatalog.load_level("expert", 1).goal)
	assert_eq(_preview.custom_minimum_size.y, BoardPreview.preferred_height(_preview.position_state.get_disk_count()))
