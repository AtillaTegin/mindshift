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
##   "kings": n           "Kral yeri": an empty peg takes only disks of size n
##                        and up
## "Sıra köçürmə" (a whole run in one move) is not built: a move of several
## disks onto one peg is no move the engine knows (ICRA 3.14 allows dropping it).

const ID: String = "solitaire"

var cell: int = -1
var colours: Array[int] = []
var kings: int = 0


func _init() -> void:
	violation_message = "RULE_SOLITAIRE"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes optional \"cell\": peg, \"colours\": [0/1 per disk], \"kings\": size" % ID
	for key: String in params:
		if not key in ["cell", "colours", "kings"]:
			return problem
	var list: Variant = params.get("colours", [])
	if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v in [0, 1]):
		return problem
	colours.assign(list)
	for key: String in ["cell", "kings"]:
		if typeof(params.get(key, 0)) != TYPE_INT:
			return problem
	cell = params.get("cell", -1)
	kings = params.get("kings", 0)
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if cell >= 0:
		params["cell"] = cell
	if not colours.is_empty():
		params["colours"] = colours.duplicate()
	if kings > 0:
		params["kings"] = kings
	return params


func colour_of(disk: int) -> int:
	return colours[disk - 1] if disk >= 1 and disk <= colours.size() else 0


## Whether `disk` may lie right on `lower` (-1: an empty peg's base).
func may_rest(disk: int, lower: int, peg: int) -> bool:
	if peg == cell:
		return lower == -1
	if lower == -1:
		return kings == 0 or disk >= kings
	return lower == disk + 1 and (colours.is_empty() or colour_of(disk) != colour_of(lower))


func is_disk_move_allowed(disk: int, _from_peg: int, to_peg: int, target_top: int) -> bool:
	return may_rest(disk, target_top, to_peg)


func supports_disk_move_check() -> bool:
	return true


func keeps_stacks_sorted() -> bool:
	return true


## Every stack a run (one size apart, colours taking turns), the cell holding
## one disk at most.
func is_state_valid(state: PuzzleState) -> bool:
	for peg_index: int in state.pegs.size():
		var stack: Array = state.pegs[peg_index]
		if peg_index == cell and stack.size() > 1:
			return false
		for i: int in stack.size():
			if not may_rest(stack[i], int(stack[i - 1]) if i > 0 else -1, peg_index) and not (i == 0 and peg_index != cell):
				return false
	return true


func get_violation_message(state: PuzzleState, move: Move) -> String:
	if move.to_peg == cell:
		return "RULE_CELL_FULL"
	if state.pegs[move.to_peg].is_empty():
		return "RULE_KING_SPOT"
	if not colours.is_empty() and state.get_top_disk(move.to_peg) == state.get_top_disk(move.from_peg) + 1:
		return "RULE_RED_BLACK"
	return violation_message


## The cell travels with its peg.
func peg_mark(peg_index: int) -> Variant:
	return peg_index == cell


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("cell")
	return params
