class_name ChainRule
extends RuleBase
## "Zəncirlənmiş Disklər" (new mechanics specification v1, section 2): two
## disks of different sizes are chained. They never move alone: when both are
## on top of their pegs, one compound move takes each to its own, different
## target, each judged by the other rules as if it moved alone. It counts as
## one move. The rule only names the linked disks (group_of_with); RuleSet and
## the Solver make the compound moves. Level JSON:
##   "rules": ["classic_hanoi", "chain"], "rule_params": {"chain": {"disks": [2, 4]}}
## World 6 waves (ICRA World 5-9, section 3.6), optional settings:
##   "groups": [[1, 3], [2, 5]]  "İki zəncir": more chains than one ("disks"
##                               then left out); [[1, 3, 5]] "Uzun zəncir":
##                               three disks that move together
##   "breaking": true            "Qırılan zəncir": a pair may land on one peg,
##                               the larger first and the smaller on it, and
##                               then its chain is broken for good (a memory
##                               bit per chain)
##   "rubber": true              "Rezin zəncir": a pair only moves to two
##                               neighbouring pegs

const ID: String = "chain"

var groups: Array[Array] = []
var breaking: bool = false
var rubber: bool = false


func _init() -> void:
	violation_message = "RULE_CHAIN"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"disks\": [two different disks]} or \"groups\": [[disks], ...], optional \"breaking\"/\"rubber\": true" % ID
	for key: String in params:
		if not key in ["disks", "groups", "breaking", "rubber"]:
			return problem
	if params.has("disks") == params.has("groups"):
		return problem
	var lists: Array = [params["disks"]] if params.has("disks") else params["groups"]
	if typeof(lists) != TYPE_ARRAY or lists.is_empty():
		return problem
	var seen: Dictionary = {}
	for list: Variant in lists:
		if typeof(list) != TYPE_ARRAY or not (list as Array).size() in [2, 3] \
				or not (list as Array).all(func(d: Variant) -> bool: return typeof(d) == TYPE_INT and d >= 1):
			return problem
		for disk: int in list:
			if seen.has(disk):
				return problem
			seen[disk] = true
		var group: Array = (list as Array).duplicate()
		group.sort()
		groups.append(group)
	for key: String in ["breaking", "rubber"]:
		if typeof(params.get(key, false)) != TYPE_BOOL:
			return problem
	breaking = params.get("breaking", false)
	rubber = params.get("rubber", false)
	if (breaking or rubber) and groups.any(func(group: Array) -> bool: return group.size() != 2):
		return problem
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if groups.size() == 1 and groups[0].size() == 2 and not breaking and not rubber:
		params["disks"] = groups[0].duplicate()
	else:
		params["groups"] = groups.duplicate(true)
	if breaking:
		params["breaking"] = true
	if rubber:
		params["rubber"] = true
	return params


## The first pair's disks (the chain the board draws first).
var disks: Array[int]:
	get:
		var first: Array[int] = []
		first.assign(groups[0] if not groups.is_empty() else [])
		return first


## The other disk of a pair that never breaks (the Solver's fast compound
## moves); 0 otherwise.
func partner_of(disk: int) -> int:
	if breaking:
		return 0
	for group: Array in groups:
		if group.size() == 2 and group.has(disk):
			return group[0] if group[1] == disk else group[1]
	return 0


func group_of_with(disk: int, memory: int) -> Array[int]:
	var found: Array[int] = []
	for i: int in groups.size():
		if (groups[i] as Array).has(disk) and not is_broken(memory, i):
			found.assign(groups[i])
	return found


## Whether chain `index` has broken (a breaking chain's memory).
func is_broken(memory: int, index: int) -> bool:
	return breaking and (memory >> index) & 1 == 1


func groups_change() -> bool:
	return breaking


func allows_shared_target() -> bool:
	return breaking


func compound_allowed(targets: Array[int]) -> bool:
	return not rubber or targets.size() != 2 or absi(targets[0] - targets[1]) == 1


func uses_memory() -> bool:
	return breaking


func memory_states(_peg_count: int, _disk_count: int) -> int:
	return 1 << groups.size() if breaking else 1


## A pair put on one peg breaks its chain.
func compound_memory_after(facts: MoveFacts, moved: Array[int], _froms: Array[int], tos: Array[int]) -> int:
	var memory: int = facts.memory
	if breaking and tos.size() == 2 and tos[0] == tos[1]:
		for i: int in groups.size():
			if (groups[i] as Array).has(moved[0]):
				memory |= 1 << i
	return memory


## A rubber chain says that its pair only goes to two neighbouring pegs.
func get_violation_message(_state: PuzzleState, move: Move) -> String:
	if rubber and move.is_compound() and absi(move.to_peg - move.to_peg_2) != 1:
		return "RULE_RUBBER"
	return violation_message


func supports_disk_move_check() -> bool:
	return true
