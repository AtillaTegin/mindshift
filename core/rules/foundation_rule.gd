class_name FoundationRule
extends RuleBase
## "Addımlı Kilidlənmə" / "Astana Qaydası" (new mechanics specification v1,
## section 9): the `locked` disks (the largest one or two) may not move until
## the `keys` (the smallest few) have all reached their own pegs (`targets`,
## from the level goal) at least once; from then on they stay unlocked (user
## decision 2026-10-15: "bir dəfə açılır, açıq qalır"). On top of the other
## rules. Level JSON:
##   "rules": ["classic_hanoi", "foundation"],
##   "rule_params": {"foundation": {"locked": [6], "keys": [1, 2, 3], "targets": [2, 2, 2]}}
##
## Chapter waves v1 (section 3.2) use the same lock in new ways: a key disk of
## any size with a marked key place ("Açar disk"), a locked disk in the middle
## of a stack ("Ortadakı kilid"), and locks that open one after the other
## ("Zəncirvari kilid", up to 3), the disk one lock frees being the key of the
## next. Those are `stages`, each {locked, keys, targets}, opened in order:
##   "rule_params": {"foundation": {"stages": [{"locked": [5], "keys": [1], "targets": [2]},
##                                             {"locked": [6], "keys": [5], "targets": [0]}]}}
## The rule's memory is how many stages are open (0 = all locked).

const ID: String = "foundation"
## Most stages one level may chain.
const MAX_STAGES: int = 3

## Each stage: {"locked": Array[int], "keys": Array[int], "targets": Array[int]}.
var stages: Array[Dictionary] = []
## Disk -> the stage that holds it locked (-1: none); the search reads it on
## every move, so no dictionary lookups there.
var _lock_stage: PackedInt32Array = PackedInt32Array()
var _stage_keys: Array[PackedInt32Array] = []
var _stage_targets: Array[PackedInt32Array] = []
## The first stage's settings (one-stage levels and their dress).
var locked: Array[int] = []
var keys: Array[int] = []
## Peg each key must reach, in the order of `keys`.
var targets: Array[int] = []


func _init() -> void:
	violation_message = "RULE_FOUNDATION"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"locked\": [disks], \"keys\": [disks], \"targets\": [one peg per key]} or {\"stages\": [...]}" % ID
	var raw: Array = []
	if params.size() == 1 and typeof(params.get("stages")) == TYPE_ARRAY:
		raw = params["stages"]
	elif params.size() == 3:
		raw = [params]
	if raw.is_empty() or raw.size() > MAX_STAGES:
		return problem
	stages.clear()
	var all_locked: Array[int] = []
	for item: Variant in raw:
		if typeof(item) != TYPE_DICTIONARY or (item as Dictionary).size() != 3:
			return problem
		var stage: Dictionary = {}
		for key: String in ["locked", "keys", "targets"]:
			var value: Variant = item.get(key)
			if typeof(value) != TYPE_ARRAY or (value as Array).is_empty() \
					or not (value as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0):
				return problem
			var list: Array[int] = []
			list.assign(value)
			stage[key] = list
		if (stage["keys"] as Array).size() != (stage["targets"] as Array).size() \
				or (stage["locked"] as Array).any(func(disk: int) -> bool: return (stage["keys"] as Array).has(disk) or all_locked.has(disk)):
			return problem
		all_locked.append_array(stage["locked"])
		stages.append(stage)
	locked = stages[0]["locked"]
	keys = stages[0]["keys"]
	targets = stages[0]["targets"]
	_lock_stage = PackedInt32Array()
	_lock_stage.resize(all_locked.max() + 1)
	_lock_stage.fill(-1)
	_stage_keys.clear()
	_stage_targets.clear()
	for i: int in stages.size():
		for disk: int in stages[i]["locked"]:
			_lock_stage[disk] = i
		_stage_keys.append(PackedInt32Array(stages[i]["keys"]))
		_stage_targets.append(PackedInt32Array(stages[i]["targets"]))
	return ""


func get_params() -> Dictionary:
	if stages.size() == 1:
		return {"locked": locked.duplicate(), "keys": keys.duplicate(), "targets": targets.duplicate()}
	var list: Array = []
	for stage: Dictionary in stages:
		list.append({"locked": (stage["locked"] as Array).duplicate(), "keys": (stage["keys"] as Array).duplicate(),
				"targets": (stage["targets"] as Array).duplicate()})
	return {"stages": list}


## The stage that holds `disk` locked, or -1.
func stage_of(disk: int) -> int:
	return _lock_stage[disk] if disk < _lock_stage.size() else -1


## Disks still locked with `memory` stages open.
func locked_now(memory: int) -> Array[int]:
	var found: Array[int] = []
	for i: int in range(memory, stages.size()):
		found.append_array(stages[i]["locked"])
	return found


func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	var stage: int = stage_of(disk)
	return stage == -1 or facts.memory > stage


func is_move_allowed_with(disk: int, _from_peg: int, _to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return is_disk_movable_with(disk, facts)


func uses_memory() -> bool:
	return true


func memory_states(_peg_count: int, _disk_count: int) -> int:
	return stages.size() + 1


## Every stage in order whose keys already stand on their pegs is open.
func start_memory(state: PuzzleState) -> int:
	var open: int = 0
	while open < stages.size():
		var keys_of: PackedInt32Array = _stage_keys[open]
		var targets_of: PackedInt32Array = _stage_targets[open]
		for i: int in keys_of.size():
			if _peg_in(state, keys_of[i]) != targets_of[i]:
				return open
		open += 1
	return open


## A move that leaves the next stage's keys all on their pegs opens it (and any
## stage after it already met); open stages stay open.
func memory_after(facts: MoveFacts, disk: int, _from_peg: int, to_peg: int) -> int:
	var open: int = facts.memory
	while open < stages.size():
		var keys_of: PackedInt32Array = _stage_keys[open]
		var targets_of: PackedInt32Array = _stage_targets[open]
		for i: int in keys_of.size():
			var key: int = keys_of[i]
			if (to_peg if key == disk else facts.peg_of[key]) != targets_of[i]:
				return open
		open += 1
	return open


## How many keys of the stage now to open stand on their pegs in `state` (the
## board shows "2/3"); `memory` stages are open already.
func keys_in_place(state: PuzzleState, memory: int = 0) -> int:
	var stage: int = mini(memory, stages.size() - 1)
	var count: int = 0
	for i: int in _stage_keys[stage].size():
		if _peg_in(state, _stage_keys[stage][i]) == _stage_targets[stage][i]:
			count += 1
	return count


## How many keys the stage now to open has.
func keys_needed(memory: int = 0) -> int:
	return _stage_keys[mini(memory, stages.size() - 1)].size()


## Every key disk of every stage with its key place: [[disk, peg], ...].
func key_places() -> Array:
	var found: Array = []
	for stage: int in stages.size():
		for i: int in _stage_keys[stage].size():
			found.append([_stage_keys[stage][i], _stage_targets[stage][i]])
	return found


func needs_facts() -> bool:
	return true


static func _peg_in(state: PuzzleState, disk: int) -> int:
	for peg_index: int in state.pegs.size():
		if state.pegs[peg_index].has(disk):
			return peg_index
	return -1
