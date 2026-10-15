class_name FoundationRule
extends RuleBase
## "Addımlı Kilidlənmə" / "Astana Qaydası" (new mechanics specification v1,
## section 9): the `locked` disks (the largest one or two) may not move until
## the `keys` (the smallest few) have all reached their own pegs (`targets`,
## from the level goal) at least once; from then on they stay unlocked (user
## decision 2026-10-15: "bir dəfə açılır, açıq qalır"). That one bit is the
## rule's memory (0 locked, 1 open). On top of the other rules. Level JSON:
##   "rules": ["classic_hanoi", "foundation"],
##   "rule_params": {"foundation": {"locked": [6], "keys": [1, 2, 3], "targets": [2, 2, 2]}}

const ID: String = "foundation"

var locked: Array[int] = []
var keys: Array[int] = []
## Peg each key must reach, in the order of `keys`.
var targets: Array[int] = []


func _init() -> void:
	violation_message = "RULE_FOUNDATION"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"locked\": [disks], \"keys\": [disks], \"targets\": [one peg per key]}" % ID
	if params.size() != 3:
		return problem
	for key: String in ["locked", "keys", "targets"]:
		var value: Variant = params.get(key)
		if typeof(value) != TYPE_ARRAY or (value as Array).is_empty() \
				or not (value as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0):
			return problem
	locked.assign(params["locked"])
	keys.assign(params["keys"])
	targets.assign(params["targets"])
	if keys.size() != targets.size() or locked.any(func(disk: int) -> bool: return keys.has(disk)):
		return problem
	return ""


func get_params() -> Dictionary:
	return {"locked": locked.duplicate(), "keys": keys.duplicate(), "targets": targets.duplicate()}


func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	return facts.memory == 1 or not locked.has(disk)


func is_move_allowed_with(disk: int, _from_peg: int, _to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return is_disk_movable_with(disk, facts)


func uses_memory() -> bool:
	return true


func memory_states(_peg_count: int, _disk_count: int) -> int:
	return 2


## Open from the start only if every key already stands on its peg.
func start_memory(state: PuzzleState) -> int:
	for i: int in keys.size():
		if targets[i] >= state.pegs.size() or not state.pegs[targets[i]].has(keys[i]):
			return 0
	return 1


## Opens for good once a move leaves every key on its peg.
func memory_after(facts: MoveFacts, disk: int, _from_peg: int, to_peg: int) -> int:
	if facts.memory == 1:
		return 1
	for i: int in keys.size():
		var peg: int = to_peg if keys[i] == disk else facts.peg_of[keys[i]]
		if peg != targets[i]:
			return 0
	return 1


## How many keys stand on their pegs in `state` (the board shows "2/3").
func keys_in_place(state: PuzzleState) -> int:
	var count: int = 0
	for i: int in keys.size():
		if targets[i] < state.pegs.size() and state.pegs[targets[i]].has(keys[i]):
			count += 1
	return count


func needs_facts() -> bool:
	return true
