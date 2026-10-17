class_name AlternationRule
extends RuleBase
## The Nine Rings alternation (cultural integration addendum, section 1, in the
## user's variant D of 2026-10-12): on top of the other rules, disk 1 (the
## smallest) may always move; right after disk 1 any disk may move; after any
## other disk only disk 1 or a disk one size away from it (±1) may. At a level
## start nothing has moved yet, so only disk 1 may go. Refused moves are just
## blocked, never punished. Level JSON:
##   "rules": ["classic_hanoi", "alternation"]
## The literal rule of the addendum (no "anything after disk 1") lets only
## disks 1-3 ever move on 3-4 pegs (measured 2026-10-11), hence variant D.
## It looks at PuzzleState.last_moved_disk (uses_last_move), so the Solver keeps
## the last moved disk in its search state; the Solver still never names it.
##
## World 3-4 sub-elements (MindShift_Dunya3-4_Alt_Elementler_v1.md, section 4),
## optional settings:
##   "free": disk       "Qırıq halqa": this disk ignores the turns, it moves
##                      whenever it fits
##   "reset": peg       "Sıfırlama qülləsi": right after a disk is put on this
##                      peg any disk may move
##   "leader": disk     "Yeni lider": this disk, not disk 1, is the one always
##                      free (and the one after which any disk may move)
##   "waiting": disk    "Gözləyən halqa": this disk only moves right after the
##                      leader (one size away is not enough for it)

const ID: String = "alternation"

var free: int = 0
var reset: int = -1
var leader: int = 1
var waiting: int = 0


func _init() -> void:
	violation_message = "RULE_ALTERNATION"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes optional \"free\": disk, \"reset\": peg, \"leader\": disk, \"waiting\": disk" % ID
	for key: String in params:
		if not key in ["free", "reset", "leader", "waiting"] or typeof(params[key]) != TYPE_INT:
			return problem
	free = params.get("free", 0)
	reset = params.get("reset", -1)
	leader = params.get("leader", 1)
	waiting = params.get("waiting", 0)
	if leader < 1 or free < 0 or waiting < 0 or reset < -1 or (waiting > 0 and waiting == leader):
		return problem
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if free > 0:
		params["free"] = free
	if reset >= 0:
		params["reset"] = reset
	if leader != 1:
		params["leader"] = leader
	if waiting > 0:
		params["waiting"] = waiting
	return params


## Whether `disk` may move after `last_disk` (0: nothing yet); `reset_last`:
## the last disk was put on the reset peg.
func movable(disk: int, last_disk: int, reset_last: bool = false) -> bool:
	if disk == free:
		return true
	if disk == waiting:
		return last_disk == leader
	if disk == leader:
		return true
	if last_disk == 0:
		return false
	return reset_last or last_disk == leader or absi(disk - last_disk) == 1


func is_disk_movable(disk: int, last_disk: int) -> bool:
	return movable(disk, last_disk)


func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	return movable(disk, facts.last_disk, _reset_last(facts))


func _reset_last(facts: MoveFacts) -> bool:
	return reset >= 0 and facts.last_disk > 0 and facts.last_disk < facts.peg_of.size() \
			and facts.peg_of[facts.last_disk] == reset


func is_disk_move_allowed_after(disk: int, _from_peg: int, _to_peg: int, _target_top: int, last_disk: int) -> bool:
	return movable(disk, last_disk)


func is_move_allowed_with(disk: int, _from_peg: int, _to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	return movable(disk, facts.last_disk, _reset_last(facts))


## Without the last move this rule cannot judge a move; the Solver and RuleSet
## always go through is_disk_move_allowed_after().
func is_disk_move_allowed(_disk: int, _from_peg: int, _to_peg: int, _target_top: int) -> bool:
	return true


func uses_last_move() -> bool:
	return true


## The reset peg needs to know where the last disk went.
func needs_facts() -> bool:
	return reset >= 0


func supports_disk_move_check() -> bool:
	return reset < 0


## The waiting disk says why it waits; under a new leader the words name the
## crowned disk, not disk 1.
func pick_up_message(disk: int, _facts: MoveFacts) -> String:
	if disk == waiting:
		return "RULE_WAITING"
	return "RULE_ALTERNATION_LEADER" if leader != 1 else violation_message


func get_violation_message(state: PuzzleState, move: Move) -> String:
	return pick_up_message(state.get_top_disk(move.from_peg), null)


## The reset peg stays with its peg.
func peg_mark(peg_index: int) -> Variant:
	return peg_index == reset


## With another leader than disk 1 a position can lose the way to the goal
## (one on 4 pegs / 5 disks, measured 2026-10-17).
func can_dead_end() -> bool:
	return leader != 1


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("reset")
	return params
