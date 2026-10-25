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
##   "fade": n          "Silinən iz": every peg the disk leaves stays on its
##                      trail for the next n moves of any disk, then the mark
##                      fades (instead of "recent"; a countdown per peg)
##   "disks": [a, b]    "İki izli disk": two disks, each with its own trail
##                      (instead of "disk"; the memory holds both)
## "Böyük iz" (the largest disk leaves the trail) is not built: the largest
## disk never has to come back to a peg, so it never changed a solution.

const ID: String = "trail"

## The disks that leave a trail (one, or two).
var disks: Array[int] = []
## How many of its latest pegs the trail remembers (0: every peg it has stood on).
var recent: int = 0
var clean: int = -1
## How many moves a peg the disk left stays on its trail (0: no fading).
var fade: int = 0


func _init() -> void:
	violation_message = "RULE_TRAIL"


func get_id() -> String:
	return ID


## The (first) disk that leaves the trail.
var disk: int:
	get:
		return disks[0] if not disks.is_empty() else 0


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"disk\": the disk that leaves the trail} or \"disks\": [two], optional \"recent\" or \"fade\", \"clean\"" % ID
	for key: String in params:
		if not key in ["disk", "disks", "recent", "clean", "fade"]:
			return problem
	if params.has("disk") == params.has("disks") or (params.has("recent") and params.has("fade")):
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
	var moves: Variant = params.get("fade", 0)
	if typeof(count) != TYPE_INT or count < 0 or typeof(peg) != TYPE_INT or peg < -1 \
			or typeof(moves) != TYPE_INT or moves < 0:
		return problem
	recent = count
	clean = peg
	fade = moves
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"disk": disks[0]} if disks.size() == 1 else {"disks": disks.duplicate()}
	if recent != 0:
		params["recent"] = recent
	if clean >= 0:
		params["clean"] = clean
	if fade > 0:
		params["fade"] = fade
	return params


func is_move_allowed_with(moving: int, _from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	var index: int = disks.find(moving)
	return index == -1 or not remembers_of(facts.memory, index, to_peg, facts.peg_count())


func uses_memory() -> bool:
	return true


## The memory of one trail: every peg, one bit each; the latest `recent`, one
## digit (peg + 1, 0 none) in base peg_count + 1 each, the newest lowest; a
## fading trail one digit per peg, the moves its mark still lasts (base fade + 1).
func _trail_states(peg_count: int) -> int:
	if fade > 0:
		return int(pow(fade + 1, peg_count))
	return 1 << peg_count if recent == 0 else int(pow(peg_count + 1, recent))


func memory_states(peg_count: int, _disk_count: int) -> int:
	return int(pow(_trail_states(peg_count), disks.size()))


## The peg each tracked disk starts on is already visited (a fading trail
## marks a peg only once the disk leaves it).
func start_memory(state: PuzzleState) -> int:
	var memory: int = 0
	if fade > 0:
		return memory
	var scale: int = 1
	for tracked: int in disks:
		for peg_index: int in state.pegs.size():
			if state.pegs[peg_index].has(tracked) and peg_index != clean:
				memory += scale * ((1 << peg_index) if recent == 0 else peg_index + 1)
		scale *= _trail_states(state.pegs.size())
	return memory


## The clean peg leaves no mark, but the disk's older steps still fade (an
## empty step in its place).
func memory_after(facts: MoveFacts, moving: int, from_peg: int, to_peg: int) -> int:
	if fade > 0:
		return _faded_after(facts.memory, moving, from_peg, facts.peg_count())
	var index: int = disks.find(moving)
	if index == -1 or (to_peg == clean and recent == 0):
		return facts.memory
	var states: int = _trail_states(facts.peg_count())
	var scale: int = int(pow(states, index))
	var own: int = (facts.memory / scale) % states
	var after: int
	if recent == 0:
		after = own | (1 << to_peg)
	else:
		var base: int = facts.peg_count() + 1
		var step: int = 0 if to_peg == clean else to_peg + 1
		after = (step + own * base) % int(pow(base, recent))
	return facts.memory - own * scale + after * scale


## A fading trail after a move: every mark one move older, then the peg a
## tracked disk just left (not the clean one) marked for `fade` moves.
func _faded_after(memory: int, moving: int, from_peg: int, peg_count: int) -> int:
	var base: int = fade + 1
	var after: int = 0
	var scale: int = 1
	for index: int in disks.size():
		for peg_index: int in peg_count:
			var left: int = memory / scale % base
			if disks[index] == moving and peg_index == from_peg and peg_index != clean:
				left = fade
			elif left > 0:
				left -= 1
			after += left * scale
			scale *= base
	return after


## How many more moves `peg_index` stays on the fading trail of tracked disk
## `index` (0: not on it; always 0 without fading).
func fade_left(memory: int, index: int, peg_index: int, peg_count: int) -> int:
	if fade == 0:
		return 0
	return memory / int(pow(fade + 1, index * peg_count + peg_index)) % (fade + 1)


## Whether `memory` keeps `peg_index` on the first disk's trail.
func remembers(memory: int, peg_index: int, peg_count: int) -> bool:
	return remembers_of(memory, 0, peg_index, peg_count)


## Whether `memory` keeps `peg_index` on the trail of tracked disk `index`.
func remembers_of(memory: int, index: int, peg_index: int, peg_count: int) -> bool:
	if peg_index == clean:
		return false
	if fade > 0:
		return fade_left(memory, index, peg_index, peg_count) > 0
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
