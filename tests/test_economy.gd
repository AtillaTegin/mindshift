extends "res://tests/test_case.gd"
## EconomySystem (spec 4.8).

const PATH: String = "user://test_economy_save.json"

var _economy: EconomySystem


func before_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)
	_economy = EconomySystem.new()
	_economy.setup(SaveSystem.new(PATH))


func after_each() -> void:
	_economy.free()
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(PATH)


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
	var reopened: SaveSystem = SaveSystem.new(PATH)
	reopened.load_save()
	assert_eq(reopened.coins, 5)


func test_undo_cost_and_level_reward() -> void:
	for used: int in EconomySystem.FREE_UNDOS_PER_ATTEMPT:
		assert_eq(EconomySystem.undo_cost(used), 0)
	assert_eq(EconomySystem.undo_cost(EconomySystem.FREE_UNDOS_PER_ATTEMPT), EconomySystem.UNDO_COST)
	assert_eq(EconomySystem.level_reward(3, 0), 3 * EconomySystem.COINS_PER_NEW_STAR)
	assert_eq(EconomySystem.level_reward(3, 2), EconomySystem.COINS_PER_NEW_STAR, "only the new star pays")
	assert_eq(EconomySystem.level_reward(2, 3), 0, "a worse replay pays nothing")
	assert_eq(EconomySystem.level_reward(3, 3), 0, "replaying for coins pays nothing")


func test_daily_bonus_once_per_day() -> void:
	assert_eq(_economy.claim_daily_bonus("2026-10-07"), EconomySystem.DAILY_BONUS)
	assert_eq(_economy.claim_daily_bonus("2026-10-07"), 0)
	assert_eq(_economy.coins, EconomySystem.DAILY_BONUS)
	assert_eq(_economy.claim_daily_bonus("2026-10-08"), EconomySystem.DAILY_BONUS)
	var reopened: SaveSystem = SaveSystem.new(PATH)
	reopened.load_save()
	assert_eq(reopened.last_daily_bonus_date, "2026-10-08")
	assert_eq(reopened.coins, 2 * EconomySystem.DAILY_BONUS)
