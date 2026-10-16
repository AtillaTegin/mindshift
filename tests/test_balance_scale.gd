extends "res://tests/test_case.gd"
## The balance scale of Tərəzi levels (Fəsil Sistemi v1.2, section 5): pans
## that sink on the heavier side, the LCD's difference and limit, the preview
## while a disk is picked up, the refusal, and that it only shows on Tərəzi.

const SAVE_PATH: String = "res://.test_saves/test_balance_scale_save.json"

var _board: GameBoard


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _start(level: Level) -> GameBoard:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.save_system.sound_enabled = false
	_board.tutorials_enabled = false
	_board.background_hints = false
	_board.level_path = ""
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.start_level(level)
	(_board.get_node("%Board") as Control).size = Vector2(672.0, 700.0)
	return _board


func _balance_level() -> Level:
	# Pair 0-1: 3 against 1 (difference 2); pair 2-3: 2 against 0.
	var rule_ids: Array[String] = ["classic_hanoi", "balance"]
	return make_level(17501, rule_ids, [[3], [1], [2], []], [[], [3], [2], [1]], {"balance": {"tolerance": 3}})


func test_scale_shows_on_tarazi_only() -> void:
	_start(_balance_level())
	var scale: BalanceScale = _board.get_node("%Board").get_node("BalanceScale")
	assert_true(scale.visible)
	assert_eq(scale.differences, [2, 2] as Array[int], "left minus right, per pair")
	assert_eq(scale.tolerance, 3)
	assert_true(scale.pan_drop(0) > 0.0, "the heavier left pan sits lower")
	assert_true(scale.pan_drop(1) < 0.0, "and the lighter one higher")
	var left_peg: PegView = _board.get_node("%PegLayer").get_child(0)
	assert_eq(left_peg.lift, scale.pan_drop(0), "the peg rides its pan")
	_start(make_level(17502, ["classic_hanoi"] as Array[String], [[2, 1], [], []], [[], [], [2, 1]]))
	assert_false(_board.get_node("%Board").get_node("BalanceScale").visible, "no scale on a classic level")


func test_preview_and_refusal() -> void:
	_start(_balance_level())
	var scale: BalanceScale = _board.get_node("%Board").get_node("BalanceScale")
	_board.on_peg_pressed(1)  # disk 1 picked up
	# Disk 1 onto peg 0: pair 0 becomes 4 - 0 = 4 > 3, a "✕". Onto peg 2:
	# pair 0 is 3 - 0, pair 1 is 3 - 0: within, peg 2's pair shows 3. Onto
	# peg 3: pair 1 is 2 - 1 = 1.
	assert_eq(scale.preview.get(0), -1, "over the limit")
	assert_eq(scale.preview.get(2), 3)
	assert_eq(scale.preview.get(3), 1)
	_board.on_peg_pressed(0)
	assert_eq(_board.session.move_count, 0, "the scale refuses")
	assert_eq((_board.get_node("%StatusLabel") as Label).text, tr("RULE_BALANCE"), "and says why")
	_board.on_peg_pressed(1)
	assert_true(scale.preview.is_empty(), "nothing picked up, nothing previewed")
