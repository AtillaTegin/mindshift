class_name AdjacentPegsRule
extends RuleBase
## "Karvan Yolu" (caravan road addendum, section 1; Hanoi variant C, linear
## adjacency): the pegs stand in a line like caravan stops, and a disk may only
## move to a neighbouring peg (from peg i to i - 1 or i + 1), never jump over
## one. On top of the other rules. Level JSON:
##   "rules": ["classic_hanoi", "adjacent_pegs"]
## This is the fixed, linear case of the linked-pegs idea (no relinking).
##
## World 3-4 sub-elements (MindShift_Dunya3-4_Alt_Elementler_v1.md, section 1),
## optional settings:
##   "oasis": [peg, stop]       "Vaha": a small stop beside the road that holds
##                              one disk and is linked to `stop` only; it is not
##                              on the road (the road's stops are the other pegs,
##                              in order)
##   "tunnels": [[a, b]]        "Kəhriz": stops a and b are neighbours too
##   "bridges": [[a, b, n]]     "Dar körpü": between the neighbouring stops a and
##                              b only disks up to size n pass
##   "one_way": [[a, b]]        "Birtərəfli yol": between the neighbouring stops
##                              a and b only from a to b
##   "jump": true               "Sıçrayış" (the island): a disk may jump over a
##                              neighbouring stop whose top disk is larger, to
##                              the stop after it
## Without settings it judges a move from the two pegs alone (the Solver's fast
## path); the oasis and the jump look at the position (MoveFacts).

const ID: String = "adjacent_pegs"
## Pegs the precomputed tables cover.
const MAX_PEGS: int = 16

var oasis: int = -1
var oasis_stop: int = -1
var tunnels: Array[Array] = []
var bridges: Array[Array] = []
var one_way: Array[Array] = []
var jump: bool = false
## For a step from a to b (index a * MAX_PEGS + b): the largest disk that may
## take it (0: not linked, 255: any).
var _largest: PackedByteArray = PackedByteArray()


func _init() -> void:
	violation_message = "RULE_ADJACENT_PEGS"
	_build_tables()


func get_id() -> String:
	return ID


func configure(params: Dictionary) -> String:
	var problem: String = "rule \"%s\" takes optional \"oasis\": [peg, stop], \"tunnels\": [[a, b]], \"bridges\": [[a, b, size]], \"one_way\": [[from, to]], \"jump\": true" % ID
	for key: String in params:
		if not key in ["oasis", "tunnels", "bridges", "one_way", "jump"]:
			return problem
	var pair: Variant = params.get("oasis", [])
	if not _ints(pair) or not ((pair as Array).is_empty() or (pair as Array).size() == 2):
		return problem
	if (pair as Array).size() == 2:
		oasis = pair[0]
		oasis_stop = pair[1]
	for key: String in ["tunnels", "bridges", "one_way"]:
		var list: Variant = params.get(key, [])
		if typeof(list) != TYPE_ARRAY:
			return problem
		for item: Variant in list:
			if not _ints(item) or (item as Array).size() != (3 if key == "bridges" else 2):
				return problem
		(tunnels if key == "tunnels" else bridges if key == "bridges" else one_way).assign(list)
	var hop: Variant = params.get("jump", false)
	if typeof(hop) != TYPE_BOOL:
		return problem
	jump = hop
	_build_tables()
	return ""


func _build_tables() -> void:
	_largest.resize(MAX_PEGS * MAX_PEGS)
	_largest.fill(0)
	for a: int in MAX_PEGS:
		for b: int in MAX_PEGS:
			var here: int = road_place(a)
			var there: int = road_place(b)
			if here >= 0 and there >= 0 and absi(here - there) == 1:
				_largest[a * MAX_PEGS + b] = 255
	for tunnel: Array in tunnels:
		_largest[tunnel[0] * MAX_PEGS + tunnel[1]] = 255
		_largest[tunnel[1] * MAX_PEGS + tunnel[0]] = 255
	for bridge: Array in bridges:
		_largest[bridge[0] * MAX_PEGS + bridge[1]] = mini(bridge[2], 254)
		_largest[bridge[1] * MAX_PEGS + bridge[0]] = mini(bridge[2], 254)
	for arrow: Array in one_way:
		_largest[arrow[1] * MAX_PEGS + arrow[0]] = 0


