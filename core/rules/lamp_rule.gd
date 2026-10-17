class_name LampRule
extends RuleBase
## "Çıraq" (ICRA World 5-9, section 3.13; the oil lamp of old Azerbaijani
## homes): the board is dark. The lamp stands on the peg where the last disk
## was put and lights it and its neighbours; a disk is only taken from a lit
## peg and only put on one. Before the first move the lamp is on its marked
## peg. On top of classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "lamp"], "rule_params": {"lamp": {"start": 2}}
## Settings:
##   "circle": true    the pegs stand round a circle (the ends are neighbours)
##   "radius": 2       "Uzun işıq": the lamp lights two pegs to each side
##   "fixed": peg      "Sabit fənər": that peg is always lit
##   "two": true       "İki çıraq": lamps on the last two pegs disks went to
##                     (the memory: the one before, peg + 1)
##   "carrier": disk   "Fənərçi disk": the lamp stands where that disk is, and
##                     moves only with it

const ID: String = "lamp"

var start: int = 0
var circle: bool = false
var radius: int = 1
var fixed: int = -1
var two: bool = false
var carrier: int = 0


func _init() -> void:
	violation_message = "RULE_DARK"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"start\": peg, optional \"circle\"/\"two\": true, \"radius\", \"fixed\": peg, \"carrier\": disk" % ID
	for key: String in params:
		if not key in ["start", "circle", "radius", "fixed", "two", "carrier"]:
			return problem
	for key: String in ["start", "radius", "fixed", "carrier"]:
		if typeof(params.get(key, 0)) != TYPE_INT:
			return problem
	for key: String in ["circle", "two"]:
		if typeof(params.get(key, false)) != TYPE_BOOL:
			return problem
	start = params.get("start", 0)
	radius = params.get("radius", 1)
	fixed = params.get("fixed", -1)
	carrier = params.get("carrier", 0)
	circle = params.get("circle", false)
	two = params.get("two", false)
	if start < 0 or radius < 1 or fixed < -1 or carrier < 0 or (two and carrier > 0):
		return problem
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"start": start}
	if circle:
		params["circle"] = true
	if radius != 1:
		params["radius"] = radius
	if fixed >= 0:
		params["fixed"] = fixed
	if two:
		params["two"] = true
	if carrier > 0:
		params["carrier"] = carrier
	return params


## The pegs the lamps stand on with `facts`.
func lamps(facts: MoveFacts) -> Array[int]:
	var found: Array[int] = []
	if carrier > 0:
		found.append(facts.peg_of[carrier] if carrier < facts.peg_of.size() else start)
		return found
	found.append(facts.peg_of[facts.last_disk] if facts.last_disk > 0 and facts.last_disk < facts.peg_of.size() else start)
	if two and facts.memory > 0:
		found.append(facts.memory - 1)
	return found


func distance(a: int, b: int, peg_count: int) -> int:
	var gap: int = absi(a - b)
	return mini(gap, peg_count - gap) if circle else gap


## Whether `peg` is lit with `facts`.
func is_lit(peg: int, facts: MoveFacts) -> bool:
	if peg == fixed:
		return true
	for lamp: int in lamps(facts):
		if distance(peg, lamp, facts.peg_count()) <= radius:
			return true
	return false


func is_move_allowed_with(_disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return is_lit(from_peg, facts) and is_lit(to_peg, facts)


func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	return disk >= facts.peg_of.size() or is_lit(facts.peg_of[disk], facts)


func pick_up_message(_disk: int, _facts: MoveFacts) -> String:
	return violation_message


func needs_facts() -> bool:
	return true


func uses_last_move() -> bool:
	return carrier == 0


func uses_memory() -> bool:
	return two


func memory_states(peg_count: int, _disk_count: int) -> int:
	return peg_count + 1 if two else 1


## Two lamps: the lamp before this move's one (where the last disk went).
func memory_after(facts: MoveFacts, _disk: int, _from_peg: int, _to_peg: int) -> int:
	if not two:
		return facts.memory
	var current: int = facts.peg_of[facts.last_disk] if facts.last_disk > 0 and facts.last_disk < facts.peg_of.size() else start
	return current + 1


## The marked start, the fixed lantern and the circle tie the pegs' places.
func peg_symmetry() -> String:
	return PEGS_FIXED
