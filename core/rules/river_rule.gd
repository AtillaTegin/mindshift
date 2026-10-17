class_name RiverRule
extends RuleBase
## "Fil Çayı" (ICRA World 5-9, section 3.2; the xiangqi elephant may not
## cross the river): a river splits the pegs into two banks, and the disks of
## size `elephant` and up are elephants that never cross it. The goal is one
## position: the small disks on the other bank, the elephants rearranged on
## their own. On top of classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "river"],
##   "rule_params": {"river": {"banks": [0, 0, 1, 1], "elephant": 5}}
## `banks`: per peg 0 (left bank), 1 (right bank) or 2 (a ferry in the river).
## Sub-elements:
##   "bridges": [[a, b]]       "Daş körpü": elephants cross between a and b too
##   a peg of bank 2           "Bərə": the ferry holds one disk and every disk,
##                             elephants too, reaches it from either bank and
##                             leaves it for either, so elephants cross one by one
##   "crossings": [[a, b, n]]  "İki keçid": disks cross the river only between
##                             a and b, and only up to size n (elephants never)
##   "reverse": true           "Tərs çay": only elephants cross, small disks never
##   "fire": true              "Novruz tonqalı" (the island): a bonfire instead
##                             of the river; only the two smallest disks jump over
##                             it (the elephants are 3 and up)
##   "ferry_small": true       only for measuring (LevelForge.settings_without):
##                             the ferry carries no elephant

const ID: String = "river"
const LEFT: int = 0
const RIGHT: int = 1
const FERRY: int = 2

var banks: Array[int] = []
var elephant: int = 0
var bridges: Array[Array] = []
var crossings: Array[Array] = []
var reverse: bool = false
var fire: bool = false
var ferry_small: bool = false


func _init() -> void:
	violation_message = "RULE_ELEPHANT"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"banks\": [0, 1 or 2 per peg] and \"elephant\": size, optional \"bridges\": [[a, b]], \"crossings\": [[a, b, size]], \"reverse\"/\"fire\": true" % ID
	for key: String in params:
		if not key in ["banks", "elephant", "bridges", "crossings", "reverse", "fire", "ferry_small"]:
			return problem
	var sides: Variant = params.get("banks")
	if typeof(sides) != TYPE_ARRAY or not (sides as Array).all(func(v: Variant) -> bool:
			return typeof(v) == TYPE_INT and v >= LEFT and v <= FERRY):
		return problem
	banks.assign(sides)
	if banks.count(LEFT) < 2 or banks.count(RIGHT) < 2 or banks.count(FERRY) > 1:
		return problem
	var size: Variant = params.get("elephant")
	if typeof(size) != TYPE_INT or size < 2:
		return problem
	elephant = size
	for key: String in ["bridges", "crossings"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY:
			return problem
		for item: Variant in list:
			if typeof(item) != TYPE_ARRAY or (item as Array).size() != (2 if key == "bridges" else 3) \
					or not (item as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0):
				return problem
		(bridges if key == "bridges" else crossings).assign(list)
	for key: String in ["reverse", "fire", "ferry_small"]:
		if typeof(params.get(key, false)) != TYPE_BOOL:
			return problem
	reverse = params.get("reverse", false)
	fire = params.get("fire", false)
	ferry_small = params.get("ferry_small", false)
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"banks": banks.duplicate(), "elephant": elephant}
	if not bridges.is_empty():
		params["bridges"] = bridges.duplicate(true)
	if not crossings.is_empty():
		params["crossings"] = crossings.duplicate(true)
	if reverse:
		params["reverse"] = true
	if fire:
		params["fire"] = true
	if ferry_small:
		params["ferry_small"] = true
	return params


func bank_of(peg: int) -> int:
	return banks[peg] if peg < banks.size() else LEFT


## The ferry peg, or -1.
func ferry() -> int:
	return banks.find(FERRY)


func is_elephant(disk: int) -> bool:
	return disk >= elephant


## Whether a and b are joined by a stone bridge.
func bridged(a: int, b: int) -> bool:
	for bridge: Array in bridges:
		if (int(bridge[0]) == a and int(bridge[1]) == b) or (int(bridge[0]) == b and int(bridge[1]) == a):
			return true
	return false


## The largest disk the crossing between a and b lets over, or 0 (none there).
func crossing_limit(a: int, b: int) -> int:
	for crossing: Array in crossings:
		if (int(crossing[0]) == a and int(crossing[1]) == b) or (int(crossing[0]) == b and int(crossing[1]) == a):
			return crossing[2]
	return 0


## Whether `disk` may go from one bank to the other between a and b: a stone
## bridge carries elephants wherever the small disks cross.
func may_cross(disk: int, a: int, b: int) -> bool:
	if reverse:
		return is_elephant(disk)
	if is_elephant(disk):
		return bridged(a, b)
	return crossings.is_empty() or disk <= crossing_limit(a, b)


func is_disk_move_allowed(disk: int, from_peg: int, to_peg: int, target_top: int) -> bool:
	var here: int = bank_of(from_peg)
	var there: int = bank_of(to_peg)
	if there == FERRY:
		return target_top == -1 and not (ferry_small and is_elephant(disk))
	if here == FERRY or here == there:
		return true
	return may_cross(disk, from_peg, to_peg)


func supports_disk_move_check() -> bool:
	return true


## The ferry holds one disk at most.
func is_state_valid(state: PuzzleState) -> bool:
	if state.get_peg_count() != banks.size():
		return false
	var boat: int = ferry()
	return boat == -1 or state.pegs[boat].size() <= 1


## A full ferry, a crossing too narrow, small disks at a reversed river and
## the bonfire say so; an elephant at the river is the rule's own message.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	var disk: int = state.get_top_disk(move.from_peg)
	if bank_of(move.to_peg) == FERRY:
		return "RULE_FERRY_FULL"
	if reverse:
		return "RULE_RIVER_REVERSE"
	if fire:
		return "RULE_BONFIRE"
	if not crossings.is_empty() and not is_elephant(disk):
		return "RULE_CROSSING"
	return violation_message


## The banks, bridges and crossings name pegs by their place.
func peg_symmetry() -> String:
	return PEGS_FIXED
