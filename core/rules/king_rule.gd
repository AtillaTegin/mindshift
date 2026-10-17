class_name KingRule
extends RuleBase
## "Kral" (ICRA World 5-9, section 3.1; after Huarong Dao and Hnefatafl): the
## crowned disk, the largest, must reach the gate peg ("Darvaza"); the other
## disks may stay anywhere. The goal is a condition (RuleBase.defines_goal),
## not one position; moves follow classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "king"], "rule_params": {"king": {"crowns": [[7, 3]]}}
## Settings:
##   "crowns": [[disk, gate], ...]   the crowned disks, each with its own gate
##                                   ("Kral və vəzir": two)
##   "narrow": [[gate, entry], ...]  "Dar qapı": a disk enters `gate` only from
##                                   the peg `entry`, its neighbour
##   "odd_even": [odd peg, even peg] "Tək-Cüt": the odd sizes stack on one marked
##                                   peg, the even ones on another; that goal is
##                                   one exact position (the level's goal), so
##                                   it takes no crowns
## "Mühasirə" (the king starts under the tallest stack) only shapes the start.

const ID: String = "king"

var crowns: Array[Array] = []
var narrow: Array[Array] = []
var odd_even: Array[int] = []


func _init() -> void:
	violation_message = "RULE_NARROW_GATE"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes \"crowns\": [[disk, gate]], optional \"narrow\": [[gate, entry]], or \"odd_even\": [peg, peg]" % ID
	for key: String in params:
		if not key in ["crowns", "narrow", "odd_even"]:
			return problem
	for key: String in ["crowns", "narrow"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY:
			return problem
		for item: Variant in list:
			if not _ints(item) or (item as Array).size() != 2:
				return problem
		(crowns if key == "crowns" else narrow).assign(list)
	var pair: Variant = params.get("odd_even", [])
	if not _ints(pair) or not ((pair as Array).is_empty() or ((pair as Array).size() == 2 and pair[0] != pair[1])):
		return problem
	odd_even.assign(pair)
	if crowns.is_empty() == odd_even.is_empty():
		return problem
	for crown: Array in crowns:
		if int(crown[0]) < 1:
			return problem
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if not crowns.is_empty():
		params["crowns"] = crowns.duplicate(true)
	if not narrow.is_empty():
		params["narrow"] = narrow.duplicate(true)
	if not odd_even.is_empty():
		params["odd_even"] = odd_even.duplicate()
	return params


static func _ints(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and (value as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0)


## The crowns set the goal; the odd and even towers are an exact one.
func defines_goal() -> bool:
	return not crowns.is_empty()


## The king's rule is the aim (its narrow gate is measured as a sub-element).
func only_aims() -> bool:
	return true


## Every crowned disk on its gate.
func is_goal_with(facts: MoveFacts) -> bool:
	for crown: Array in crowns:
		var disk: int = crown[0]
		if disk >= facts.peg_of.size() or facts.peg_of[disk] != int(crown[1]):
			return false
	return true


## The gate of `disk`, or -1 for a disk without a crown.
func gate_of(disk: int) -> int:
	for crown: Array in crowns:
		if int(crown[0]) == disk:
			return crown[1]
	return -1


## The only peg a disk may enter `gate` from, or -1 when any goes.
func entry_of(gate: int) -> int:
	for pair: Array in narrow:
		if int(pair[0]) == gate:
			return pair[1]
	return -1


func is_disk_move_allowed(_disk: int, from_peg: int, to_peg: int, _target_top: int) -> bool:
	var entry: int = entry_of(to_peg)
	return entry == -1 or from_peg == entry


func supports_disk_move_check() -> bool:
	return true


## Each gate and marked peg travels with its peg; a narrow gate ties the board
## to its order (the entry is a neighbour).
func peg_symmetry() -> String:
	return PEGS_ANY if narrow.is_empty() else PEGS_FIXED


func peg_mark(peg_index: int) -> Variant:
	var mark: Array = []
	for crown: Array in crowns:
		if int(crown[1]) == peg_index:
			mark.append(crown[0])
	if not odd_even.is_empty():
		mark.append("odd" if odd_even[0] == peg_index else "even" if odd_even[1] == peg_index else "")
	return mark


func params_without_pegs() -> Dictionary:
	return {"narrow": narrow.duplicate(true)} if not narrow.is_empty() else {}
