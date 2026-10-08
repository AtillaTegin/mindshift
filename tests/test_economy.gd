extends "res://tests/test_case.gd"
## EconomySystem (spec 4.8, economy/UX addendum 8.1).

const PATH: String = "user://test_economy_save.json"

var _economy: EconomySystem


func before_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	_economy = EconomySystem.new()
	_economy.setup(SaveSystem.new(PATH))
	_economy.date_override = "2026-10-09"
	_economy.time_override = 1_000_000


func after_each() -> void:
	_economy.free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


func _reopened() -> SaveSystem:
	var save: SaveSystem = SaveSystem.new(PATH)
	save.load_save()
	return save


func test_earn_spend_and_afford() -> void:
	var changes: Array[int] = []
	_economy.coins_changed.connect(func(coins: int) -> void: changes.append(coins))
	assert_eq(_economy.coins, 0)
	assert_false(_economy.can_afford(1))
	assert_false(_economy.spend(1), "cannot go below zero")
	_economy.earn(5, "level_complete")
	assert_true(_economy.can_afford(5))
	assert_true(_economy.spend(2))
	assert_eq(_economy.coins, 3)
	assert_true(_economy.spend(0), "free actions always succeed")
	assert_false(_economy.spend(-1), "negative prices are rejected")
	_economy.earn(-4, "bogus")
	assert_eq(_economy.coins, 3, "negative earnings ignored")
	assert_eq(changes, [5, 3] as Array[int])


func test_coins_are_saved_at_once() -> void:
	_economy.earn(7, "level_complete")
	_economy.spend(2)
	assert_eq(_reopened().coins, 5)


func test_level_reward_by_stars_and_only_the_improvement_on_replay() -> void:
	assert_eq(EconomySystem.level_reward(3, 0), 8)
	assert_eq(EconomySystem.level_reward(2, 0), 5)
	assert_eq(EconomySystem.level_reward(1, 0), 3)
	assert_eq(EconomySystem.level_reward(3, 1), 5, "1 -> 3 stars pays the difference")
	assert_eq(EconomySystem.level_reward(3, 2), 3)
	assert_eq(EconomySystem.level_reward(2, 3), 0, "a worse replay pays nothing")
	assert_eq(EconomySystem.level_reward(3, 3), 0, "replaying for coins pays nothing")


func test_daily_bonus_once_per_day() -> void:
	assert_eq(EconomySystem.DAILY_BONUS, 10)
	assert_eq(_economy.claim_daily_bonus("2026-10-07"), 10)
	assert_eq(_economy.claim_daily_bonus("2026-10-07"), 0)
	assert_eq(_economy.claim_daily_bonus("2026-10-08"), 10)
	var reopened: SaveSystem = _reopened()
	assert_eq(reopened.last_daily_bonus_date, "2026-10-08")
	assert_eq(reopened.coins, 20)


func test_hint_cost_by_tier() -> void:
	assert_eq(_economy.hint_cost("easy"), 3)
	assert_eq(_economy.hint_cost("medium"), 3)
	assert_eq(_economy.hint_cost("hard"), 5)
	assert_eq(_economy.hint_cost("expert"), 5)


func test_unlimited_hints_last_24_hours_and_stack() -> void:
	assert_false(_economy.has_unlimited_hints())
	_economy.grant_unlimited_hints()
	assert_true(_economy.has_unlimited_hints())
	assert_eq(_economy.hint_cost("expert"), 0, "free while active")
	assert_eq(_economy.unlimited_hints_seconds_left(), 24 * 3600)
	_economy.time_override += 23 * 3600
	assert_true(_economy.has_unlimited_hints())
	_economy.grant_unlimited_hints()
	assert_eq(_economy.unlimited_hints_seconds_left(), 25 * 3600, "a second purchase adds to the time left")
	_economy.time_override += 25 * 3600
	assert_false(_economy.has_unlimited_hints(), "expired")
	assert_eq(_economy.hint_cost("expert"), 5)
	assert_eq(_reopened().unlimited_hints_until, 1_000_000 + 48 * 3600, "saved")


func test_three_free_undos_per_day_then_one_coin() -> void:
	_economy.earn(2, "test")
	for i: int in 3:
		assert_eq(_economy.undo_cost(), 0)
		assert_true(_economy.pay_for_undo())
	assert_eq(_economy.coins, 2, "free undos cost nothing")
	assert_eq(_economy.free_undos_left(), 0)
	assert_eq(_economy.undo_cost(), 1)
	assert_true(_economy.pay_for_undo())
	assert_true(_economy.pay_for_undo())
	assert_eq(_economy.coins, 0)
	assert_false(_economy.pay_for_undo(), "no free undo and no coins")
	var reopened: SaveSystem = _reopened()
	assert_eq(reopened.free_undos_used, 3, "shared over levels and kept across restarts")
	assert_eq(reopened.daily_date, "2026-10-09")
	_economy.date_override = "2026-10-10"
	assert_eq(_economy.free_undos_left(), 3, "a new day refills them")


func test_rewarded_ads_pay_five_coins_five_times_a_day() -> void:
	for i: int in 5:
		assert_eq(_economy.reward_ad(), 5)
	assert_eq(_economy.ads_left(), 0)
	assert_eq(_economy.reward_ad(), 0, "daily limit")
	assert_eq(_economy.coins, 25)
	_economy.date_override = "2026-10-10"
	assert_eq(_economy.ads_left(), 5)


func test_daily_counters_survive_a_damaged_field() -> void:
	var file: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "coins": 4, "daily": {"date": "2026-10-09", "free_undos_used": "x"},
			"unlimited_hints_until": -5}))
	file.close()
	var save: SaveSystem = _reopened()
	assert_eq(save.coins, 4)
	assert_eq(save.free_undos_used, 0)
	assert_eq(save.unlimited_hints_until, 0)
