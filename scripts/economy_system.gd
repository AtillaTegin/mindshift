class_name EconomySystem
extends Node
## Coins (spec 4.8). Structure only: real-money purchases come later and will
## simply call earn(). The balance lives in the SaveSystem and every change is
## saved at once. All prices and rewards are v1 guesses kept here for balancing.

signal coins_changed(coins: int)

const HINT_COST: int = 1
## Undos that cost nothing in one attempt at a level; each further undo costs UNDO_COST.
const FREE_UNDOS_PER_ATTEMPT: int = 3
const UNDO_COST: int = 1
## Paid for each star earned for the first time, so replaying for coins pays nothing.
const COINS_PER_NEW_STAR: int = 2
const DAILY_BONUS: int = 5

var save: SaveSystem

var coins: int:
	get:
		return save.coins if save != null else 0


func setup(p_save: SaveSystem) -> void:
	save = p_save


func can_afford(cost: int) -> bool:
	return cost <= coins


## Takes `cost` coins if the balance allows; returns whether it did.
func spend(cost: int) -> bool:
	if cost < 0 or not can_afford(cost):
		return false
	if cost > 0:
		_set_coins(coins - cost)
	return true


## Adds coins. `reason` names the source ("level_complete", "daily_bonus", ...)
## for future analytics; it does not change the amount.
func earn(amount: int, _reason: String) -> void:
	if amount > 0:
		_set_coins(coins + amount)


## Undo price given how many undos were already used in this attempt.
static func undo_cost(undos_used: int) -> int:
	return 0 if undos_used < FREE_UNDOS_PER_ATTEMPT else UNDO_COST


## Coins for finishing a level with `stars` when the best so far was `previous_stars`.
static func level_reward(stars: int, previous_stars: int) -> int:
	return maxi(stars - previous_stars, 0) * COINS_PER_NEW_STAR


## Grants the daily bonus once per calendar day ("YYYY-MM-DD"); returns the
## coins granted (0 if today's bonus was already taken).
func claim_daily_bonus(today: String) -> int:
	if save == null or save.last_daily_bonus_date == today:
		return 0
	save.last_daily_bonus_date = today
	earn(DAILY_BONUS, "daily_bonus")
	return DAILY_BONUS


func _set_coins(value: int) -> void:
	save.coins = value
	save.write()
	coins_changed.emit(value)