func get_params() -> Dictionary:
	var params: Dictionary = {}
	if oasis >= 0:
		params["oasis"] = [oasis, oasis_stop]
	if not tunnels.is_empty():
		params["tunnels"] = tunnels.duplicate(true)
	if not bridges.is_empty():
		params["bridges"] = bridges.duplicate(true)
	if not one_way.is_empty():
		params["one_way"] = one_way.duplicate(true)
	if jump:
		params["jump"] = true
	return params


static func _ints(value: Variant) -> bool:
	return typeof(value) == TYPE_ARRAY and (value as Array).all(func(v: Variant) -> bool: return typeof(v) == TYPE_INT and v >= 0)


## The road reads the same from either end; its sub-elements tie it to one
## order.
func peg_symmetry() -> String:
	return PEGS_LINE if get_params().is_empty() else PEGS_FIXED


## Where peg `peg` stands on the road (the oasis is not on it), or -1.
func road_place(peg: int) -> int:
	if peg == oasis:
		return -1
	return peg - 1 if oasis >= 0 and peg > oasis else peg


## Whether `a` and `b` are neighbours on the road or linked by a tunnel (a
## one-way road counts in its own direction only).
func linked(a: int, b: int) -> bool:
	if a >= MAX_PEGS or b >= MAX_PEGS:
		return false
	var here: int = road_place(a)
	var there: int = road_place(b)
	var neighbours: bool = here >= 0 and there >= 0 and absi(here - there) == 1
	return neighbours or _largest[a * MAX_PEGS + b] > 0


## Whether a step from `a` to `b` is open to `disk` (bridges, one-way roads).
func _road_open(disk: int, a: int, b: int) -> bool:
	return a < MAX_PEGS and b < MAX_PEGS and disk <= _largest[a * MAX_PEGS + b]


## The stop a jump from `from` to `to` passes over, or -1.
func jump_over(from: int, to: int) -> int:
	var here: int = road_place(from)
	var there: int = road_place(to)
	if not jump or here < 0 or there < 0 or absi(here - there) != 2:
		return -1
	var middle: int = (here + there) / 2
	return middle + 1 if oasis >= 0 and middle >= oasis else middle


func is_disk_move_allowed(disk: int, from_peg: int, to_peg: int, _target_top: int) -> bool:
	return linked(from_peg, to_peg) and _road_open(disk, from_peg, to_peg)


func is_move_allowed_with(disk: int, from_peg: int, to_peg: int, target_top: int, facts: MoveFacts) -> bool:
	if to_peg == oasis:
		return from_peg == oasis_stop and facts.counts[oasis] == 0
	if from_peg == oasis:
		return to_peg == oasis_stop
	var over: int = jump_over(from_peg, to_peg)
	if over >= 0:
		return facts.tops[over] > disk
	return is_disk_move_allowed(disk, from_peg, to_peg, target_top)


func needs_facts() -> bool:
	return oasis >= 0 or jump


func supports_disk_move_check() -> bool:
	return not needs_facts()


## The oasis holds one disk at most.
func is_state_valid(state: PuzzleState) -> bool:
	return oasis < 0 or (oasis < state.get_peg_count() and oasis_stop < state.get_peg_count()
			and state.pegs[oasis].size() <= 1)


## A full oasis, a narrow bridge and a one-way road say so.
func get_violation_message(state: PuzzleState, move: Move) -> String:
	var disk: int = state.get_top_disk(move.from_peg)
	if move.to_peg == oasis and move.from_peg == oasis_stop:
		return "RULE_OASIS_FULL"
	if linked(move.from_peg, move.to_peg) and not _road_open(disk, move.from_peg, move.to_peg):
		for arrow: Array in one_way:
			if arrow[0] == move.to_peg and arrow[1] == move.from_peg:
				return "RULE_ONE_WAY"
		return "RULE_BRIDGE"
	return violation_message


## A one-way road lets disks go where they cannot come back from.
func can_dead_end() -> bool:
	return not one_way.is_empty()
