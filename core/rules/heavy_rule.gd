class_name HeavyRule
extends RuleBase
## "Ağır Disk" (ICRA World 5-9, section 3.7): the pegs stand in a line and
## each disk goes at most its reach in pegs (0: any distance); small disks go
## anywhere, middle ones two pegs, large ones only to a neighbour. The dots on
## a disk show its reach (∞ for none). On top of classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "heavy"], "rule_params": {"heavy": {"reach": [0, 0, 2, 2, 1, 1]}}
## Settings (reach is per disk, disk 1 first; "Tərs çəki" is just a reach
## that falls with size):
##   "cart": peg      "Araba": a peg that holds one disk; a disk leaving it goes
##                    any distance
##   "fatigue": true  "Yorğunluq": a disk of reach 1 never moves twice in a row
##   "uphill": true   "Yoxuş": to the right a limited disk goes half its reach
##                    (rounded up)
##   "stop": peg      only for measuring (LevelForge.settings_without): the
##                    cart's peg as a plain one-disk stop, no free way out

const ID: String = "heavy"

var reach: Array[int] = []
var cart: int = -1
var stop: int = -1
var fatigue: bool = false
var uphill: bool = false


func _init() -> void:
	violation_message = "RULE_HEAVY"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"reach\": [per disk, 0 for any], optional \"cart\": peg, \"fatigue\"/\"uphill\": true" % ID
	for key: String in params:
		if not key in ["reach", "cart", "stop", "fatigue", "uphill"]:
			return problem
	var list: Variant = params.get("reach")
	if typeof(list) != TYPE_ARRAY or (list as Array).is_empty() \
			or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0):
		return problem
	reach.assign(list)
	for key: String in ["cart", "stop"]:
		var peg: Variant = params.get(key, -1)
		if typeof(peg) != TYPE_INT or peg < -1:
			return problem
	cart = params.get("cart", -1)
	stop = params.get("stop", -1)
	for key: String in ["fatigue", "uphill"]:
		if typeof(params.get(key, false)) != TYPE_BOOL:
			return problem
	fatigue = params.get("fatigue", false)
	uphill = params.get("uphill", false)
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"reach": reach.duplicate()}
	if cart >= 0:
		params["cart"] = cart
	if stop >= 0:
		params["stop"] = stop
	if fatigue:
		params["fatigue"] = true
	if uphill:
		params["uphill"] = true
	return params


## How far `disk` may go from `from_peg` towards `to_peg` (0: any distance).
func reach_of(disk: int, from_peg: int = 0, to_peg: int = 0) -> int:
	var far: int = reach[disk - 1] if disk >= 1 and disk <= reach.size() else 0
	if uphill and far > 0 and to_peg > from_peg:
		far = (far + 1) / 2
	return far


func is_disk_move_allowed_after(disk: int, from_peg: int, to_peg: int, target_top: int, last_disk: int) -> bool:
	if (to_peg == cart or to_peg == stop) and target_top != -1:
		return false
	if fatigue and disk == last_disk and reach_of(disk) == 1:
		return false
	if from_peg == cart:
		return true
	var far: int = reach_of(disk, from_peg, to_peg)
	return far == 0 or absi(to_peg - from_peg) <= far


func is_disk_move_allowed(disk: int, from_peg: int, to_peg: int, target_top: int) -> bool:
	return is_disk_move_allowed_after(disk, from_peg, to_peg, target_top, 0)


func uses_last_move() -> bool:
	return fatigue


func supports_disk_move_check() -> bool:
	return true


## The cart holds one disk at most.
func is_state_valid(state: PuzzleState) -> bool:
	for peg: int in [cart, stop]:
		if peg >= 0 and (peg >= state.get_peg_count() or state.pegs[peg].size() > 1):
			return false
	return true


## A full cart, a tired disk and a too far step say so.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	var disk: int = state.get_top_disk(move.from_peg)
	if move.to_peg == cart and not state.pegs[cart].is_empty():
		return "RULE_CART_FULL"
	if fatigue and disk == state.last_moved_disk and reach_of(disk) == 1:
		return "RULE_FATIGUE"
	return violation_message


## A line reads the same both ways, but not uphill or with its cart.
func peg_symmetry() -> String:
	return PEGS_LINE if cart < 0 and not uphill else PEGS_FIXED
