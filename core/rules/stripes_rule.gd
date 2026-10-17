class_name StripesRule
extends RuleBase
## "İkirəngli Hanoi" / "Zolaqlı Qüllə" (new mechanics specification v1, section
## 6): odd sizes are one colour, even sizes the other, and two disks of one
## colour never touch (no disk on another of the same parity). On top of the
## other rules, so every stack shows alternating stripes. Level JSON:
##   "rules": ["classic_hanoi", "stripes"]
##
## World 3-4 sub-elements (MindShift_Dunya3-4_Alt_Elementler_v1.md, section 2),
## optional settings:
##   "neutral": disk          "Neytral disk": grey, it touches either colour
##                            and either colour may go on it (sizes still rule)
##   "bases": [per peg]       "Rəngli əsas": 0, or the colour (ODD / EVEN) of a
##                            peg's base, which counts as a disk under its first
##                            disk
##   "paint": peg             "Boya qülləsi": a disk coming down onto this peg
##                            is painted the other colour on the way and keeps
##                            it (the landing is judged in its new colour); the
##                            memory holds which disks are painted (bit d - 1)
##   "inverse": true          "Tərs zolaq": the rule turned round, a disk only
##                            goes onto its own colour (or an empty peg)

const ID: String = "stripes"
## Colours: no colour (the neutral disk, a plain base), odd sizes, even sizes.
const NONE: int = 0
const ODD: int = 1
const EVEN: int = 2

var neutral: int = 0
var bases: Array[int] = []
var paint: int = -1
var inverse: bool = false


func _init() -> void:
	violation_message = "RULE_STRIPES"


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes optional \"neutral\": disk, \"bases\": [0/1/2 per peg], \"paint\": peg, \"inverse\": true" % ID
	for key: String in params:
		if not key in ["neutral", "bases", "paint", "inverse"]:
			return problem
	for key: String in ["neutral", "paint"]:
		var value: Variant = params.get(key, 0 if key == "neutral" else -1)
		if typeof(value) != TYPE_INT or value < (0 if key == "neutral" else -1):
			return problem
	neutral = params.get("neutral", 0)
	paint = params.get("paint", -1)
	var list: Variant = params.get("bases", [])
	if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(c: Variant) -> bool: return typeof(c) == TYPE_INT and c >= NONE and c <= EVEN):
		return problem
	bases.assign(list)
	var turned: Variant = params.get("inverse", false)
	if typeof(turned) != TYPE_BOOL:
		return problem
	inverse = turned
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if neutral > 0:
		params["neutral"] = neutral
	if bases.any(func(c: int) -> bool: return c != NONE):
		params["bases"] = bases.duplicate()
	if paint >= 0:
		params["paint"] = paint
	if inverse:
		params["inverse"] = true
	return params


## The colour of `disk` with `memory` (painted disks have turned).
func colour_of(disk: int, memory: int = 0) -> int:
	if disk == neutral:
		return NONE
	var colour: int = ODD if disk % 2 == 1 else EVEN
	return (EVEN if colour == ODD else ODD) if paint >= 0 and (memory >> (disk - 1)) & 1 == 1 else colour


## The colour `disk` lands in on `peg` (the paint peg turns it on the way).
func landing_colour(disk: int, peg: int, memory: int) -> int:
	var colour: int = colour_of(disk, memory)
	if peg == paint and colour != NONE:
		return EVEN if colour == ODD else ODD
	return colour


## Whether colours `upper` and `lower` may touch (the upper one on the lower).
func may_touch(upper: int, lower: int) -> bool:
	if upper == NONE or lower == NONE:
		return true
	return upper == lower if inverse else upper != lower


func base_of(peg: int) -> int:
	return bases[peg] if peg < bases.size() else NONE


func _allowed(disk: int, to_peg: int, target_top: int, memory: int) -> bool:
	var colour: int = landing_colour(disk, to_peg, memory)
	if target_top == -1:
		return base_of(to_peg) == NONE or may_touch(colour, base_of(to_peg))
	return may_touch(colour, colour_of(target_top, memory))


func is_disk_move_allowed(disk: int, _from_peg: int, to_peg: int, target_top: int) -> bool:
	return _allowed(disk, to_peg, target_top, 0)


func is_move_allowed_with(disk: int, _from_peg: int, to_peg: int, target_top: int, facts: MoveFacts) -> bool:
	return _allowed(disk, to_peg, target_top, facts.memory)


func uses_memory() -> bool:
	return paint >= 0


func memory_states(_peg_count: int, disk_count: int) -> int:
	return 1 << disk_count if paint >= 0 else 1


func memory_after(facts: MoveFacts, disk: int, _from_peg: int, to_peg: int) -> int:
	if to_peg == paint and disk != neutral:
		return facts.memory ^ (1 << (disk - 1))
	return facts.memory


func needs_facts() -> bool:
	return paint >= 0


func supports_disk_move_check() -> bool:
	return paint < 0


## Every stack keeps the rule's colours, its bottom disk its base's. A paint
## level's goal may be reached in any colours, so its positions are not judged
## here (its start is drawn by the rule: LevelForge, and every move is).
func is_state_valid(state: PuzzleState) -> bool:
	if paint >= 0:
		return true
	for peg_index: int in state.pegs.size():
		var stack: Array = state.pegs[peg_index]
		if stack.is_empty():
			continue
		if base_of(peg_index) != NONE and not may_touch(colour_of(stack[0]), base_of(peg_index)):
			return false
		for i: int in range(1, stack.size()):
			if not may_touch(colour_of(stack[i]), colour_of(stack[i - 1])):
				return false
	return true


## A coloured base, the paint peg and the turned rule say so.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	if inverse:
		return "RULE_STRIPES_INVERSE"
	if move.to_peg == paint:
		return "RULE_STRIPES_PAINT"
	if state.get_top_disk(move.to_peg) == -1 and base_of(move.to_peg) != NONE:
		return "RULE_STRIPES_BASE"
	return violation_message


## The paint peg and each base stay with their pegs.
func peg_mark(peg_index: int) -> Variant:
	return [base_of(peg_index), peg_index == paint]


## A painted disk never turns back: on 4 pegs / 5 disks 444 positions with
## the paint peg cannot reach the goal any more (measured 2026-10-17).
func can_dead_end() -> bool:
	return paint >= 0


func params_without_pegs() -> Dictionary:
	var params: Dictionary = {}
	if neutral > 0:
		params["neutral"] = neutral
	if inverse:
		params["inverse"] = true
	return params
