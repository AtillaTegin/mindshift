class_name KoRule
extends RuleBase
## "Ko" (ICRA World 5-9, section 3.5; Go's ko rule): the peg a disk was taken
## from breathes for one move: the next move neither takes a disk from it nor
## puts one on it (a Go stone marks it). The rule remembers the last moves
## (PuzzleState.memory: each move as from * pegs + to + 1, the newest lowest).
## On top of classic Hanoi. Level JSON:
##   "rules": ["classic_hanoi", "ko"], "rule_params": {"ko": {}}
## Settings:
##   "target": true   "Hədəf ko": the peg a disk was put on breathes instead
##   "both": true     "İki daş": the peg it came from and the one it went to
##   "free": peg      "Azad qüllə": that peg never breathes
##   "turns": 2       "Uzun ko": a peg breathes for two moves

const ID: String = "ko"

var target: bool = false
var both: bool = false
var free: int = -1
var turns: int = 1


func _init() -> void:
	violation_message = "RULE_KO"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes optional \"target\"/\"both\": true, \"free\": peg, \"turns\": 1 or 2" % ID
	for key: String in params:
		if not key in ["target", "both", "free", "turns"]:
			return problem
	for key: String in ["target", "both"]:
		if typeof(params.get(key, false)) != TYPE_BOOL:
			return problem
	var peg: Variant = params.get("free", -1)
	var count: Variant = params.get("turns", 1)
	if typeof(peg) != TYPE_INT or peg < -1 or typeof(count) != TYPE_INT or not count in [1, 2]:
		return problem
	target = params.get("target", false)
	both = params.get("both", false)
	if target and both:
		return problem
	free = peg
	turns = count
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if target:
		params["target"] = true
	if both:
		params["both"] = true
	if free >= 0:
		params["free"] = free
	if turns != 1:
		params["turns"] = turns
	return params


func uses_memory() -> bool:
	return true


## One code per remembered move: from * pegs + to + 1 (0: none).
func memory_states(peg_count: int, _disk_count: int) -> int:
	return int(pow(peg_count * peg_count + 1, turns))


func memory_after(facts: MoveFacts, _disk: int, from_peg: int, to_peg: int) -> int:
	var base: int = facts.peg_count() * facts.peg_count() + 1
	var code: int = from_peg * facts.peg_count() + to_peg + 1
	return code if turns == 1 else code + base * (facts.memory % base)


## The pegs that breathe now (`memory` of a board of `peg_count` pegs).
func breathing(memory: int, peg_count: int) -> Array[int]:
	var pegs: Array[int] = []
	var base: int = peg_count * peg_count + 1
	var rest: int = memory
	for i: int in turns:
		var code: int = rest % base
		rest /= base
		if code == 0:
			continue
		var from_peg: int = (code - 1) / peg_count
		var to_peg: int = (code - 1) % peg_count
		for peg: int in ([from_peg, to_peg] if both else [to_peg] if target else [from_peg]):
			if peg != free and not pegs.has(peg):
				pegs.append(peg)
	return pegs


## Whether `peg` breathes (no array: the Solver asks this for every move).
func is_breathing(memory: int, peg_count: int, peg: int) -> bool:
	if peg == free:
		return false
	var base: int = peg_count * peg_count + 1
	var rest: int = memory
	for i: int in turns:
		var code: int = rest % base
		rest /= base
		if code == 0:
			continue
		if not target and (code - 1) / peg_count == peg:
			return true
		if (target or both) and (code - 1) % peg_count == peg:
			return true
	return false


## A disk on a breathing peg waits.
func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	return disk >= facts.peg_of.size() or facts.peg_of[disk] < 0 \
			or not is_breathing(facts.memory, facts.peg_count(), facts.peg_of[disk])


func pick_up_message(_disk: int, _facts: MoveFacts) -> String:
	return violation_message


func is_move_allowed_with(_disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	var peg_count: int = facts.peg_count()
	return not is_breathing(facts.memory, peg_count, from_peg) and not is_breathing(facts.memory, peg_count, to_peg)


## The free peg travels with its peg.
func peg_mark(peg_index: int) -> Variant:
	return peg_index == free


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("free")
	return params
