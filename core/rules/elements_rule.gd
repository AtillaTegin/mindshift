class_name ElementsRule
extends RuleBase
## "Beş Ünsür" (ICRA World 5-9, section 3.8; Wu Xing): every disk has an
## element, 0 Wood (green), 1 Fire (red), 2 Earth (yellow), 3 Metal (white),
## 4 Water (blue). Each element defeats the one two steps on (Wood Earth,
## Earth Water, Water Fire, Fire Metal, Metal Wood) and creates the next
## (Water Wood, Wood Fire, Fire Earth, Earth Metal, Metal Water). Beside the
## size rule a disk never goes onto the element that defeats it. Level JSON:
##   "rules": ["classic_hanoi", "elements"], "rule_params": {"elements": {"elements": [0, 1, 2, 3, 4]}}
## Settings ("elements" per disk, disk 1 first):
##   "earth": true     "Mərkəzi Torpaq": Earth touches every element
##   "bases": [per peg -1..4]  "Ünsür əsası": a base counts as a disk of that
##                     element under the first disk
##   "creation": true  "Yaradılış yolu": a disk only goes onto the element that
##                     creates it, or onto an empty peg
##   "turning": peg    "Ünsür qülləsi": a disk put on that peg turns into the
##                     next element of creation (the memory: one turn count 0-4
##                     per disk)
##   "changing": true  "Dəyişən ünsür" (the island): a disk turns into the next
##                     element each time it moves (the same memory)

const ID: String = "elements"
const WOOD: int = 0
const FIRE: int = 1
const EARTH: int = 2
const METAL: int = 3
const WATER: int = 4

var elements: Array[int] = []
var earth: bool = false
var bases: Array[int] = []
var creation: bool = false
var turning: int = -1
var changing: bool = false


func _init() -> void:
	violation_message = "RULE_ELEMENT"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"elements\": [0-4 per disk], optional \"earth\"/\"creation\"/\"changing\": true, \"bases\": [-1..4 per peg], \"turning\": peg" % ID
	for key: String in params:
		if not key in ["elements", "earth", "bases", "creation", "turning", "changing"]:
			return problem
	for key: String in ["elements", "bases"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(v: Variant) -> bool:
				return typeof(v) == TYPE_INT and v >= -1 and v <= WATER):
			return problem
	elements.assign(params.get("elements", []))
	bases.assign(params.get("bases", []))
	if elements.is_empty() or elements.has(-1):
		return problem
	for key: String in ["earth", "creation", "changing"]:
		if typeof(params.get(key, false)) != TYPE_BOOL:
			return problem
	earth = params.get("earth", false)
	creation = params.get("creation", false)
	changing = params.get("changing", false)
	var peg: Variant = params.get("turning", -1)
	if typeof(peg) != TYPE_INT or peg < -1:
		return problem
	turning = peg
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"elements": elements.duplicate()}
	if earth:
		params["earth"] = true
	if bases.any(func(b: int) -> bool: return b >= 0):
		params["bases"] = bases.duplicate()
	if creation:
		params["creation"] = true
	if turning >= 0:
		params["turning"] = turning
	if changing:
		params["changing"] = true
	return params


## The element of `disk` with `memory` (its turns so far, a base-5 digit each).
func element_of(disk: int, memory: int = 0) -> int:
	var base: int = elements[disk - 1] if disk >= 1 and disk <= elements.size() else EARTH
	if turning < 0 and not changing:
		return base
	return (base + (memory / int(pow(5, disk - 1))) % 5) % 5


## Whether `upper` may lie on `lower` (two elements).
func may_rest(upper: int, lower: int) -> bool:
	if earth and (upper == EARTH or lower == EARTH):
		return true
	if creation:
		return (lower + 1) % 5 == upper
	return (lower + 2) % 5 != upper


## The element of the peg's base, or -1.
func base_of(peg: int) -> int:
	return bases[peg] if peg < bases.size() else -1


func uses_memory() -> bool:
	return turning >= 0 or changing


func memory_states(_peg_count: int, disk_count: int) -> int:
	return int(pow(5, disk_count)) if uses_memory() else 1


## The disk turns as it lands: the next element of creation on the turning
## peg, or on every move of a changing board.
func memory_after(facts: MoveFacts, disk: int, _from_peg: int, to_peg: int) -> int:
	if not changing and to_peg != turning:
		return facts.memory
	var digit: int = int(pow(5, disk - 1))
	var turns: int = (facts.memory / digit) % 5
	return facts.memory - turns * digit + ((turns + 1) % 5) * digit


## The landing is judged in the element the disk has once it lands.
func is_move_allowed_with(disk: int, from_peg: int, to_peg: int, target_top: int, facts: MoveFacts) -> bool:
	var memory: int = facts.memory
	if uses_memory():
		memory = memory_after(facts, disk, from_peg, to_peg)
	var upper: int = element_of(disk, memory)
	var lower: int = element_of(target_top, memory) if target_top != -1 else base_of(to_peg)
	return lower == -1 or may_rest(upper, lower)


func is_disk_move_allowed(disk: int, _from_peg: int, to_peg: int, target_top: int) -> bool:
	var lower: int = element_of(target_top) if target_top != -1 else base_of(to_peg)
	return lower == -1 or may_rest(element_of(disk), lower)


func needs_facts() -> bool:
	return uses_memory()


func supports_disk_move_check() -> bool:
	return not uses_memory()


## Every disk rests on what it may (and on its peg's base); positions of a
## turning board are judged by the moves only (their memory is unknown here).
func is_state_valid(state: PuzzleState) -> bool:
	if uses_memory():
		return true
	for peg_index: int in state.pegs.size():
		var below: int = base_of(peg_index)
		for disk: int in state.pegs[peg_index]:
			if below != -1 and not may_rest(element_of(disk), below):
				return false
			below = element_of(disk)
	return true


## Creation's stricter rule and a base say which one refused.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	if creation:
		return "RULE_CREATION"
	if state.pegs[move.to_peg].is_empty() and base_of(move.to_peg) != -1:
		return "RULE_ELEMENT_BASE"
	return violation_message


## A base or the turning peg travels with its peg.
func peg_mark(peg_index: int) -> Variant:
	return [base_of(peg_index), peg_index == turning]


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("bases")
	params.erase("turning")
	return params
