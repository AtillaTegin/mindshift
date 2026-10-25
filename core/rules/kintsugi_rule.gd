class_name KintsugiRule
extends RuleBase
## "Kintsugi" (ICRA World 5-9, section 3.12; mending broken pottery with gold
## lacquer): a cracked disk carries at most one disk on top of it. A cracked
## disk put on the golden workshop is mended for good (a gold line shows on
## it) and carries anything from then on. The memory: one bit per cracked
## disk (mended), then one per workshop (closed). On top of classic Hanoi.
## Level JSON:
##   "rules": ["classic_hanoi", "kintsugi"], "rule_params": {"kintsugi": {"cracked": [3, 5], "workshops": [2]}}
## Settings:
##   "deep": true      "Dərin çat": nothing at all on a cracked disk
##   two "workshops"   "İki emalatxana"
##   "single": true    "Tək təmir": a workshop mends one disk, then closes
##   "ordered": true   "Sıralı təmir": the cracked disks are mended largest first
##                     (a smaller one on a workshop before is refused)

const ID: String = "kintsugi"

var cracked: Array[int] = []
var workshops: Array[int] = []
var deep: bool = false
var single: bool = false
var ordered: bool = false


func _init() -> void:
	violation_message = "RULE_CRACKED"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"cracked\": [disks] and \"workshops\": [pegs], optional \"deep\"/\"single\"/\"ordered\": true" % ID
	for key: String in params:
		if not key in ["cracked", "workshops", "deep", "single", "ordered"]:
			return problem
	for key: String in ["cracked", "workshops"]:
		var list: Variant = params.get(key)
		if typeof(list) != TYPE_ARRAY or (list as Array).is_empty() \
				or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0):
			return problem
	cracked.assign(params["cracked"])
	cracked.sort()
	workshops.assign(params["workshops"])
	for key: String in ["deep", "single", "ordered"]:
		if typeof(params.get(key, false)) != TYPE_BOOL:
			return problem
	deep = params.get("deep", false)
	single = params.get("single", false)
	ordered = params.get("ordered", false)
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"cracked": cracked.duplicate(), "workshops": workshops.duplicate()}
	if deep:
		params["deep"] = true
	if single:
		params["single"] = true
	if ordered:
		params["ordered"] = true
	return params


func uses_memory() -> bool:
	return true


## It looks where each broken disk lies (MoveFacts.peg_of).
func needs_facts() -> bool:
	return true


func memory_states(_peg_count: int, _disk_count: int) -> int:
	return 1 << (cracked.size() + workshops.size())


func is_mended(memory: int, disk: int) -> bool:
	var index: int = cracked.find(disk)
	return index == -1 or (memory >> index) & 1 == 1


func is_closed(memory: int, workshop: int) -> bool:
	var index: int = workshops.find(workshop)
	return single and index >= 0 and (memory >> (cracked.size() + index)) & 1 == 1


## The cracked disks still broken with `memory`.
func broken(memory: int) -> Array[int]:
	var found: Array[int] = []
	for disk: int in cracked:
		if not is_mended(memory, disk):
			found.append(disk)
	return found


## How many disks lie above `disk` on its peg (smaller ones on the same peg).
static func _above(facts: MoveFacts, disk: int) -> int:
	var count: int = 0
	var peg: int = facts.peg_of[disk]
	for smaller: int in range(1, disk):
		if smaller < facts.peg_of.size() and facts.peg_of[smaller] == peg:
			count += 1
	return count


## A broken disk on the target peg takes one disk more only while nothing
## (deep: never anything) lies on it; a cracked disk out of order is no job
## for the workshop.
func is_move_allowed_with(disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	for broken_disk: int in broken(facts.memory):
		if broken_disk == disk or broken_disk >= facts.peg_of.size() or facts.peg_of[broken_disk] != to_peg:
			continue
		var above: int = _above(facts, broken_disk) - (1 if from_peg == to_peg else 0)
		if deep or above >= 1:
			return false
	if ordered and workshops.has(to_peg) and not is_closed(facts.memory, to_peg) and cracked.has(disk) \
			and not is_mended(facts.memory, disk):
		for larger: int in cracked:
			if larger > disk and not is_mended(facts.memory, larger):
				return false
	return true


## A cracked disk landing on an open workshop is mended; a single workshop
## closes then.
func memory_after(facts: MoveFacts, disk: int, _from_peg: int, to_peg: int) -> int:
	var memory: int = facts.memory
	if workshops.has(to_peg) and not is_closed(memory, to_peg) and cracked.has(disk) and not is_mended(memory, disk):
		memory |= 1 << cracked.find(disk)
		if single:
			memory |= 1 << (cracked.size() + workshops.find(to_peg))
	return memory


## At the start nothing is mended: no broken disk carries more than it may.
func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for i: int in peg.size():
			if cracked.has(peg[i]) and peg.size() - 1 - i > (0 if deep else 1):
				return false
	return true


func get_violation_message(_state: PuzzleState, move: Move) -> String:
	if ordered and workshops.has(move.to_peg):
		return "RULE_REPAIR_ORDER"
	return "RULE_DEEP_CRACK" if deep else violation_message


## A workshop travels with its peg.
func peg_mark(peg_index: int) -> Variant:
	return workshops.has(peg_index)


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("workshops")
	params["count"] = workshops.size()
	return params
