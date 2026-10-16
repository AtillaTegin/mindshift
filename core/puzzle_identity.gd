class_name PuzzleIdentity
extends RefCounted
## The similarity check (current decisions 2026-10-16, E): one canonical form
## per puzzle, so two levels that differ only in the order of their pegs (a
## mirror image included) or in swapped colours never both ship, the trap of
## sort puzzles that repeat one puzzle in new colours. Each rule says which
## peg orders keep its puzzles the same (RuleBase.peg_symmetry), what its
## settings say about each peg (peg_mark) and which disk relabelings keep them
## (disk_swaps); the key is the smallest description over all of those.
## Karakuri boxes and other looks do not count: a boxed board is the same
## puzzle as the open one.


## The canonical key of the puzzle `start` -> `goal` under `rule_ids` with
## `params`.
static func key(start: PuzzleState, goal: PuzzleState, rule_ids: Array, params: Dictionary) -> String:
	var ids: Array[String] = []
	ids.assign(rule_ids)
	ids.sort()
	var rules: RuleSet = RuleSet.from_ids(ids, params)
	if rules == null:
		return "%s => %s %s %s" % [start.hash_key(), goal.hash_key(), str(ids), JSON.stringify(params)]
	var settings: Dictionary = {}
	for rule: RuleBase in rules.active_rules:
		settings[rule.get_id()] = rule.params_without_pegs()
	var peg_count: int = start.get_peg_count()
	var orders: Array = orders_of(rules, peg_count)
	var disks: Array = []
	for peg: Array in start.pegs:
		disks.append_array(peg)
	var maps: Array[Dictionary] = [{}]
	for rule: RuleBase in rules.active_rules:
		maps.append_array(rule.disk_swaps(disks))
	var best: String = ""
	for map: Dictionary in maps:
		var columns: Array[String] = []
		for peg_index: int in peg_count:
			var marks: Array = []
			for rule: RuleBase in rules.active_rules:
				marks.append(rule.peg_mark(peg_index))
			columns.append(JSON.stringify([_relabelled(start.pegs[peg_index], map), _relabelled(goal.pegs[peg_index], map), marks]))
		var candidates: Array[String] = []
		if orders.is_empty():
			var sorted: Array[String] = columns.duplicate()
			sorted.sort()
			candidates.append("|".join(sorted))
		for order: Array in orders:
			candidates.append("|".join(order.map(func(peg_index: int) -> String: return columns[peg_index])))
		for candidate: String in candidates:
			if best.is_empty() or candidate < best:
				best = candidate
	return "%s %s %s" % [str(ids), JSON.stringify(settings), best]


## The peg orders every rule of `rules` allows on `peg_count` pegs, each a
## list (new place -> old peg); empty when any order goes.
static func orders_of(rules: RuleSet, peg_count: int) -> Array:
	var allowed: Array = []
	var any: bool = true
	for rule: RuleBase in rules.active_rules:
		var kind: String = rule.peg_symmetry()
		if kind == RuleBase.PEGS_ANY:
			continue
		var these: Array = _orders(kind, peg_count)
		allowed = these if any else allowed.filter(func(order: Array) -> bool: return these.has(order))
		any = false
	return allowed


static func _orders(kind: String, peg_count: int) -> Array:
	var identity: Array = range(peg_count)
	match kind:
		RuleBase.PEGS_LINE:
			var reversed: Array = identity.duplicate()
			reversed.reverse()
			return [identity, reversed]
		RuleBase.PEGS_CIRCLE:
			var turns: Array = []
			for shift: int in peg_count:
				turns.append(identity.map(func(peg_index: int) -> int: return (peg_index + shift) % peg_count))
			return turns
		RuleBase.PEGS_PAIRS:
			return _permutations(identity).filter(func(order: Array) -> bool:
				for i: int in range(0, peg_count - 1, 2):
					if order[i] / 2 != order[i + 1] / 2:
						return false
				return true)
	return [identity]


## Every order of `items`.
static func _permutations(items: Array) -> Array:
	if items.size() <= 1:
		return [items.duplicate()]
	var found: Array = []
	for i: int in items.size():
		var rest: Array = items.duplicate()
		rest.remove_at(i)
		for tail: Array in _permutations(rest):
			found.append([items[i]] + tail)
	return found


static func _relabelled(stack: Array, map: Dictionary) -> Array:
	return stack if map.is_empty() else stack.map(func(disk: int) -> int: return map.get(disk, disk))
