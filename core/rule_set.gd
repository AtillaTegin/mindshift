class_name RuleSet
extends RefCounted
## The active rules of a level. A move is legal when it is structurally valid
## (pegs exist, differ, source not empty) and every active rule allows it.
## New mechanics are added as RuleBase subclasses and registered in
## `create_rule()`; the Solver does not change.

var active_rules: Array[RuleBase] = []


func _init(p_rules: Array[RuleBase] = []) -> void:
	active_rules.assign(p_rules)


## RuleSet containing only the classic Hanoi rule.
static func classic() -> RuleSet:
	var rules: Array[RuleBase] = [ClassicHanoiRule.new()]
	return RuleSet.new(rules)


## Builds a RuleSet from the level JSON `rules` array.
## Returns null if `ids` is not an array or contains an unknown id.
static func from_ids(ids: Variant) -> RuleSet:
	if typeof(ids) != TYPE_ARRAY:
		return null
	var rules: Array[RuleBase] = []
	for id: Variant in ids:
		if typeof(id) != TYPE_STRING:
			return null
		var rule: RuleBase = create_rule(id)
		if rule == null:
			return null
		rules.append(rule)
	return RuleSet.new(rules)


## Rule registry: a fresh rule for a level JSON id, or null if the id is unknown.
static func create_rule(id: String) -> RuleBase:
	if id == ClassicHanoiRule.ID:
		return ClassicHanoiRule.new()
	return null


func get_rule_ids() -> Array[String]:
	var ids: Array[String] = []
	for rule: RuleBase in active_rules:
		ids.append(rule.get_id())
	return ids


func is_move_legal(state: PuzzleState, move: Move) -> bool:
	if state == null or move == null:
		return false
	var peg_count: int = state.pegs.size()
	if move.from_peg < 0 or move.from_peg >= peg_count:
		return false
	if move.to_peg < 0 or move.to_peg >= peg_count:
		return false
	if move.from_peg == move.to_peg or state.pegs[move.from_peg].is_empty():
		return false
	return _rules_allow(state, move)


## All legal moves, in a fixed order (by source peg, then target peg) so that
## search results are reproducible.
func get_legal_moves(state: PuzzleState) -> Array[Move]:
	var moves: Array[Move] = []
	var peg_count: int = state.pegs.size()
	for from_peg: int in peg_count:
		if state.pegs[from_peg].is_empty():
			continue
		for to_peg: int in peg_count:
			if to_peg == from_peg:
				continue
			var move: Move = Move.new(from_peg, to_peg)
			if _rules_allow(state, move):
				moves.append(move)
	return moves


## New state with `move` applied, or null if the move is illegal.
## `state` itself is never modified.
func apply_move(state: PuzzleState, move: Move) -> PuzzleState:
	if not is_move_legal(state, move):
		return null
	return apply_move_unchecked(state, move)


## Same as apply_move() without the legality check, for hot loops that only
## apply moves returned by get_legal_moves().
func apply_move_unchecked(state: PuzzleState, move: Move) -> PuzzleState:
	var next: PuzzleState = state.duplicate_state()
	next.pegs[move.to_peg].append(next.pegs[move.from_peg].pop_back())
	return next


func is_goal_state(state: PuzzleState, goal: PuzzleState) -> bool:
	return state != null and state.equals(goal)


## Structural check (at least one peg, disk sizes positive and unique) plus
## every active rule's own state check. Used to validate level start/goal states.
func is_state_valid(state: PuzzleState) -> bool:
	if state == null or state.pegs.is_empty():
		return false
	var seen: Dictionary[int, bool] = {}
	for peg: Array in state.pegs:
		for disk: Variant in peg:
			if typeof(disk) != TYPE_INT or disk <= 0 or seen.has(disk):
				return false
			seen[disk] = true
	for rule: RuleBase in active_rules:
		if not rule.is_state_valid(state):
			return false
	return true


func _rules_allow(state: PuzzleState, move: Move) -> bool:
	for rule: RuleBase in active_rules:
		if not rule.is_move_allowed(state, move):
			return false
	return true
