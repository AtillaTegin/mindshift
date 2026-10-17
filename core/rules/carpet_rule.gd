class_name CarpetRule
extends RuleBase
## "Xalça" (ICRA World 5-9, section 3.4; the Azerbaijani carpet, a navel in
## the middle of a symmetric pattern): the goal is the pegs' heights, a
## silhouette such as 1-3-5-3-1, built with any disks the size rule allows
## (RuleBase.defines_goal). Moves follow classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "carpet"], "rule_params": {"carpet": {"heights": [1, 3, 5, 3, 1]}}
## Settings:
##   "heights": [per peg]        the silhouette; "Buta" is an uneven one, "Qoşa
##                               xalça" (6 pegs) repeats one of three pegs twice
##   "navel": [peg, disk]        "Göbək": that disk on top of that peg
##   "colours": [per disk]       "Rəngli naxış": each disk's colour (0-2, disk 1
##   "tops": [per peg]           first) and the colour each peg's top disk must
##                               have (-1: any, an empty peg's included)

const ID: String = "carpet"

var heights: Array[int] = []
var navel: Array[int] = []
var colours: Array[int] = []
var tops: Array[int] = []


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"heights\": [one count per peg], optional \"navel\": [peg, disk], \"colours\": [per disk] with \"tops\": [per peg]" % ID
	for key: String in params:
		if not key in ["heights", "navel", "colours", "tops"]:
			return problem
	for key: String in ["heights", "navel", "colours", "tops"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= -1):
			return problem
	heights.assign(params.get("heights", []))
	navel.assign(params.get("navel", []))
	colours.assign(params.get("colours", []))
	tops.assign(params.get("tops", []))
	if heights.is_empty() or heights.any(func(h: int) -> bool: return h < 0) or not (navel.is_empty() or navel.size() == 2) \
			or colours.is_empty() != tops.is_empty() or (not tops.is_empty() and tops.size() != heights.size()):
		return problem
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"heights": heights.duplicate()}
	if not navel.is_empty():
		params["navel"] = navel.duplicate()
	if not colours.is_empty():
		params["colours"] = colours.duplicate()
		params["tops"] = tops.duplicate()
	return params


func defines_goal() -> bool:
	return true


## Every peg as high as the silhouette, the navel's disk on top of its peg,
## every marked top in its colour.
func is_goal_with(facts: MoveFacts) -> bool:
	if facts.counts.size() != heights.size():
		return false
	for peg_index: int in heights.size():
		if facts.counts[peg_index] != heights[peg_index]:
			return false
	if not navel.is_empty() and facts.tops[navel[0]] != navel[1]:
		return false
	for peg_index: int in tops.size():
		if tops[peg_index] >= 0 and (facts.tops[peg_index] < 1 or colour_of(facts.tops[peg_index]) != tops[peg_index]):
			return false
	return true


## The colour of `disk` in a coloured carpet (0 without colours).
func colour_of(disk: int) -> int:
	return colours[disk - 1] if disk >= 1 and disk <= colours.size() else 0


func is_state_valid(state: PuzzleState) -> bool:
	return state.get_peg_count() == heights.size()


## It limits no move: the Solver keeps its fast packed search.
func supports_disk_move_check() -> bool:
	return true


## The silhouette reads the same both ways along the row.
func peg_symmetry() -> String:
	return PEGS_LINE


func peg_mark(peg_index: int) -> Variant:
	if peg_index >= heights.size():
		return null
	return [heights[peg_index], navel[1] if not navel.is_empty() and navel[0] == peg_index else 0,
			tops[peg_index] if not tops.is_empty() else -1]


func params_without_pegs() -> Dictionary:
	return {"colours": colours.duplicate()} if not colours.is_empty() else {}
