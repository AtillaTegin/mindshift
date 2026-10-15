class_name TrailRule
extends RuleBase
## "İz Qadağası" / "Qumlu Cığır" (new mechanics specification v1, section 3):
## one disk leaves a trail and may not come back to a peg on it, the peg it
## starts on included. The trail is the rule's memory: with `recent` 0 every
## peg it has stood on (one bit per peg), else only its latest `recent` pegs
## (the specification's "son N qülləni xatırla", left to the builder; the
## shipped pilots use 2: with the whole history the rule almost never changed
## a solution, measured 2026-10-15). Boards stay small (at most 5 pegs). On
## top of the other rules. Level JSON:
##   "rules": ["classic_hanoi", "trail"], "rule_params": {"trail": {"disk": 1, "recent": 2}}

const ID: String = "trail"

## The disk that leaves the trail.
var disk: int = 0
## How many of its latest pegs the trail remembers (0: every peg it has stood on).
var recent: int = 0


func _init() -> void:
	violation_message = "RULE_TRAIL"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("disk")
	if typeof(value) != TYPE_INT or value < 1 or params.size() > 2 \
			or (params.size() == 2 and typeof(params.get("recent")) != TYPE_INT):
		return "rule \"%s\" needs {\"disk\": the disk that leaves the trail}" % ID
	disk = value
	recent = params.get("recent", 0)
	return ""


func get_params() -> Dictionary:
	return {"disk": disk} if recent == 0 else {"disk": disk, "recent": recent}


func is_move_allowed_with(moving: int, _from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return moving != disk or not remembers(facts.memory, to_peg, facts.peg_count())


func uses_memory() -> bool:
	return true


## Every peg: one bit each. The latest `recent`: one digit (peg + 1, 0 none)
## in base peg_count + 1 for each, the newest lowest.
func memory_states(peg_count: int, _disk_count: int) -> int:
	return 1 << peg_count if recent == 0 else int(pow(peg_count + 1, recent))


## The peg the disk starts on is already visited.
func start_memory(state: PuzzleState) -> int:
	for peg_index: int in state.pegs.size():
		if state.pegs[peg_index].has(disk):
			return 1 << peg_index if recent == 0 else peg_index + 1
	return 0


func memory_after(facts: MoveFacts, moving: int, _from_peg: int, to_peg: int) -> int:
	if moving != disk:
		return facts.memory
	if recent == 0:
		return facts.memory | (1 << to_peg)
	var base: int = facts.peg_count() + 1
	return (to_peg + 1 + facts.memory * base) % int(pow(base, recent))


## Whether `memory` keeps `peg_index` on the trail (the disk may not go there).
func remembers(memory: int, peg_index: int, peg_count: int) -> bool:
	if recent == 0:
		return (memory >> peg_index) & 1 == 1
	var rest: int = memory
	for i: int in recent:
		if rest % (peg_count + 1) == peg_index + 1:
			return true
		rest /= peg_count + 1
	return false
