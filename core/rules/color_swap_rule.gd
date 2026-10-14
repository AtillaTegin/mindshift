class_name ColorSwapRule
extends RuleBase
## "Böyük Mübadilə" v2 (addendum 2026-10-13, user decision on its two kinds):
## white and black disks, one of each size 1..k. Disk ids carry both: id
## 2s - 1 is the white disk of size s, id 2s the black one, so a stack ordered
## by size is ordered by id too and the Solver keeps its fast path.
## - Size: a disk only goes onto a larger one (equal sizes do not stack).
## - Colour (`{"colour": true}`, the mixed kind "Qarışıq-Ayırma"): also never
##   onto a disk of the other colour. The pure kind "Təmiz Dəyişmə" leaves it
##   out ({"colour": false}): colour then only marks which stack is which.
## A refused move names the broken condition (get_violation_message; the user
## asked for a clear message, never a silent refusal). Level JSON:
##   "rules": ["color_swap"], "rule_params": {"color_swap": {"colour": true}}

const ID: String = "color_swap"
const SIZE_MESSAGE: String = "RULE_CLASSIC_HANOI"
const SAME_SIZE_MESSAGE: String = "RULE_SAME_SIZE"
const COLOUR_MESSAGE: String = "RULE_COLOUR_TOUCH"

var colour_bound: bool = false


func _init() -> void:
	violation_message = SIZE_MESSAGE


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var value: Variant = params.get("colour")
	if params.size() != 1 or typeof(value) != TYPE_BOOL:
		return "rule \"%s\" needs {\"colour\": true or false}" % ID
	colour_bound = value
	return ""


func get_params() -> Dictionary:
	return {"colour": colour_bound}


## Size of disk `id` (1..k).
static func size_of(id: int) -> int:
	return (id + 1) / 2


static func is_white(id: int) -> bool:
	return id % 2 == 1


## The id of the white or black disk of `size`.
static func disk_of(size: int, white: bool) -> int:
	return size * 2 - (1 if white else 0)


func is_disk_move_allowed(disk: int, _from_peg: int, _to_peg: int, target_top: int) -> bool:
	if target_top == -1:
		return true
	return size_of(disk) < size_of(target_top) and (not colour_bound or is_white(disk) == is_white(target_top))


## The size condition first (larger, then equal), else the colour one.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	var disk: int = state.get_top_disk(move.from_peg)
	var target: int = state.get_top_disk(move.to_peg)
	if target == -1 or size_of(disk) > size_of(target):
		return SIZE_MESSAGE
	return SAME_SIZE_MESSAGE if size_of(disk) == size_of(target) else COLOUR_MESSAGE


## Every peg strictly smaller towards the top (a start may mix the colours:
## the colour condition only limits moves).
func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for i: int in range(1, peg.size()):
			if size_of(peg[i]) >= size_of(peg[i - 1]):
				return false
	return true


func supports_disk_move_check() -> bool:
	return true


func keeps_stacks_sorted() -> bool:
	return true
