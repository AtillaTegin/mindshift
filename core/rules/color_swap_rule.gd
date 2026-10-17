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
## World 5 waves (ICRA World 5-9, section 3.3), optional settings:
##   "caravanserai": peg  "Karvansara": on that middle peg colours may mix
##                        (the colour rule does not apply onto it)
##   "colours": 3         "Üç karvan": white, black and red; id 3(s - 1) + c + 1
##                        is the disk of size s and colour c (0 white, 1 black,
##                        2 red), still ordered by size

const ID: String = "color_swap"
const SIZE_MESSAGE: String = "RULE_CLASSIC_HANOI"
const SAME_SIZE_MESSAGE: String = "RULE_SAME_SIZE"
const COLOUR_MESSAGE: String = "RULE_COLOUR_TOUCH"
const WHITE: int = 0
const BLACK: int = 1
const RED: int = 2

var colour_bound: bool = false
var colours: int = 2
var caravanserai: int = -1


func _init() -> void:
	violation_message = SIZE_MESSAGE


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"colour\": true or false}, optional \"colours\": 2 or 3 and \"caravanserai\": peg" % ID
	var value: Variant = params.get("colour")
	if typeof(value) != TYPE_BOOL:
		return problem
	for key: String in params:
		if not key in ["colour", "colours", "caravanserai"]:
			return problem
	var count: Variant = params.get("colours", 2)
	var inn: Variant = params.get("caravanserai", -1)
	if typeof(count) != TYPE_INT or not count in [2, 3] or typeof(inn) != TYPE_INT or inn < -1:
		return problem
	colour_bound = value
	colours = count
	caravanserai = inn
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {"colour": colour_bound}
	if colours != 2:
		params["colours"] = colours
	if caravanserai >= 0:
		params["caravanserai"] = caravanserai
	return params


## Size of disk `id` (1..k) with `count` colours.
static func size_of(id: int, count: int = 2) -> int:
	return (id - 1) / count + 1


## Colour of disk `id` (WHITE, BLACK, RED) with `count` colours.
static func colour_of(id: int, count: int = 2) -> int:
	return (id - 1) % count


static func is_white(id: int, count: int = 2) -> bool:
	return colour_of(id, count) == WHITE


## The id of the white or black disk of `size`.
static func disk_of(size: int, white: bool) -> int:
	return size * 2 - (1 if white else 0)


## The id of the disk of `size` and `colour` with `count` colours.
static func disk_with(size: int, colour: int, count: int) -> int:
	return count * (size - 1) + colour + 1


func size(id: int) -> int:
	return size_of(id, colours)


func colour(id: int) -> int:
	return colour_of(id, colours)


func is_disk_move_allowed(disk: int, _from_peg: int, to_peg: int, target_top: int) -> bool:
	if target_top == -1:
		return true
	return size(disk) < size(target_top) and (not colour_bound or to_peg == caravanserai or colour(disk) == colour(target_top))


## The size condition first (larger, then equal), else the colour one.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	var disk: int = state.get_top_disk(move.from_peg)
	var target: int = state.get_top_disk(move.to_peg)
	if target == -1 or size(disk) > size(target):
		return SIZE_MESSAGE
	return SAME_SIZE_MESSAGE if size(disk) == size(target) else COLOUR_MESSAGE


## Every peg strictly smaller towards the top (a start may mix the colours:
## the colour condition only limits moves).
func is_state_valid(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for i: int in range(1, peg.size()):
			if size(peg[i]) >= size(peg[i - 1]):
				return false
	return true


## White and black swapped make the same puzzle (with the board mirrored, the
## goal's sides come back). Three colours turned round in their cycle keep the
## same puzzle too.
func disk_swaps(disks: Array) -> Array[Dictionary]:
	var swaps: Array[Dictionary] = []
	for shift: int in range(1, colours):
		var swap: Dictionary = {}
		for disk: int in disks:
			var hue: int = colour(disk)
			var turned: int = (hue + shift) % colours if colours == 3 else 1 - hue
			swap[disk] = disk_with(size(disk), turned, colours)
		swaps.append(swap)
	return swaps


## The caravanserai is a peg of its own; three caravans need their homes.
func peg_symmetry() -> String:
	return PEGS_ANY if caravanserai < 0 and colours == 2 else PEGS_LINE


func peg_mark(peg_index: int) -> Variant:
	return "inn" if peg_index == caravanserai else null


func params_without_pegs() -> Dictionary:
	var params: Dictionary = get_params()
	params.erase("caravanserai")
	return params


## The mixed kind: a disk lifted off the other colour never goes back onto
## it, so a few moves can leave the goal out of reach (on 4 pegs about half of
## a dozen random games did; the dead region then holds ~10 positions,
## measured 2026-10-16). The pure kind can always take a move back.
func can_dead_end() -> bool:
	return colour_bound


func supports_disk_move_check() -> bool:
	return true


func keeps_stacks_sorted() -> bool:
	return true
