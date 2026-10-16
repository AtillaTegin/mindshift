class_name MirrorRule
extends RuleBase
## "Güzgü Hanoi", the "Əks-səda" rule (Fəsil Sistemi v1.2, section 6; it
## replaced the two independent boards of specification v1): two boards, the
## first half of the pegs on top, the second half below. The player only plays
## the top board; every move echoes on the bottom board in the mirror (top peg
## i <-> bottom peg n-1-i of the n pegs a board has: on 3 pegs 1<->3, 2<->2)
## when it is possible there, else the bottom board stays as it is. The goal
## is the top board's goal with the bottom board as its mirror image (the
## level's goal position holds both). The bottom board's disks have the
## higher ids, so the classic rule keeps working on both. Level JSON:
##   "rules": ["classic_hanoi", "mirror"]

const ID: String = "mirror"


func _init() -> void:
	violation_message = "RULE_MIRROR"


func get_id() -> String:
	return ID


## Only the top board is played.
func is_move_allowed_with(_disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	var half: int = facts.peg_count() / 2
	return from_peg < half and to_peg < half


## An even number of pegs (two equal boards), the disks of the top board
## below the bottom board's.
func is_state_valid(state: PuzzleState) -> bool:
	if state.pegs.size() % 2 != 0:
		return false
	var half: int = state.pegs.size() / 2
	var top_largest: int = 0
	var bottom_smallest: int = 1 << 30
	for peg_index: int in state.pegs.size():
		for disk: int in state.pegs[peg_index]:
			if peg_index < half:
				top_largest = maxi(top_largest, disk)
			else:
				bottom_smallest = mini(bottom_smallest, disk)
	return top_largest < bottom_smallest


## The bottom board's mirror of a top board move.
func echo_of(after: PuzzleState, move: Move) -> Move:
	var half: int = after.pegs.size() / 2
	if move.from_peg >= half or move.to_peg >= half:
		return null
	return Move.new(mirror_peg(move.from_peg, half), mirror_peg(move.to_peg, half))


func echoes() -> bool:
	return true


func needs_facts() -> bool:
	return true


## The bottom board peg that mirrors top board peg `peg` (boards of `half` pegs).
static func mirror_peg(peg: int, half: int) -> int:
	return half + (half - 1 - peg)


## The bottom board that mirrors `top` (its disks renumbered from `offset` up).
static func mirrored(top: Array, offset: int) -> Array:
	var bottom: Array = []
	for i: int in range(top.size() - 1, -1, -1):
		bottom.append((top[i] as Array).map(func(disk: int) -> int: return disk + offset))
	return bottom
