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
## World 7 waves (ICRA World 5-9, section 3.9), optional settings:
##   "clean": peg       "Təmiz qüllə": that peg never stays on a trail
##   "recent": 3 or 4   "Silinən iz": the trail fades after that many of the
##                      disk's moves (the base form keeps two)
##   "disks": [a, b]    "İki izli disk": two disks, each with its own trail
##                      (instead of "disk"; the memory holds both)
##   a "disk" that is the largest one: "Böyük iz"

const ID: String = "trail"

## The disks that leave a trail (one, or two).
var disks: Array[int] = []
## How many of its latest pegs the trail remembers (0: every peg it has stood on).
var recent: int = 0
var clean: int = -1


func _init() -> void:
	violation_message = "RULE_TRAIL"


func get_id() -> String:
	return ID


## The (first) disk that leaves the trail.
var disk: int:
	get:
		return disks[0] if not disks.is_empty() else 0


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"disk\": the disk that leaves the trail} or \"disks\": [two], optional \"recent\", \"clean\"" % ID
	for key: String in params:
		if not key in ["disk", "disks", "recent", "clean"]:
			return problem
	if params.has("disk") == params.has("disks"):
		return problem
	var list: Variant = [params["disk"]] if params.has("disk") else params["disks"]
	if typeof(list) != TYPE_ARRAY or not (list as Array).size() in [1, 2] \
			or not (list as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 1):
		return problem
	disks.assign(list)
	if disks.size() == 2 and disks[0] == disks[1]:
		return problem
	var count: Variant = params.get("recent", 0)
	var peg: Variant = params.get("clean", -1)
	if typeof(count) != TYPE_INT or count < 0 or typeof(peg) != TYPE_INT or peg < -1:
		return problem
	recent = count
	clean = peg
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"disk": disks[0]} if disks.size() == 1 else {"disks": disks.duplicate()}
	if recent != 0:
		params["recent"] = recent
	if clean >= 0:
		params["clean"] = clean
	return params


func is_move_allowed_with(moving: int, _from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	var index: int = disks.find(moving)
	return index == -1 or not remembers_of(facts.memory, index, to_peg, facts.peg_count())


func uses_memory() -> bool:
	return true


## The memory of one trail: every peg, one bit each; the latest `recent`, one
## digit (peg + 1, 0 none) in base peg_count + 1 each, the newest lowest.
func _trail_states(peg_count: int) -> int:
	return 1 << peg_count if recent == 0 else int(pow(peg_count + 1, recent))


func memory_states(peg_count: int, _disk_count: int) -> int:
	return int(pow(_trail_states(peg_count), disks.size()))


## The peg each tracked disk starts on is already visited.
func start_memory(state: PuzzleState) -> int:
	var memory: int = 0
	var scale: int = 1
	for tracked: int in disks:
		for peg_index: int in state.pegs.size():
			if state.pegs[peg_index].has(tracked) and peg_index != clean:
				memory += scale * ((1 << peg_index) if recent == 0 else peg_index + 1)
		scale *= _trail_states(state.pegs.size())
	return memory


func memory_after(facts: MoveFacts, moving: int, _from_peg: int, to_peg: int) -> int:
	var index: int = disks.find(moving)
	if index == -1 or to_peg == clean:
		return facts.memory
	var states: int = _trail_states(facts.peg_count())
	var scale: int = int(pow(states, index))
	var own: int = (facts.memory / scale) % states
	var after: int
	if recent == 0:
		after = own | (1 << to_peg)
	else:
		var base: int = facts.peg_count() + 1
		after = (to_peg + 1 + own * base) % int(pow(base, recent))
	return facts.memory - own * scale + after * scale


## Whether `memory` keeps `peg_index` on the first disk's trail.
func remembers(memory: int, peg_index: int, peg_count: int) -> bool:
	return remembers_of(memory, 0, peg_index, peg_count)


## Whether `memory` keeps `peg_index` on the trail of tracked disk `index`.
func remembers_of(memory: int, index: int, peg_index: int, peg_count: int) -> bool:
	if peg_index == clean:
		return false
	var states: int = _trail_states(peg_count)
	var own: int = (memory / int(pow(states, index))) % states
	if recent == 0:
		return (own >> peg_index) & 1 == 1
	var rest: int = own
	for i: int in recent:
		if rest % (peg_count + 1) == peg_index + 1:
			return true
		rest /= peg_count + 1
	return false


## The clean peg travels with its peg.
func peg_mark(peg_index: int) -> Variant:
	return peg_index == clean


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("clean")
	return params
