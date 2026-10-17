class_name BalanceRule
extends RuleBase
## "Tərəzi Hanoi" / "Qədim Tərəzi" (new mechanics specification v1, section 1):
## the pegs come in pairs (0-1, 2-3, ...), the two pans of a scale. In every
## position the sums of the disk sizes on the two pegs of a pair differ by at
## most `tolerance` (user decision 2026-10-15: start, goal and every position
## after a move); a move that would tip a pair further is refused. On top of
## the other rules; boards of 4 or 6 pegs. Level JSON:
##   "rules": ["classic_hanoi", "balance"], "rule_params": {"balance": {"tolerance": 4}}
##
## World 3-4 sub-elements (MindShift_Dunya3-4_Alt_Elementler_v1.md, section 5),
## optional settings beside "tolerance":
##   "weights": [per peg]      "Çəki daşı": a fixed stone of that weight on a pan
##   "factors": [per peg]      "Uzun qol": 2 on the pan of a long arm, whose
##                             disks weigh double there (1 elsewhere)
##   "tolerances": [per pair]  "Fərqli hədlər": each scale its own limit (in
##                             place of "tolerance")
##   "moving_stone": true      "Hərəkətli daş" (the island): the stone may be
##                             carried once to the other pan of its scale, a
##                             move of its own (Move.new(pan, pan), see
##                             special_moves()); the memory says whether it was
## "Üç tərəzi" is a board of 6 pegs: three scales.

const ID: String = "balance"

var tolerance: int = 0
var tolerances: Array[int] = []
var weights: Array[int] = []
var factors: Array[int] = []
var moving_stone: bool = false


func _init() -> void:
	violation_message = "RULE_BALANCE"


func get_id() -> String:
	return ID


## Each scale's two pans stay together.
func peg_symmetry() -> String:
	return PEGS_PAIRS


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" needs {\"tolerance\": n} or {\"tolerances\": [n per scale]}, optional \"weights\" and \"factors\" (one per peg) and \"moving_stone\": true" % ID
	for key: String in params:
		if not key in ["tolerance", "tolerances", "weights", "factors", "moving_stone"]:
			return problem
	if params.has("tolerance") == params.has("tolerances"):
		return problem
	var value: Variant = params.get("tolerance", 0)
	if typeof(value) != TYPE_INT or value < 0:
		return problem
	tolerance = value
	for key: String in ["tolerances", "weights", "factors"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY or not (list as Array).all(func(n: Variant) -> bool:
				return typeof(n) == TYPE_INT and n >= (1 if key == "factors" else 0)):
			return problem
	tolerances.assign(params.get("tolerances", []))
	weights.assign(params.get("weights", []))
	factors.assign(params.get("factors", []))
	if not tolerances.is_empty():
		tolerance = tolerances.max()
	var stone: Variant = params.get("moving_stone", false)
	if typeof(stone) != TYPE_BOOL or (stone and stone_pan() == -1):
		return problem
	moving_stone = stone
	return ""


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if tolerances.is_empty():
		params["tolerance"] = tolerance
	else:
		params["tolerances"] = tolerances.duplicate()
	if weights.any(func(n: int) -> bool: return n > 0):
		params["weights"] = weights.duplicate()
	if factors.any(func(n: int) -> bool: return n != 1):
		params["factors"] = factors.duplicate()
	if moving_stone:
		params["moving_stone"] = true
	return params


## The pair partner of `peg` (0 <-> 1, 2 <-> 3, ...).
static func pan_of(peg: int) -> int:
	return peg + 1 if peg % 2 == 0 else peg - 1


## The limit of the scale of `peg`.
func limit_of(peg: int) -> int:
	return tolerances[peg / 2] if peg / 2 < tolerances.size() else tolerance


func factor_of(peg: int) -> int:
	return factors[peg] if peg < factors.size() else 1


## The pan the stone starts on, or -1 without one.
func stone_pan() -> int:
	for peg: int in weights.size():
		if weights[peg] > 0:
			return peg
	return -1


## The stone's weight on `peg` with `memory` (1: the stone was carried over).
func stone_on(peg: int, memory: int) -> int:
	var start: int = stone_pan()
	if start == -1:
		return 0
	var now: int = pan_of(start) if memory == 1 else start
	return weights[start] if peg == now else 0


## What pan `peg` weighs with disk sizes `sum`: long arms double, the stone adds.
func weight_of(peg: int, sum: int, memory: int = 0) -> int:
	return factor_of(peg) * sum + stone_on(peg, memory)


## The two pairs the move touches stay within their limits afterwards.
func is_move_allowed_with(disk: int, from_peg: int, to_peg: int, _target_top: int, facts: MoveFacts) -> bool:
	var sums: PackedInt32Array = facts.sums
	var from_pan: int = pan_of(from_peg)
	var to_pan: int = pan_of(to_peg)
	var from_after: int = weight_of(from_peg, sums[from_peg] - disk, facts.memory)
	var to_after: int = weight_of(to_peg, sums[to_peg] + disk, facts.memory)
	var from_pan_after: int = weight_of(from_pan, sums[from_pan] + (disk if from_pan == to_peg else 0), facts.memory)
	var to_pan_after: int = weight_of(to_pan, sums[to_pan] - (disk if to_pan == from_peg else 0), facts.memory)
	return absi(from_after - from_pan_after) <= limit_of(from_peg) and absi(to_after - to_pan_after) <= limit_of(to_peg)


## An even number of pegs and every pair within its limit (the stone where it
## starts).
func is_state_valid(state: PuzzleState) -> bool:
	if state.pegs.size() % 2 != 0:
		return false
	for peg: int in range(0, state.pegs.size(), 2):
		if absi(weight_of(peg, sum_of(state.pegs[peg])) - weight_of(peg + 1, sum_of(state.pegs[peg + 1]))) > limit_of(peg):
			return false
	return true


static func sum_of(stack: Array) -> int:
	var total: int = 0
	for disk: int in stack:
		total += disk
	return total


func needs_facts() -> bool:
	return true


## Carrying the stone over: once, while both pans stay within the limit.
func uses_memory() -> bool:
	return moving_stone


func memory_states(_peg_count: int, _disk_count: int) -> int:
	return 2 if moving_stone else 1


## The stone's own move (Move.new(pan, pan): the stone leaves `pan`) where it
## may be carried now; none otherwise.
func special_moves(facts: MoveFacts) -> Array[Move]:
	var moves: Array[Move] = []
	if not moving_stone or facts.memory == 1:
		return moves
	var pan: int = stone_pan()
	var other: int = pan_of(pan)
	if absi(weight_of(pan, facts.sums[pan], 1) - weight_of(other, facts.sums[other], 1)) <= limit_of(pan):
		moves.append(Move.new(pan, pan))
	return moves


func special_memory_after(_facts: MoveFacts, _move: Move) -> int:
	return 1


func has_special_moves() -> bool:
	return moving_stone


## The stone's button shows until it has been carried over.
func special_open(facts: MoveFacts) -> bool:
	return moving_stone and facts.memory == 0


## Carried over, the stone never comes back.
func can_dead_end() -> bool:
	return moving_stone


## Each pan's stone and arm, and its scale's limit, stay with it.
func peg_mark(peg_index: int) -> Variant:
	return [weights[peg_index] if peg_index < weights.size() else 0, factor_of(peg_index), limit_of(peg_index)]


func params_without_pegs() -> Dictionary:
	return {"moving_stone": true} if moving_stone else {}
