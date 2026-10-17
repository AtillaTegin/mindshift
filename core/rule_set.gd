class_name RuleSet
extends RefCounted
## The active rules of a level. A move is legal when it is structurally valid
## (pegs exist, differ, source not empty) and every active rule allows it.
## New mechanics are added as RuleBase subclasses and registered in
## `create_rule()`; the Solver does not change.
##
## Two linked disks (RuleBase.partner_of) only move together: a compound Move
## lifts both tops at once and puts each on its own, different target, each
## judged by every rule as if it moved alone with the other already lifted.

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
	var memories: int = 0
	var goals: int = 0
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
		memories += 1 if rule.uses_memory() else 0
		goals += 1 if rule.defines_goal() else 0
		rules.append(rule)
	if memories > 1:
		errors.append("only one rule may keep a memory")
		return null
	if goals > 1:
		errors.append("only one rule may set the goal")
		return null
	return RuleSet.new(rules)


## Every id create_rule() knows (a test keeps the two in step, and checks that
## each mode has its texts in ModeTexts; a sub-element's rule, e.g. the sealed
## box, belongs to its mode: ChapterPlan.SUB_RULES).
const RULE_IDS: Array[String] = ["classic_hanoi", "alternation", "adjacent_pegs", "color_swap", "peg_capacity",
		"foundation", "balance", "cyclic", "stripes", "chain", "mirror", "trail", "magnet", "sealed_box", "king", "river"]


## Rule registry: a fresh rule for a level JSON id, or null if the id is unknown.
static func create_rule(id: String) -> RuleBase:
	match id:
		ClassicHanoiRule.ID:
			return ClassicHanoiRule.new()
		AlternationRule.ID:
			return AlternationRule.new()
		AdjacentPegsRule.ID:
			return AdjacentPegsRule.new()
		ColorSwapRule.ID:
			return ColorSwapRule.new()
		PegCapacityRule.ID:
			return PegCapacityRule.new()
		FoundationRule.ID:
			return FoundationRule.new()
		BalanceRule.ID:
			return BalanceRule.new()
		CyclicRule.ID:
			return CyclicRule.new()
		StripesRule.ID:
			return StripesRule.new()
		ChainRule.ID:
			return ChainRule.new()
		MirrorRule.ID:
			return MirrorRule.new()
		TrailRule.ID:
			return TrailRule.new()
		MagnetRule.ID:
			return MagnetRule.new()
		SealedBoxRule.ID:
			return SealedBoxRule.new()
		KingRule.ID:
			return KingRule.new()
		RiverRule.ID:
			return RiverRule.new()
	return null


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


## is_disk_movable() knowing the whole position (`facts`).
func is_disk_movable_with(disk: int, facts: MoveFacts) -> bool:
	for rule: RuleBase in active_rules:
		if not rule.is_disk_movable_with(disk, facts):
			return false
	return true


## Whether any active rule looks at the disk that moved last.
func uses_last_move() -> bool:
	for rule: RuleBase in active_rules:
		if rule.uses_last_move():
			return true
	return false


## Whether any active rule needs MoveFacts beyond the last disk.
func needs_facts() -> bool:
	for rule: RuleBase in active_rules:
		if rule.needs_facts():
			return true
	return false


## The one active rule that keeps a memory (RuleBase.uses_memory), or null.
func memory_rule() -> RuleBase:
	for rule: RuleBase in active_rules:
		if rule.uses_memory():
			return rule
	return null


func uses_memory() -> bool:
	return memory_rule() != null


## The memory of `state`: its own, or the rules' start memory while no move has
## set one (PuzzleState.memory -1); always 0 without a memory rule.
func memory_of(state: PuzzleState) -> int:
	var rule: RuleBase = memory_rule()
	if rule == null:
		return 0
	return state.memory if state.memory >= 0 else rule.start_memory(state)


## `state` with its memory resolved (a copy), e.g. a level start.
func prepared(state: PuzzleState) -> PuzzleState:
	var copy: PuzzleState = state.duplicate_state()
	if uses_memory():
		copy.memory = memory_of(state)
	return copy


