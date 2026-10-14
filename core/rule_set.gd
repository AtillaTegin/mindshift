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


## Builds a RuleSet from the level JSON `rules` array and the optional
## `rule_params` object ({ rule id: settings }). Returns null if `ids` is not an
## array, holds an unknown id, or the settings do not fit; the reason goes to
## `errors`.
static func from_ids(ids: Variant, params: Variant = {}, errors: Array[String] = []) -> RuleSet:
	if typeof(ids) != TYPE_ARRAY:
		errors.append("rules must be an array")
		return null
	if typeof(params) != TYPE_DICTIONARY:
		errors.append("rule_params must be an object")
		return null
	for key: Variant in params:
		if not key in ids:
			errors.append("rule_params has \"%s\", which is not in rules" % str(key))
			return null
	var rules: Array[RuleBase] = []
	for id: Variant in ids:
		if typeof(id) != TYPE_STRING:
			errors.append("rule ids must be strings")
			return null
		var rule: RuleBase = create_rule(id)
		if rule == null:
			errors.append("unknown rule \"%s\"" % id)
			return null
		var settings: Variant = params.get(id, {})
		var problem: String = rule.configure(settings) if typeof(settings) == TYPE_DICTIONARY \
				else "rule_params.%s must be an object" % id
		if not problem.is_empty():
			errors.append(problem)
			return null
		rules.append(rule)
	return RuleSet.new(rules)


## Rule registry: a fresh rule for a level JSON id, or null if the id is unknown.
static func create_rule(id: String) -> RuleBase:
	match id:
		ClassicHanoiRule.ID:
			return ClassicHanoiRule.new()
		AlternationRule.ID:
			return AlternationRule.new()
		AdjacentPegsRule.ID:
			return AdjacentPegsRule.new()
		CombinationRule.ID:
			return CombinationRule.new()
		ColorSwapRule.ID:
			return ColorSwapRule.new()
	return null


## Hands the level's disk colours to every rule (RuleBase.bind_disk_colours).
func bind_disk_colours(colours: Array[String]) -> void:
	for rule: RuleBase in active_rules:
		rule.bind_disk_colours(colours)


## The non-empty settings of the active rules, as written to level JSON.
func get_rule_params() -> Dictionary:
	var params: Dictionary = {}
	for rule: RuleBase in active_rules:
		if not rule.get_params().is_empty():
			params[rule.get_id()] = rule.get_params()
	return params


## Whether every active rule lets `disk` move now, `last_disk` having moved last.
func is_disk_movable(disk: int, last_disk: int) -> bool:
	for rule: RuleBase in active_rules:
		if not rule.is_disk_movable(disk, last_disk):
			return false
	return true


## Whether any active rule looks at the disk that moved last.
func uses_last_move() -> bool:
	for rule: RuleBase in active_rules:
		if rule.uses_last_move():
			return true
	return false


## What a search must tell apart: the position, plus the last moved disk when a
## rule depends on it.
func search_key(state: PuzzleState) -> String:
	return state.hash_key() + ("#%d" % state.last_moved_disk if uses_last_move() else "")


## Whether the top disk of `peg_index` may be picked up (false for an empty peg).
func can_pick_up(state: PuzzleState, peg_index: int) -> bool:
	var disk: int = state.get_top_disk(peg_index)
	return disk != -1 and is_disk_movable(disk, state.last_moved_disk)


## The disks a tap on `peg_index` picks up, bottom -> top: its top disk, or
## the group a rule moves together (RuleBase.disks_picked_up). Empty for an
## empty peg.
func picked_up_disks(state: PuzzleState, peg_index: int) -> Array[int]:
	var stack: Array = state.pegs[peg_index]
	var count: int = 1
	for rule: RuleBase in active_rules:
		count = maxi(count, rule.disks_picked_up(stack))
	var disks: Array[int] = []
	disks.assign(stack.slice(maxi(stack.size() - count, 0)))
	return disks


## Why the top disk of `peg_index` cannot be picked up: the violation_message
## of the first rule that holds it back, or "".
func get_pick_up_violation_message(state: PuzzleState, peg_index: int) -> String:
	var disk: int = state.get_top_disk(peg_index)
	for rule: RuleBase in active_rules:
		if disk != -1 and not rule.is_disk_movable(disk, state.last_moved_disk):
			return rule.violation_message
	return ""


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
## apply moves returned by get_legal_moves(). A rule may make a move carry a
## group of top disks (RuleBase.disks_moved); they keep their order.
func apply_move_unchecked(state: PuzzleState, move: Move) -> PuzzleState:
	var next: PuzzleState = state.duplicate_state()
	var count: int = 1
	for rule: RuleBase in active_rules:
		count = maxi(count, rule.disks_moved(state, move))
	var source: Array = next.pegs[move.from_peg]
	var group: Array = source.slice(source.size() - count)
	source.resize(source.size() - count)
	next.pegs[move.to_peg].append_array(group)
	next.last_moved_disk = group[-1]
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


## Why `move` is not allowed: the violation_message of the first active rule
## that refuses it, or "" if the move is legal or only structurally invalid
## (no such peg, same peg, empty source).
func get_violation_message(state: PuzzleState, move: Move) -> String:
	if state == null or move == null:
		return ""
	var peg_count: int = state.pegs.size()
	if move.from_peg < 0 or move.from_peg >= peg_count or move.to_peg < 0 or move.to_peg >= peg_count:
		return ""
	if move.from_peg == move.to_peg or state.pegs[move.from_peg].is_empty():
		return ""
	for rule: RuleBase in active_rules:
		if not rule.is_move_allowed(state, move):
			return rule.get_violation_message(state, move)
	return ""


func _rules_allow(state: PuzzleState, move: Move) -> bool:
	for rule: RuleBase in active_rules:
		if not rule.is_move_allowed(state, move):
			return false
	return true
