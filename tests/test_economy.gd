extends "res://tests/test_case.gd"
## EconomySystem (spec 4.8, economy/UX addendum 8.1).

const PATH: String = "res://.test_saves/test_economy_save.json"

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


func test_levels_pay_tokens_not_coins() -> void:
	# Economy formulas addendum v3: one token per new star, never coins.
	assert_eq(EconomySystem.level_tokens(3, 0), 3)
	assert_eq(EconomySystem.level_tokens(1, 0), 1)
	assert_eq(EconomySystem.level_tokens(3, 1), 2, "a replay counts only the improvement")
	assert_eq(EconomySystem.level_tokens(2, 3), 0, "a worse replay earns nothing")
	assert_eq(EconomySystem.level_tokens(3, 3), 0, "replaying earns nothing")
	var result: Dictionary = _economy.add_tokens(3)
	assert_eq(_economy.coins, 0, "tokens are not coins")
	assert_eq(result, {"tokens": 3, "keys": 0, "chests": [] as Array[int]})
	assert_eq(_economy.tokens(), 3)


func test_tokens_make_keys_and_three_keys_open_a_chest() -> void:
	var changes: Array[int] = []
	_economy.chest_progress_changed.connect(func() -> void: changes.append(_economy.tokens()))
	_economy.add_tokens(14)
	assert_eq([_economy.tokens(), _economy.keys()], [14, 0])
	var result: Dictionary = _economy.add_tokens(3)
	assert_eq(result["keys"], 1, "15 tokens make a key")
	assert_eq([_economy.tokens(), _economy.keys()], [2, 1], "the rest carries over")
	_economy.add_tokens(13)
	assert_eq([_economy.tokens(), _economy.keys()], [0, 2])
	assert_eq(_economy.save.chests_opened, 0)
	_economy.rng.seed = 7
	var expected: int = EconomySystem.chest_coins_for_roll(_rng_with_seed(7).randf())
	result = _economy.add_tokens(15)
	assert_eq(result["keys"], 1)
	assert_eq(result["chests"], [expected] as Array[int], "the third key opens a chest by itself")
	assert_eq([_economy.tokens(), _economy.keys()], [0, 0], "keys are used up")
	assert_eq(_economy.coins, expected, "its coins are paid at once")
	assert_eq(changes.size(), 4)
	var reopened: SaveSystem = _reopened()
	assert_eq([reopened.chest_tokens, reopened.chest_keys, reopened.chests_opened], [0, 0, 1], "kept in the save")


func test_chest_odds() -> void:
	assert_eq(EconomySystem.chest_coins_for_roll(0.0), 0)
	assert_eq(EconomySystem.chest_coins_for_roll(0.599), 0)
	assert_eq(EconomySystem.chest_coins_for_roll(0.6), 1)
	assert_eq(EconomySystem.chest_coins_for_roll(0.899), 1)
	assert_eq(EconomySystem.chest_coins_for_roll(0.9), 3)
	assert_eq(EconomySystem.chest_coins_for_roll(0.9999), 3)
	var rng: RandomNumberGenerator = _rng_with_seed(20261011)
	var counts: Dictionary = {0: 0, 1: 0, 3: 0}
	var total: int = 0
	for i: int in 10000:
		var coins_inside: int = EconomySystem.chest_coins_for_roll(rng.randf())
		counts[coins_inside] += 1
		total += coins_inside
	assert_true(absi(counts[0] - 6000) < 250 and absi(counts[1] - 3000) < 250 and absi(counts[3] - 1000) < 200,
			"60/30/10: %s" % str(counts))
	assert_true(absf(total / 10000.0 - 0.6) < 0.05, "about 0.6 coins per chest on average")


func test_a_whole_run_of_three_star_levels_pays_almost_nothing() -> void:
	# 15 levels with 3 stars: 45 tokens, 3 keys, one chest, 0-3 coins (was 45 coins).
	var coins_from_chests: int = 0
	for i: int in 15:
		for coins_inside: int in _economy.add_tokens(EconomySystem.level_tokens(3, 0))["chests"]:
			coins_from_chests += coins_inside
	assert_eq(_economy.save.chests_opened, 1)
	assert_true(coins_from_chests <= 3)
	assert_eq(_economy.coins, coins_from_chests)


static func _rng_with_seed(value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = value
	return rng

func test_daily_bonus_once_per_day() -> void:
	assert_eq(EconomySystem.DAILY_BONUS, 2, "formulas addendum v3: a thank-you, not an income")
	assert_eq(_economy.claim_daily_bonus("2026-10-07"), 2)
	assert_eq(_economy.claim_daily_bonus("2026-10-07"), 0)
	assert_eq(_economy.claim_daily_bonus("2026-10-08"), 2)
	var reopened: SaveSystem = _reopened()
	assert_eq(reopened.last_daily_bonus_date, "2026-10-08")
	assert_eq(reopened.coins, 4)


func test_undo_is_always_cheaper_than_a_hint() -> void:
	for tier: String in Difficulty.ORDER:
		assert_true(EconomySystem.UNDO_COST < EconomySystem.hint_cost_for_tier(tier), tier)


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


func test_rewarded_ads_pay_four_coins_five_times_a_day() -> void:
	for i: int in 5:
		assert_eq(_economy.reward_ad(), 4)
	assert_eq(_economy.ads_left(), 0)
	assert_eq(_economy.reward_ad(), 0, "daily limit")
	assert_eq(_economy.coins, 20)
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
