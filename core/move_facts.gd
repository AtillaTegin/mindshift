class_name MoveFacts
extends RefCounted
## What a rule may know about the position a move starts from, beyond the
## moving disk, the two pegs and the target's top disk
## (RuleBase.is_move_allowed_with): the disk that moved last, the rules'
## memory, and per peg its disk count, the sum of its disk sizes and its top
## disk, plus the peg of every disk. RuleSet builds one from a PuzzleState; the
## Solver refills one for every position it expands, so rules never see how
## the search stores positions.

var last_disk: int = 0
## The rules' memory (PuzzleState.memory, already resolved: never -1).
var memory: int = 0
## Per peg: how many disks it holds, the sum of their sizes, its top disk (-1
## when empty).
var counts: PackedInt32Array = PackedInt32Array()
var sums: PackedInt32Array = PackedInt32Array()
var tops: PackedInt32Array = PackedInt32Array()
## Peg of disk i at index i (index 0 unused; -1 for a disk not on the board).
var peg_of: PackedInt32Array = PackedInt32Array()


## The facts of `state` under `rules` (its memory resolved by RuleSet).
static func of(state: PuzzleState, rules: RuleSet) -> MoveFacts:
	var facts: MoveFacts = MoveFacts.new()
	var peg_count: int = state.pegs.size()
	var largest: int = 0
	for peg: Array in state.pegs:
		for disk: int in peg:
			largest = maxi(largest, disk)
	facts.reset(peg_count, largest)
	for peg_index: int in peg_count:
		for disk: int in state.pegs[peg_index]:
			facts.add(disk, peg_index)
	facts.last_disk = state.last_moved_disk
	facts.memory = rules.memory_of(state) if rules != null else maxi(state.memory, 0)
	return facts


## Empties the facts for `peg_count` pegs and disks up to `largest_disk`.
func reset(peg_count: int, largest_disk: int) -> void:
	counts.resize(peg_count)
	sums.resize(peg_count)
	tops.resize(peg_count)
	counts.fill(0)
	sums.fill(0)
	tops.fill(-1)
	peg_of.resize(largest_disk + 1)
	peg_of.fill(-1)


## Puts `disk` on top of `peg_index` (disks are added bottom to top).
func add(disk: int, peg_index: int) -> void:
	counts[peg_index] += 1
	sums[peg_index] += disk
	tops[peg_index] = disk
	peg_of[disk] = peg_index


func peg_count() -> int:
	return counts.size()


## Whether `disk` is the top disk of its peg.
func is_top(disk: int) -> bool:
	return disk > 0 and disk < peg_of.size() and peg_of[disk] >= 0 and tops[peg_of[disk]] == disk
