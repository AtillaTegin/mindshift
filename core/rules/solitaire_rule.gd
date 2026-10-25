class_name SolitaireRule
extends RuleBase
## "Pasyans" (ICRA World 5-9, section 3.14; card patience, never named after a
## card game in the game): a disk only goes onto the disk one size larger (k
## onto k + 1) or onto an empty peg, so every stack is a run. Level JSON:
##   "rules": ["classic_hanoi", "solitaire"], "rule_params": {"solitaire": {}}
## Settings:
##   "cell": peg          "Boş hücrə": a one-disk cell open to every disk and
##                        from which any disk goes on by the rule
##   "colours": [..]      "Qırmızı-qara": each disk red (1) or black (0); stacked
##                        disks take turns of colour
##   "arches": [..]       "Tağ": per peg the largest size it takes (0: any)
##   "limits": [..]       "Dar qüllə": per peg the most disks it holds (0: any)
##   "closed": true       only for measuring (LevelForge.settings_without): the
##                        cell takes no disk
## "Sıra köçürmə" (a whole run in one move) is not built: a move of several
## disks onto one peg is no move the engine knows (ICRA 3.14 allows dropping it).

const ID: String = "solitaire"

var cell: int = -1
var colours: Array[int] = []
var arches: Array[int] = []
var limits: Array[int] = []
var closed: bool = false


func _init() -> void:
	violation_message = "RULE_SOLITAIRE"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes optional \"cell\": peg, \"colours\": [0/1 per disk], \"arches\"/\"limits\": one number per peg" % ID
	for key: String in params:
		if not key in ["cell", "colours", "arches", "limits", "closed"]:
			return problem
	if typeof(params.get("closed", false)) != TYPE_BOOL:
		return problem
	closed = params.get("closed", false)
	var list: Variant = params.get("colours", [])
	if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v in [0, 1]):
		return problem
	colours.assign(list)
	for key: String in ["cell"]:
		if typeof(params.get(key, 0)) != TYPE_INT:
			return problem
	for key: String in ["arches", "limits"]:
		var per_peg: Variant = params.get(key, [])
		if typeof(per_peg) != TYPE_ARRAY or not (per_peg as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0):
			return problem
	cell = params.get("cell", -1)
	arches.assign(params.get("arches", []))
	limits.assign(params.get("limits", []))
	return ""

func get_params() -> Dictionary:
	var params: Dictionary = {}
	if cell >= 0:
		params["cell"] = cell
	if not colours.is_empty():
		params["colours"] = colours.duplicate()
	if arches.any(func(n: int) -> bool: return n > 0):
		params["arches"] = arches.duplicate()
	if limits.any(func(n: int) -> bool: return n > 0):
		params["limits"] = limits.duplicate()
	if closed:
		params["closed"] = true
	return params


func colour_of(disk: int) -> int:
	return colours[disk - 1] if disk >= 1 and disk <= colours.size() else 0


func _arch_of(peg: int) -> int:
	return arches[peg] if peg < arches.size() else 0


func _limit_of(peg: int) -> int:
	return limits[peg] if peg < limits.size() else 0


## Whether `disk` may lie right on `lower` (-1: an empty peg's base).
func may_rest(disk: int, lower: int, peg: int) -> bool:
	if _arch_of(peg) > 0 and disk > _arch_of(peg):
		return false
	if peg == cell:
		return lower == -1 and not closed
	if lower == -1:
		return true
	return lower == disk + 1 and (colours.is_empty() or colour_of(disk) != colour_of(lower))


func is_disk_move_allowed(disk: int, _from_peg: int, to_peg: int, target_top: int) -> bool:
	return may_rest(disk, target_top, to_peg)


## A narrow tower also counts its disks.
func is_move_allowed_with(disk: int, _from_peg: int, to_peg: int, target_top: int, facts: MoveFacts) -> bool:
	if _limit_of(to_peg) > 0 and facts.counts[to_peg] >= _limit_of(to_peg):
		return false
	return may_rest(disk, target_top, to_peg)


func needs_facts() -> bool:
	return limits.any(func(n: int) -> bool: return n > 0)


func supports_disk_move_check() -> bool:
	return not needs_facts()


func keeps_stacks_sorted() -> bool:
	return true


## Every stack a run (one size apart, colours taking turns) under its peg's
## arch and limit, the cell holding one disk at most.
func is_state_valid(state: PuzzleState) -> bool:
	for peg_index: int in state.pegs.size():
		var stack: Array = state.pegs[peg_index]
		if peg_index == cell and stack.size() > 1:
			return false
		if _limit_of(peg_index) > 0 and stack.size() > _limit_of(peg_index):
			return false
		for i: int in stack.size():
			if _arch_of(peg_index) > 0 and int(stack[i]) > _arch_of(peg_index):
				return false
			if i > 0 and not may_rest(stack[i], int(stack[i - 1]), peg_index):
				return false
	return true


func get_violation_message(state: PuzzleState, move: Move) -> String:
	var disk: int = state.get_top_disk(move.from_peg)
	if _arch_of(move.to_peg) > 0 and disk > _arch_of(move.to_peg):
		return "RULE_ARCH"
	if move.to_peg == cell:
		return "RULE_CELL_FULL"
	if _limit_of(move.to_peg) > 0 and state.pegs[move.to_peg].size() >= _limit_of(move.to_peg):
		return "RULE_NARROW_FULL"
	if not colours.is_empty() and state.get_top_disk(move.to_peg) == disk + 1:
		return "RULE_RED_BLACK"
	return violation_message


## The cell, the arch and the limit travel with their peg.
func peg_mark(peg_index: int) -> Variant:
	return [peg_index == cell, _arch_of(peg_index), _limit_of(peg_index)]


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("cell")
	params.erase("arches")
	params.erase("limits")
	return params