## The disk linked to `disk` by some rule, or 0.
func partner_of(disk: int) -> int:
	for rule: RuleBase in active_rules:
		var partner: int = rule.partner_of(disk)
		if partner != 0:
			return partner
	return 0


## Whether any rule links two disks.
func has_partners(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for disk: int in peg:
			if partner_of(disk) != 0:
				return true
	return false


## The peg groups of a rule that splits the board (RuleBase.peg_groups), or [].
func peg_groups(peg_count: int) -> Array[Array]:
	for rule: RuleBase in active_rules:
		var groups: Array[Array] = rule.peg_groups(peg_count)
		if not groups.is_empty():
			return groups
	return [] as Array[Array]


## Whether a rule makes moves echo (RuleBase.echo_of).
func has_echo() -> bool:
	for rule: RuleBase in active_rules:
		if rule.echoes():
			return true
	return false


## Whether a rule can leave the goal out of reach for good (RuleBase.can_dead_end),
## or a one-way rule meets another rule that limits moves (RuleBase.moves_one_way).
func can_dead_end() -> bool:
	var one_way: bool = false
	var others: int = 0
	for rule: RuleBase in active_rules:
		if rule.can_dead_end():
			return true
		one_way = one_way or rule.moves_one_way()
		others += 1 if rule.get_id() != ClassicHanoiRule.ID and not rule.moves_one_way() else 0
	return one_way and others > 0


## The move that echoes `move` made from `state` (RuleBase.echo_of), or null
## when no rule echoes or the echo is not possible on the position after it.
func echo_for(state: PuzzleState, move: Move) -> Move:
	if move.is_compound():
		return null
	var after: PuzzleState = state.duplicate_state()
	after.pegs[move.to_peg].append(after.pegs[move.from_peg].pop_back())
	for rule: RuleBase in active_rules:
		var echo: Move = rule.echo_of(after, move)
		if echo != null:
			return echo if _echo_possible(after, echo) else null
	return null


## The echo's own check: a top disk onto an empty peg or a larger top.
static func _echo_possible(state: PuzzleState, echo: Move) -> bool:
	var disk: int = state.get_top_disk(echo.from_peg)
	var top: int = state.get_top_disk(echo.to_peg)
	return echo.from_peg != echo.to_peg and disk != -1 and (top == -1 or top > disk)


## These rules without the ones that split the board, for solving one group.
func without_groups(peg_count: int) -> RuleSet:
	var rules: Array[RuleBase] = []
	for rule: RuleBase in active_rules:
		if rule.peg_groups(peg_count).is_empty():
			rules.append(rule)
	return RuleSet.new(rules)


## What a search must tell apart: the position, plus the last moved disk and
## the memory when a rule depends on them.
func search_key(state: PuzzleState) -> String:
	var key: String = state.hash_key()
	if uses_last_move():
		key += "#%d" % state.last_moved_disk
	if uses_memory():
		key += "~%d" % memory_of(state)
	return key


## Whether the top disk of `peg_index` may be picked up (false for an empty
## peg). A linked disk only when its partner is on top of another peg too.
func can_pick_up(state: PuzzleState, peg_index: int) -> bool:
	return state.get_top_disk(peg_index) != -1 and get_pick_up_violation_message(state, peg_index).is_empty()


## Why the top disk of `peg_index` cannot be picked up: the violation_message
## of the first rule that holds it back, or "".
func get_pick_up_violation_message(state: PuzzleState, peg_index: int) -> String:
	var disk: int = state.get_top_disk(peg_index)
	if disk == -1:
		return ""
	var facts: MoveFacts = MoveFacts.of(state, self)
	for rule: RuleBase in active_rules:
		if not rule.is_disk_movable_with(disk, facts):
			return rule.pick_up_message(disk, facts)
		var partner: int = rule.partner_of(disk)
		if partner != 0 and (not facts.is_top(partner) or facts.peg_of[partner] == peg_index):
			return rule.violation_message
	return ""


func get_rule_ids() -> Array[String]:
	var ids: Array[String] = []
	for rule: RuleBase in active_rules:
		ids.append(rule.get_id())
	return ids


func is_move_legal(state: PuzzleState, move: Move) -> bool:
	if state != null and move != null and move.from_peg == move.to_peg:
		return _special_rule(state, move) != null
	if state == null or move == null or not _is_structural(state, move):
		return false
	return _refusing_rule(state, move, MoveFacts.of(state, self)) == null


## All legal moves, in a fixed order (by source peg, then target peg; compound
## moves by their first disk's pegs, then the second's) so that search results
## are reproducible.
func get_legal_moves(state: PuzzleState) -> Array[Move]:
	var moves: Array[Move] = []
	var facts: MoveFacts = MoveFacts.of(state, self)
	var peg_count: int = state.pegs.size()
	for from_peg: int in peg_count:
		var disk: int = state.get_top_disk(from_peg)
		if disk == -1:
			continue
		var partner: int = partner_of(disk)
		if partner != 0:
			# Each linked pair once, from its smaller disk; both must be on top.
			if partner < disk or not facts.is_top(partner):
				continue
			var partner_peg: int = facts.peg_of[partner]
			for to_peg: int in peg_count:
				for to_peg_2: int in peg_count:
					var move: Move = Move.new(from_peg, to_peg, partner_peg, to_peg_2)
					if _is_structural(state, move) and _refusing_rule(state, move, facts) == null:
						moves.append(move)
			continue
		for to_peg: int in peg_count:
			if to_peg == from_peg:
				continue
			var move: Move = Move.new(from_peg, to_peg)
			if _refusing_rule(state, move, facts) == null:
				moves.append(move)
	for rule: RuleBase in active_rules:
		moves.append_array(rule.special_moves(facts))
	return moves


## Whether a rule has moves of its own piece (RuleBase.special_moves): the
## stone on a pan, written Move.new(peg, peg).
func has_special_moves() -> bool:
	for rule: RuleBase in active_rules:
		if rule.has_special_moves():
			return true
	return false


## The rule whose special move `move` is legal now, or null.
func _special_rule(state: PuzzleState, move: Move) -> RuleBase:
	if move.from_peg != move.to_peg or move.is_compound():
		return null
	var facts: MoveFacts = MoveFacts.of(state, self)
	for rule: RuleBase in active_rules:
		for special: Move in rule.special_moves(facts):
			if special.equals(move):
				return rule
	return null


## New state with `move` applied, or null if the move is illegal.
## `state` itself is never modified.
func apply_move(state: PuzzleState, move: Move) -> PuzzleState:
	if not is_move_legal(state, move):
		return null
	return apply_move_unchecked(state, move)


## Same as apply_move() without the legality check, for hot loops that only
## apply moves returned by get_legal_moves(). Updates the last moved disk (the
## first of a compound move) and the rules' memory.
func apply_move_unchecked(state: PuzzleState, move: Move) -> PuzzleState:
	var next: PuzzleState = state.duplicate_state()
	if move.from_peg == move.to_peg:
		# A rule's own piece moved (RuleBase.special_moves): only its memory changes.
		var special: RuleBase = _special_rule(state, move)
		if special != null:
			next.memory = special.special_memory_after(MoveFacts.of(state, self), move)
		return next
	var memory: RuleBase = memory_rule()
	var facts: MoveFacts = MoveFacts.of(state, self) if memory != null else null
	var disk: int = next.pegs[move.from_peg].pop_back()
	var disk_2: int = next.pegs[move.from_peg_2].pop_back() if move.is_compound() else 0
	next.pegs[move.to_peg].append(disk)
	if move.is_compound():
		next.pegs[move.to_peg_2].append(disk_2)
	next.last_moved_disk = disk
	if memory != null:
		next.memory = memory.memory_after(facts, disk, move.from_peg, move.to_peg)
		if move.is_compound():
			facts.memory = next.memory
			next.memory = memory.memory_after(facts, disk_2, move.from_peg_2, move.to_peg_2)
	# An echoing rule's follow-up move, when it is possible (RuleBase.echo_of).
	if not move.is_compound():
		for rule: RuleBase in active_rules:
			if rule.echoes():
				var echo: Move = rule.echo_of(next, move)
				if echo != null and _echo_possible(next, echo):
					next.pegs[echo.to_peg].append(next.pegs[echo.from_peg].pop_back())
				break
	return next


## Whether `state` is the goal: the condition of a rule that sets the goal
## (RuleBase.defines_goal), otherwise the exact position `goal`.
func is_goal_state(state: PuzzleState, goal: PuzzleState) -> bool:
	if state == null:
		return false
	var rule: RuleBase = goal_rule()
	if rule != null:
		return rule.is_goal_with(MoveFacts.of(state, self))
	return state.equals(goal)


## The one active rule that sets the goal (RuleBase.defines_goal), or null.
func goal_rule() -> RuleBase:
	for rule: RuleBase in active_rules:
		if rule.defines_goal():
			return rule
	return null


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
	if state == null or move == null or not _is_structural(state, move):
		return ""
	var facts: MoveFacts = MoveFacts.of(state, self)
	var rule: RuleBase = _refusing_rule(state, move, facts)
	if rule == null:
		return ""
	# The part of a compound move the rule refuses, so it names the right reason.
	var part: Move = move
	if move.is_compound() and _part_allowed(rule, state, facts, move.from_peg, move.to_peg, _top_after_lift(state, move, move.to_peg)):
		part = Move.new(move.from_peg_2, move.to_peg_2)
	return rule.get_violation_message(state, part)


## Pegs in range and different, sources not empty; a compound move takes two
## linked top disks from two pegs to two different pegs, each moving.
func _is_structural(state: PuzzleState, move: Move) -> bool:
	var peg_count: int = state.pegs.size()
	for peg: int in [move.from_peg, move.to_peg]:
		if peg < 0 or peg >= peg_count:
			return false
	if move.from_peg == move.to_peg or state.pegs[move.from_peg].is_empty():
		return false
	if not move.is_compound():
		return true
	for peg: int in [move.from_peg_2, move.to_peg_2]:
		if peg < 0 or peg >= peg_count:
			return false
	if move.from_peg_2 == move.to_peg_2 or move.from_peg_2 == move.from_peg or move.to_peg_2 == move.to_peg:
		return false
	if state.pegs[move.from_peg_2].is_empty():
		return false
	return partner_of(state.get_top_disk(move.from_peg)) == state.get_top_disk(move.from_peg_2)


## The first rule that refuses `move` (structurally valid), or null. A linked
## disk moving alone is refused by the rule that links it.
func _refusing_rule(state: PuzzleState, move: Move, facts: MoveFacts) -> RuleBase:
	var disk: int = state.get_top_disk(move.from_peg)
	if not move.is_compound() and partner_of(disk) != 0:
		for rule: RuleBase in active_rules:
			if rule.partner_of(disk) != 0:
				return rule
	for rule: RuleBase in active_rules:
		if not _part_allowed(rule, state, facts, move.from_peg, move.to_peg, _top_after_lift(state, move, move.to_peg)):
			return rule
		if move.is_compound() and not _part_allowed(rule, state, facts, move.from_peg_2, move.to_peg_2,
				_top_after_lift(state, move, move.to_peg_2)):
			return rule
	return null


## Whether `rule` lets the top disk of `from_peg` go to `to_peg`, whose top is
## then `target_top`. Rules that judge locally get the facts; others the state.
func _part_allowed(rule: RuleBase, state: PuzzleState, facts: MoveFacts, from_peg: int, to_peg: int,
		target_top: int) -> bool:
	var disk: int = state.get_top_disk(from_peg)
	if rule.supports_disk_move_check() or rule.needs_facts() or rule.uses_memory():
		return rule.is_move_allowed_with(disk, from_peg, to_peg, target_top, facts)
	return rule.is_move_allowed(state, Move.new(from_peg, to_peg))


## The top disk of `peg` once the moving disks of `move` are lifted (-1: empty).
func _top_after_lift(state: PuzzleState, move: Move, peg: int) -> int:
	var stack: Array = state.pegs[peg]
	var lifted: int = (1 if peg == move.from_peg else 0) + (1 if move.is_compound() and peg == move.from_peg_2 else 0)
	return stack[stack.size() - 1 - lifted] if stack.size() > lifted else -1
