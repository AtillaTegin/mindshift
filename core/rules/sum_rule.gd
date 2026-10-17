class_name SumRule
extends RuleBase
## "Cəm" (ICRA World 5-9, section 3.10; after the sum puzzles loved in Japan,
## never named so in the game): the goal is the sum of the disk sizes on
## every peg, written under it; the current sums show live. Moves follow
## classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "sum"], "rule_params": {"sum": {"sums": [6, 9, 0, 6]}}
## Settings (one per peg; -1: any):
##   "sums": [..]       the sums ("Cəm"); left out for "Ədalət"
##   "fair": true       "Ədalət": no numbers, every peg's sum the same
##   "counts": [..]     "Cəm və hündürlük": each peg's disk count too
##   "double": peg      "İkiqat qüllə": that peg's sum counts twice
##   "parity": [..]     "Tək-cüt cəm": 1 an odd sum, 2 an even one (no sums)

const ID: String = "sum"

var sums: Array[int] = []
var fair: bool = false
var counts: Array[int] = []
var double: int = -1
var parity: Array[int] = []


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs \"sums\" or \"parity\" (one per peg) or \"fair\": true, optional \"counts\", \"double\": peg" % ID
	for key: String in params:
		if not key in ["sums", "fair", "counts", "double", "parity"]:
			return problem
	for key: String in ["sums", "counts", "parity"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= -1):
			return problem
	sums.assign(params.get("sums", []))
	counts.assign(params.get("counts", []))
	parity.assign(params.get("parity", []))
	if typeof(params.get("fair", false)) != TYPE_BOOL or typeof(params.get("double", -1)) != TYPE_INT:
		return problem
	fair = params.get("fair", false)
	double = params.get("double", -1)
	if [not sums.is_empty(), fair, not parity.is_empty()].count(true) != 1:
		return problem
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if not sums.is_empty():
		params["sums"] = sums.duplicate()
	if fair:
		params["fair"] = true
	if not counts.is_empty():
		params["counts"] = counts.duplicate()
	if double >= 0:
		params["double"] = double
	if not parity.is_empty():
		params["parity"] = parity.duplicate()
	return params


func defines_goal() -> bool:
	return true


## The sum peg `peg_index` shows with `facts` (twice on the doubled peg).
func shown_sum(facts: MoveFacts, peg_index: int) -> int:
	return facts.sums[peg_index] * (2 if peg_index == double else 1)


func is_goal_with(facts: MoveFacts) -> bool:
	var pegs: int = facts.peg_count()
	for peg_index: int in pegs:
		var total: int = shown_sum(facts, peg_index)
		if peg_index < sums.size() and sums[peg_index] >= 0 and total != sums[peg_index]:
			return false
		if peg_index < counts.size() and counts[peg_index] >= 0 and facts.counts[peg_index] != counts[peg_index]:
			return false
		if peg_index < parity.size() and parity[peg_index] > 0 and total % 2 != parity[peg_index] % 2:
			return false
		if fair and total != shown_sum(facts, 0):
			return false
	return true


## It limits no move: the Solver keeps its fast packed search.
func supports_disk_move_check() -> bool:
	return true


## The numbers under the pegs travel with them.
func peg_mark(peg_index: int) -> Variant:
	return [sums[peg_index] if peg_index < sums.size() else -2, counts[peg_index] if peg_index < counts.size() else -2,
			parity[peg_index] if peg_index < parity.size() else -2, peg_index == double]


func params_without_pegs() -> Dictionary:
	return {"fair": fair}
