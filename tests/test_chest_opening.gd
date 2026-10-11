extends "res://tests/test_case.gd"
## The chest opening (economy formulas addendum v3.1): build-up, burst, and a
## result that either flies a coin to the counter with a ding or answers an
## empty chest gently. Also the code-made ding itself.

var _chest: ChestOpening
var _landed: Array[int] = []
var _finished: int = 0


func before_each() -> void:
	_chest = ChestOpening.new()
	_chest.size = Vector2(500, 230)
	(Engine.get_main_loop() as SceneTree).root.add_child(_chest)
	_landed.clear()
	_finished = 0
	_chest.coins_landed.connect(func(coins: int) -> void: _landed.append(coins))
	_chest.finished.connect(func() -> void: _finished += 1)


func after_each() -> void:
	_chest.get_parent().remove_child(_chest)
	_chest.free()


func _open_time() -> float:
	return ChestOpening.BUILD_SECONDS + ChestOpening.BURST_SECONDS


func test_build_up_trembles_and_glows_in_the_dress_colour() -> void:
	assert_eq(_chest.phase(), "idle")
	_chest.play(1, "jade", Vector2(600, 40))
	assert_eq(_chest.phase(), "build")
	assert_eq(_chest.glow_color(), ThemeManager.skin_color("jade", "mark"), "green jade on a Nine Rings level")
	var angles: Array[float] = []
	for i: int in 8:
		_chest.advance(0.1)
		angles.append(_chest.lid_angle())
	assert_true(angles.max() > 0.01 and angles.min() < -0.01, "the lid trembles: %s" % str(angles))
	assert_true(absf(angles[-1]) <= 0.07, "but stays shut")
	assert_eq(_chest.get_caption(), "", "no result yet")
	_chest.play(1, "", Vector2.ZERO)
	assert_eq(_chest.glow_color(), ThemeManager.icon_color("chest_band"), "gold on a classic level")
	_chest.play(0, "wood", Vector2.ZERO)
	assert_eq(_chest.glow_color(), ThemeManager.skin_color("wood", "mark"), "karakuri wood")


func test_burst_opens_the_lid_with_sparks() -> void:
	_chest.play(1, "wood", Vector2(600, 40))
	assert_false(_chest.is_sparking())
	_chest.advance(ChestOpening.BUILD_SECONDS + 0.05)
	assert_eq(_chest.phase(), "burst")
	assert_true(_chest.is_sparking(), "sparks fly")
	_chest.advance(ChestOpening.BURST_SECONDS)
	assert_true(_chest.lid_angle() < -1.0, "the lid is wide open")


func test_coin_rises_flies_to_the_counter_and_dings() -> void:
	var target: Vector2 = Vector2(620, 30)
	_chest.play(3, "", target)
	_chest.advance(_open_time() + 0.01)
	assert_eq(_chest.phase(), "result")
	var start: Vector2 = _chest.coin_position()
	assert_ne(start, Vector2.INF)
	assert_eq(_chest.get_caption(), "+3 coin!")
	_chest.advance(ChestOpening.RISE_SECONDS)
	var risen: Vector2 = _chest.coin_position()
	assert_true(risen.y < start.y, "the coin rises out of the chest first")
	_chest.advance(ChestOpening.FLY_SECONDS * 0.5)
	var local_target: Vector2 = _chest.get_global_transform().affine_inverse() * target
	assert_true(_chest.coin_position().distance_to(local_target) < risen.distance_to(local_target), "then heads for the counter")
	assert_eq(_landed, [] as Array[int], "not there yet")
	_chest.advance(1.0)
	assert_eq(_landed, [3] as Array[int], "lands once")
	assert_true(_chest.ding_played)
	assert_eq(_chest.coin_position(), Vector2.INF, "gone into the counter")
	assert_eq(_chest.phase(), "done")
	assert_eq(_finished, 1)
	_chest.advance(1.0)
	assert_eq(_landed.size(), 1, "never twice")


func test_no_ding_with_sound_off() -> void:
	_chest.sound_enabled = false
	_chest.play(1, "", Vector2.ZERO)
	_chest.advance(10.0)
	assert_eq(_landed, [1] as Array[int])
	assert_false(_chest.ding_played)


func test_an_empty_chest_is_answered_gently() -> void:
	_chest.play(0, "jade", Vector2(600, 40))
	_chest.advance(_open_time() + 0.2)
	assert_eq(_chest.phase(), "result")
	assert_true(_chest.dust_amount() > 0.0, "a small dust puff")
	assert_eq(_chest.coin_position(), Vector2.INF)
	assert_eq(_chest.get_caption(), "Bu dəfə boş çıxdı. Davam et!", "a friendly word, not a loss")
	assert_false(_chest.get_caption().to_lower().contains("uduz"))
	_chest.advance(10.0)
	assert_eq(_chest.phase(), "done")
	assert_eq(_landed, [] as Array[int], "nothing lands")
	assert_false(_chest.ding_played, "no coin, no ding")
	assert_eq(_chest.dust_amount(), 0.0)
	assert_eq(_finished, 1)


func test_stopping_early_still_delivers_the_coins_silently() -> void:
	_chest.play(1, "", Vector2.ZERO)
	_chest.advance(ChestOpening.BUILD_SECONDS * 0.5)
	_chest.stop()
	assert_eq(_landed, [1] as Array[int])
	assert_false(_chest.ding_played)
	assert_false(_chest.visible)


func test_ding_is_made_in_code() -> void:
	var ding: AudioStreamWAV = SoundFx.ding()
	assert_eq(ding.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(ding.data.size(), int(SoundFx.DING_SECONDS * SoundFx.MIX_RATE) * 2)
	var early_peak: int = 0
	for i: int in range(0, 2000):
		early_peak = maxi(early_peak, absi(ding.data.decode_s16(i * 2)))
	var late_peak: int = 0
	for i: int in range(ding.data.size() / 2 - 500, ding.data.size() / 2):
		late_peak = maxi(late_peak, absi(ding.data.decode_s16(i * 2)))
	assert_true(early_peak > 10000, "a clear strike (%d)" % early_peak)
	assert_true(late_peak < early_peak / 10, "that fades away (%d)" % late_peak)
	assert_eq(SoundFx.ding(), ding, "built once")
