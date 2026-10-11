class_name EconomySystem
extends Node
## Coins (spec 4.8, economy/UX addendum 8.1, economy formulas addendum v3).
## The balance, the daily counters and the chest progress live in the
## SaveSystem and every change is saved at once. Coins never block progress
## (levels open by completion, not by money); they make the comfort tools,
## hints and extra undos, feel valuable. Playing well never pays coins
## directly: it fills the chest meter, whose chests hold a few coins at most.
## Rewarded ads and the shop are the real sources. Every number is a constant
## here so balancing is a one-line change.

signal coins_changed(coins: int)
## Free undos, watched ads or the unlimited-hint offer changed.
signal allowances_changed
## Tokens, keys or opened chests changed.
signal chest_progress_changed

## Chest meter (formulas addendum v3, section 2): one token per new star of a
## level (a replay counts only the improvement, so replaying earns nothing),
## TOKENS_PER_KEY tokens make a key, KEYS_PER_CHEST keys open a chest by
## themselves. First guesses, to be tuned by playtesting.
const TOKENS_PER_KEY: int = 15
const KEYS_PER_CHEST: int = 3
## What a chest holds: [coins, chance in percent]; 60% empty, 30% 1 coin, 10% 3.
const CHEST_TABLE: Array = [[0, 60], [1, 30], [3, 10]]
## Balance of a brand-new save: enough for the first hints of the tutorial.
const STARTING_COINS: int = 20
## A small thank-you for coming back, not an income.
const DAILY_BONUS: int = 2
## Hints stay expensive: they reveal a step of the proven optimal solution.
const HINT_COSTS: Dictionary = {"easy": 3, "medium": 3, "hard": 5, "expert": 5}
## Free undos per calendar day, shared by all levels; later undos cost UNDO_COST,
## always less than a hint.
const FREE_UNDOS_PER_DAY: int = 3
const UNDO_COST: int = 1
## Rewarded ads (stubbed until an ad SDK is added).
const AD_REWARD: int = 4
const ADS_PER_DAY: int = 5
const UNLIMITED_HINT_HOURS: int = 24

var save: SaveSystem
## Draws the chest contents; tests seed it.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Test hooks: a fixed "YYYY-MM-DD" day and unix time instead of the system clock.
var date_override: String = ""
var time_override: int = -1

var coins: int:
	get:
		return save.coins if save != null else 0


func _init() -> void:
	rng.randomize()


func setup(p_save: SaveSystem) -> void:
	save = p_save


func today() -> String:
	return date_override if not date_override.is_empty() else Time.get_date_string_from_system()


func now() -> int:
	return time_override if time_override >= 0 else int(Time.get_unix_time_from_system())


func can_afford(cost: int) -> bool:
	return cost <= coins


## Takes `cost` coins if the balance allows; returns whether it did.
func spend(cost: int) -> bool:
	if cost < 0 or not can_afford(cost):
		return false
	if cost > 0:
		_set_coins(coins - cost)
	return true


## Adds coins. `reason` names the source ("level_complete", "daily_bonus",
## "purchase", "rewarded_ad") for future analytics; it does not change the amount.
func earn(amount: int, _reason: String) -> void:
	if amount > 0:
		_set_coins(coins + amount)


## Tokens for finishing a level with `stars` when the best so far was
## `previous_stars`: only the new stars count.
static func level_tokens(stars: int, previous_stars: int) -> int:
	return maxi(stars - previous_stars, 0)


## The coins in a chest for a uniform `roll` in [0, 1), by CHEST_TABLE.
static func chest_coins_for_roll(roll: float) -> int:
	var threshold: float = 0.0
	for entry: Array in CHEST_TABLE:
		threshold += entry[1] / 100.0
		if roll < threshold:
			return entry[0]
	return CHEST_TABLE[-1][0]


func tokens() -> int:
	return save.chest_tokens


func keys() -> int:
	return save.chest_keys


## Adds `count` tokens; full keys and chests follow at once and every chest
## opens by itself. Returns {tokens, keys: keys earned, chests: coins of each
## opened chest}.
func add_tokens(count: int) -> Dictionary:
	var result: Dictionary = {"tokens": maxi(count, 0), "keys": 0, "chests": [] as Array[int]}
	if count <= 0:
		return result
	save.chest_tokens += count
	while save.chest_tokens >= TOKENS_PER_KEY:
		save.chest_tokens -= TOKENS_PER_KEY
		save.chest_keys += 1
		result["keys"] += 1
		if save.chest_keys >= KEYS_PER_CHEST:
			save.chest_keys -= KEYS_PER_CHEST
			save.chests_opened += 1
			var coins_inside: int = chest_coins_for_roll(rng.randf())
			(result["chests"] as Array[int]).append(coins_inside)
			earn(coins_inside, "chest")
	save.write()
	chest_progress_changed.emit()
	return result


static func hint_cost_for_tier(tier: String) -> int:
	return HINT_COSTS.get(tier, HINT_COSTS["expert"])


## What a hint costs right now in `tier` (0 while unlimited hints are active).
func hint_cost(tier: String) -> int:
	return 0 if has_unlimited_hints() else hint_cost_for_tier(tier)


func free_undos_left() -> int:
	_roll_day()
	return maxi(FREE_UNDOS_PER_DAY - save.free_undos_used, 0)


func undo_cost() -> int:
	return 0 if free_undos_left() > 0 else UNDO_COST


## Uses one of today's free undos, or pays UNDO_COST. False if neither is possible.
func pay_for_undo() -> bool:
	if free_undos_left() > 0:
		save.free_undos_used += 1
		save.write()
		allowances_changed.emit()
		return true
	return spend(UNDO_COST)


func ads_left() -> int:
	_roll_day()
	return maxi(ADS_PER_DAY - save.ads_watched, 0)


## Credits one watched rewarded ad; returns the coins given (0 over the daily limit).
func reward_ad() -> int:
	if ads_left() == 0:
		return 0
	save.ads_watched += 1
	earn(AD_REWARD, "rewarded_ad")
	allowances_changed.emit()
	return AD_REWARD


func has_unlimited_hints() -> bool:
	return save != null and save.unlimited_hints_until > now()


func unlimited_hints_seconds_left() -> int:
	return maxi(save.unlimited_hints_until - now(), 0) if save != null else 0


## Makes hints free for `hours` (added on top of time still left).
func grant_unlimited_hints(hours: int = UNLIMITED_HINT_HOURS) -> void:
	save.unlimited_hints_until = maxi(save.unlimited_hints_until, now()) + hours * 3600
	save.write()
	allowances_changed.emit()


## Grants the daily bonus once per calendar day ("YYYY-MM-DD"); returns the
## coins granted (0 if today's bonus was already taken).
func claim_daily_bonus(day: String) -> int:
	if save == null or save.last_daily_bonus_date == day:
		return 0
	save.last_daily_bonus_date = day
	earn(DAILY_BONUS, "daily_bonus")
	return DAILY_BONUS


## Starts fresh daily counters when the day has changed.
func _roll_day() -> void:
	if save.daily_date != today():
		save.daily_date = today()
		save.free_undos_used = 0
		save.ads_watched = 0


func _set_coins(value: int) -> void:
	save.coins = value
	save.write()
	coins_changed.emit(value)
