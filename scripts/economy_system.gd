class_name EconomySystem
extends Node
## Coins (spec 4.8, economy/UX addendum 8.1). The balance and the daily
## counters live in the SaveSystem and every change is saved at once. Coins
## never block progress (levels open by completion, not by money); they make
## the comfort tools, hints and extra undos, feel a little valuable. Every
## number is a constant here so balancing is a one-line change.

signal coins_changed(coins: int)
## Free undos, watched ads or the unlimited-hint offer changed.
signal allowances_changed

## Coins for a level by stars. A replay pays only the difference to the best
## result so far, so replaying for coins pays nothing (user decision 2026-10-09).
const STAR_REWARDS: Dictionary = {1: 3, 2: 5, 3: 8}
const DAILY_BONUS: int = 10
const HINT_COSTS: Dictionary = {"easy": 3, "medium": 3, "hard": 5, "expert": 5}
## Free undos per calendar day, shared by all levels; later undos cost UNDO_COST.
const FREE_UNDOS_PER_DAY: int = 3
const UNDO_COST: int = 1
## Rewarded ads (stubbed until an ad SDK is added).
const AD_REWARD: int = 5
const ADS_PER_DAY: int = 5
const UNLIMITED_HINT_HOURS: int = 24

var save: SaveSystem
## Test hooks: a fixed "YYYY-MM-DD" day and unix time instead of the system clock.
var date_override: String = ""
var time_override: int = -1

var coins: int:
	get:
		return save.coins if save != null else 0


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


## Coins a result with `stars` is worth (0 for none).
static func star_reward(stars: int) -> int:
	return STAR_REWARDS.get(stars, 0)


## Coins for finishing a level with `stars` when the best so far was `previous_stars`.
static func level_reward(stars: int, previous_stars: int) -> int:
	return maxi(star_reward(stars) - star_reward(previous_stars), 0)


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
