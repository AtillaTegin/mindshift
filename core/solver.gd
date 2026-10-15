class_name Solver
extends RefCounted
## Finds a shortest move sequence from a start position to a goal position.
##
## Both strategies below are breadth-first, so the path found is always a
## shortest one; they differ only in speed:
## - Packed search: if the active rules keep every peg sorted and each rule can
##   judge a move from the moving disk and the target's top disk alone
##   (RuleBase.keeps_stacks_sorted / supports_disk_move_check), a position is just
##   "which peg each disk is on" and fits in one int. The search runs from both
##   ends and meets in the middle. This is what makes 4-5 peg / 8-10 disk levels
##   and in-game hints fast enough.
## - Packed search with history: when a rule also looks at the disk that moved
##   last (RuleBase.uses_last_move), keeps a memory (uses_memory), judges with
##   MoveFacts (needs_facts) or links two disks (partner_of), the packed code
##   also carries the last disk and the memory, every searched position fills
##   a MoveFacts, linked disks make compound moves, and the search runs one way
##   only (a predecessor's own last disk or memory is not known going
##   backwards).
## - Split search: a rule that splits the board into peg groups that never
##   exchange disks (RuleBase.peg_groups) gets every group solved on its own;
##   the paths are joined, so the total is the sum of the shortest ones.
## - Generic search: standard BFS over PuzzleState keyed by RuleSet.search_key().
##   Works for any RuleSet.
## The Solver never refers to concrete rule classes; new rules only need to
## implement RuleBase.

const DEFAULT_MAX_STATES: int = 200000
## Packed codes go up to peg_count ^ disk_count; larger puzzles use the generic search.
const MAX_PACKED_CODE: int = 1 << 62


## Returns:
##   solvable: bool       - a path was found
##   min_moves: int       - length of that path, -1 when not solvable
##   path: Array[Move]    - the moves, start -> goal (empty when start equals goal)
##   states_visited: int  - distinct positions the search stored
##   limit_reached: bool  - the search stopped at max_states before finding an answer
##   strategy: String     - "packed", "packed_history", "split", "generic", or "none" when no search was needed
## Neither `start` nor `goal` is modified.
static func solve(start: PuzzleState, goal: PuzzleState, rules: RuleSet,
		max_states: int = DEFAULT_MAX_STATES) -> Dictionary:
	if start == null or goal == null or rules == null:
		return _result(false, [], 0, false)
	if rules.is_goal_state(start, goal):
		return _result(true, [], 1, false)
	if not _same_pegs_and_disks(start, goal):
		# Moves never add or remove pegs or disks.
		return _result(false, [], 1, false)
	var result: Dictionary
	var groups: Array[Array] = rules.peg_groups(start.pegs.size())
	if not groups.is_empty():
		result = _solve_split(start, goal, rules, groups, max_states)
		result["strategy"] = "split"
	elif _can_pack(start, goal, rules) and (rules.uses_last_move() or rules.uses_memory() or rules.needs_facts()
			or rules.has_partners(start)):
		result = _solve_packed_history(start, goal, rules, max_states)
		result["strategy"] = "packed_history"
	elif _can_pack(start, goal, rules):
		result = _solve_packed(start, goal, rules, max_states)
		result["strategy"] = "packed"
	else:
		result = _solve_generic(start, goal, rules, max_states)
		result["strategy"] = "generic"
	return result


## Every peg group solved on its own (with the rules that do not split the
## board), the paths joined group after group.
static func _solve_split(start: PuzzleState, goal: PuzzleState, rules: RuleSet, groups: Array[Array],
		max_states: int) -> Dictionary:
	var group_rules: RuleSet = rules.without_groups(start.pegs.size())
	var path: Array[Move] = []
	var visited: int = 0
	for group: Array in groups:
		var part_start: PuzzleState = PuzzleState.new(group.map(func(peg: int) -> Array: return start.pegs[peg]))
		var part_goal: PuzzleState = PuzzleState.new(group.map(func(peg: int) -> Array: return goal.pegs[peg]))
		var part: Dictionary = solve(part_start, part_goal, group_rules, max_states)
		visited += part["states_visited"]
		if not part["solvable"]:
			return _result(false, [], visited, part["limit_reached"])
		for move: Move in part["path"]:
			path.append(Move.new(group[move.from_peg], group[move.to_peg]))
	return _result(true, path, visited, false)


static func _solve_generic(start: PuzzleState, goal: PuzzleState, rules: RuleSet,
		max_states: int) -> Dictionary:
	var start_key: String = rules.search_key(start)
	# key -> [previous key, move from previous]; the start maps to [].
	var parents: Dictionary[String, Array] = {start_key: []}
	var queue: Array[PuzzleState] = [start]
	var queue_keys: PackedStringArray = PackedStringArray([start_key])
	var head: int = 0
	while head < queue.size():
		var state: PuzzleState = queue[head]
		var key: String = queue_keys[head]
		queue[head] = null
		head += 1
		for move: Move in rules.get_legal_moves(state):
			var next: PuzzleState = rules.apply_move_unchecked(state, move)
			var next_key: String = rules.search_key(next)
			if parents.has(next_key):
				continue
			parents[next_key] = [key, move]
			if rules.is_goal_state(next, goal):
				return _result(true, _generic_path(parents, next_key), parents.size(), false)
			if parents.size() >= max_states:
				return _result(false, [], parents.size(), true)
			queue.append(next)
			queue_keys.append(next_key)
	return _result(false, [], parents.size(), false)


static func _generic_path(parents: Dictionary[String, Array], end_key: String) -> Array[Move]:
	var path: Array[Move] = []
	var key: String = end_key
	while not parents[key].is_empty():
		var entry: Array = parents[key]
		path.append(entry[1])
		key = entry[0]
	path.reverse()
	return path


## Bidirectional BFS over packed positions. A position is encoded as
## sum(peg_of(disk) * peg_count ^ rank(disk)), rank 0 being the smallest disk;
## because every peg is sorted, that fully determines the position.
## Each round expands one whole layer of the smaller frontier. The first
## position discovered by both sides closes a shortest path: before that layer
## no position was within reach of both sides, so no shorter path exists.
static func _solve_packed(start: PuzzleState, goal: PuzzleState, rules: RuleSet,
		max_states: int) -> Dictionary:
	var peg_count: int = start.pegs.size()
	var sizes: Array[int] = _sorted_disks(start)
	var disk_count: int = sizes.size()
	var rank_of: Dictionary[int, int] = {}
	var powers: PackedInt64Array = PackedInt64Array()
	var power: int = 1
	for rank: int in disk_count:
		rank_of[sizes[rank]] = rank
		powers.append(power)
		power *= peg_count
	var rule_list: Array[RuleBase] = rules.active_rules
	var start_code: int = _encode(start, rank_of, powers)
	var goal_code: int = _encode(goal, rank_of, powers)

	# forward: code -> previous code (start -> -1)
	# backward: code -> next code towards the goal (goal -> -1)
	var forward: Dictionary[int, int] = {start_code: -1}
	var backward: Dictionary[int, int] = {goal_code: -1}
	var forward_frontier: PackedInt64Array = PackedInt64Array([start_code])
	var backward_frontier: PackedInt64Array = PackedInt64Array([goal_code])
	# Rank of the top disk and of the disk under it on each peg (-1 = none).
	var tops: PackedInt32Array = PackedInt32Array()
	var seconds: PackedInt32Array = PackedInt32Array()
	tops.resize(peg_count)
	seconds.resize(peg_count)

	while not forward_frontier.is_empty() and not backward_frontier.is_empty():
		var go_forward: bool = forward_frontier.size() <= backward_frontier.size()
		var frontier: PackedInt64Array = forward_frontier if go_forward else backward_frontier
		var seen: Dictionary[int, int] = forward if go_forward else backward
		var other: Dictionary[int, int] = backward if go_forward else forward
		var next_frontier: PackedInt64Array = PackedInt64Array()
		for code: int in frontier:
			tops.fill(-1)
			seconds.fill(-1)
			var rest: int = code
			for rank: int in disk_count:
				var peg: int = rest % peg_count
				rest /= peg_count
				if tops[peg] == -1:
					tops[peg] = rank
				elif seconds[peg] == -1:
					seconds[peg] = rank
			# The top disk of peg `a` goes to peg `b`.
			for a: int in peg_count:
				var rank_a: int = tops[a]
				if rank_a == -1:
					continue
				var disk: int = sizes[rank_a]
				for b: int in peg_count:
					if b == a:
						continue
					var rank_b: int = tops[b]
					var allowed: bool = true
					if go_forward:
						# Successor: the move a -> b is made from this position.
						var target_top: int = -1 if rank_b == -1 else sizes[rank_b]
						for rule: RuleBase in rule_list:
							if not rule.is_disk_move_allowed(disk, a, b, target_top):
								allowed = false
								break
					else:
						# Predecessor: the disk sat on top of `b` and the move b -> a
						# brought it here. On a sorted peg it must be smaller than b's top.
						if rank_b != -1 and rank_b < rank_a:
							continue
						var under: int = seconds[a]
						var target_top: int = -1 if under == -1 else sizes[under]
						for rule: RuleBase in rule_list:
							if not rule.is_disk_move_allowed(disk, b, a, target_top):
								allowed = false
								break
					if not allowed:
						continue
					var next: int = code + (b - a) * powers[rank_a]
					if seen.has(next):
						continue
					seen[next] = code
					if other.has(next):
						var path: Array[Move] = _packed_path(forward, backward, next, peg_count, powers)
						return _result(true, path, forward.size() + backward.size() - 1, false)
					if forward.size() + backward.size() >= max_states:
						return _result(false, [], forward.size() + backward.size(), true)
					next_frontier.append(next)
		if go_forward:
			forward_frontier = next_frontier
		else:
			backward_frontier = next_frontier
	return _result(false, [], forward.size() + backward.size(), false)


## One-way BFS over packed positions plus the rank of the disk that moved last
## and the rules' memory: key = (position * (disk_count + 1) + last rank + 1)
## * memory states + memory (last rank + 1 = 0 means none; the last disk is
## left out, as if always none, when no rule looks at it). Every expanded
## position fills one MoveFacts and every move goes through
## RuleBase.is_move_allowed_with(). A linked pair (RuleBase.partner_of) moves
## only as one compound move: both on top of different pegs, each to its own
## different target. The first time the goal position is reached, with any
## last disk and memory, the path is a shortest one.
static func _solve_packed_history(start: PuzzleState, goal: PuzzleState, rules: RuleSet,
		max_states: int) -> Dictionary:
	var peg_count: int = start.pegs.size()
	var sizes: Array[int] = _sorted_disks(start)
	var disk_count: int = sizes.size()
	var rank_of: Dictionary[int, int] = {}
	var powers: PackedInt64Array = PackedInt64Array()
	var power: int = 1
	for rank: int in disk_count:
		rank_of[sizes[rank]] = rank
		powers.append(power)
		power *= peg_count
	# Rank of each disk's partner, -1 for a free disk.
	var partners: PackedInt32Array = PackedInt32Array()
	for rank: int in disk_count:
		var partner: int = rules.partner_of(sizes[rank])
		partners.append(rank_of[partner] if rank_of.has(partner) else -1)
	# The last disk only splits positions when a rule looks at it.
	var lasts: int = disk_count + 1 if rules.uses_last_move() else 1
	var memory_rule: RuleBase = rules.memory_rule()
	var memories: int = memory_rule.memory_states(peg_count, disk_count) if memory_rule != null else 1
	var rule_list: Array[RuleBase] = rules.active_rules
	var goal_code: int = _encode(goal, rank_of, powers)
	var start_last: int = rank_of[start.last_moved_disk] + 1 if lasts > 1 and rank_of.has(start.last_moved_disk) else 0
	var start_key: int = (_encode(start, rank_of, powers) * lasts + start_last) * memories + rules.memory_of(start)
	# key -> previous key (start -> -1)
	var parents: Dictionary[int, int] = {start_key: -1}
	var frontier: PackedInt64Array = PackedInt64Array([start_key])
	var facts: MoveFacts = MoveFacts.new()
	facts.reset(peg_count, sizes[-1])
	# Counts, sums and disk pegs only when a rule reads them or disks are linked;
	# otherwise just the tops (as fast as the history search ever was).
	var full_facts: bool = rules.needs_facts() or rules.has_partners(start)
	# Rules that judge from the disk, the pegs, the target top and the last disk
	# are asked directly (is_disk_move_allowed_after); the others get the facts.
	var plain_rules: Array[RuleBase] = []
	var fact_rules: Array[RuleBase] = []
	for rule: RuleBase in rule_list:
		if rule.needs_facts() or rule.uses_memory():
			fact_rules.append(rule)
		else:
			plain_rules.append(rule)
	# Rank of each peg's top disk (-1 = empty); with full facts also the disk
	# under it (for compound moves).
	var top_ranks: PackedInt32Array = PackedInt32Array()
	top_ranks.resize(peg_count)
	var seconds: PackedInt32Array = PackedInt32Array()
	seconds.resize(peg_count)
	var head: int = 0
	while head < frontier.size():
		var key: int = frontier[head]
		head += 1
		var memory: int = key % memories
		var code: int = key / memories / lasts
		var last_rank: int = key / memories % lasts - 1
		top_ranks.fill(-1)
		if full_facts:
			facts.reset(peg_count, sizes[-1])
			seconds.fill(-1)
			# Largest first, so every peg is filled bottom to top.
			for rank: int in range(disk_count - 1, -1, -1):
				var peg: int = (code / powers[rank]) % peg_count
				seconds[peg] = facts.tops[peg]
				facts.add(sizes[rank], peg)
				top_ranks[peg] = rank
		else:
			var rest: int = code
			for rank: int in disk_count:
				var peg: int = rest % peg_count
				rest /= peg_count
				if top_ranks[peg] == -1:
					top_ranks[peg] = rank
		var last_disk: int = sizes[last_rank] if last_rank >= 0 else 0
		facts.last_disk = last_disk
		facts.memory = memory
		for a: int in peg_count:
			var rank_a: int = top_ranks[a]
			if rank_a == -1:
				continue
			var disk: int = sizes[rank_a]
			var rank_p: int = partners[rank_a]
			if rank_p == -1:
				for b: int in peg_count:
					if b == a:
						continue
					var target_top: int = -1 if top_ranks[b] == -1 else sizes[top_ranks[b]]
					var allowed: bool = true
					for rule: RuleBase in plain_rules:
						if not rule.is_disk_move_allowed_after(disk, a, b, target_top, last_disk):
							allowed = false
							break
					if allowed:
						for rule: RuleBase in fact_rules:
							if not rule.is_move_allowed_with(disk, a, b, target_top, facts):
								allowed = false
								break
					if not allowed:
						continue
					var next_code: int = code + (b - a) * powers[rank_a]
					var next_memory: int = memory_rule.memory_after(facts, disk, a, b) if memory_rule != null else 0
					var next_key: int = (next_code * lasts + (rank_a + 1 if lasts > 1 else 0)) * memories + next_memory
					if parents.has(next_key):
						continue
					parents[next_key] = key
					if next_code == goal_code:
						return _result(true, _history_path(parents, next_key, memories * lasts, peg_count, powers),
								parents.size(), false)
					if parents.size() >= max_states:
						return _result(false, [], parents.size(), true)
					frontier.append(next_key)
				continue
			# A linked pair, taken once from its smaller disk; both on top.
			var partner: int = sizes[rank_p]
			if rank_p < rank_a or not facts.is_top(partner):
				continue
			var c: int = facts.peg_of[partner]
			for b: int in peg_count:
				if b == a:
					continue
				var top_b: int = seconds[c] if b == c else facts.tops[b]
				if not _allowed(rule_list, disk, a, b, top_b, facts):
					continue
				for d: int in peg_count:
					if d == c or d == b:
						continue
					var top_d: int = seconds[a] if d == a else facts.tops[d]
					if not _allowed(rule_list, partner, c, d, top_d, facts):
						continue
					var next_code: int = code + (b - a) * powers[rank_a] + (d - c) * powers[rank_p]
					var next_memory: int = 0
					if memory_rule != null:
						facts.memory = memory_rule.memory_after(facts, disk, a, b)
						next_memory = memory_rule.memory_after(facts, partner, c, d)
						facts.memory = memory
					var next_key: int = (next_code * lasts + (rank_a + 1 if lasts > 1 else 0)) * memories + next_memory
					if parents.has(next_key):
						continue
					parents[next_key] = key
					if next_code == goal_code:
						return _result(true, _history_path(parents, next_key, memories * lasts, peg_count, powers),
								parents.size(), false)
					if parents.size() >= max_states:
						return _result(false, [], parents.size(), true)
					frontier.append(next_key)
	return _result(false, [], parents.size(), false)


## Whether every rule lets `disk` go from `from_peg` to `to_peg` (top `target_top`).
static func _allowed(rule_list: Array[RuleBase], disk: int, from_peg: int, to_peg: int, target_top: int,
		facts: MoveFacts) -> bool:
	for rule: RuleBase in rule_list:
		if not rule.is_move_allowed_with(disk, from_peg, to_peg, target_top, facts):
			return false
	return true


## The moves back from `last_key` to the start of a history search (`divisor`
## turns a key into its packed position).
static func _history_path(parents: Dictionary[int, int], last_key: int, divisor: int, peg_count: int,
		powers: PackedInt64Array) -> Array[Move]:
	var path: Array[Move] = []
	var walk: int = last_key
	while parents[walk] != -1:
		path.append(_packed_move(parents[walk] / divisor, walk / divisor, peg_count, powers))
		walk = parents[walk]
	path.reverse()
	return path


static func _encode(state: PuzzleState, rank_of: Dictionary[int, int], powers: PackedInt64Array) -> int:
	var code: int = 0
	for peg_index: int in state.pegs.size():
		for disk: int in state.pegs[peg_index]:
			code += peg_index * powers[rank_of[disk]]
	return code


static func _packed_path(forward: Dictionary[int, int], backward: Dictionary[int, int],
		meet: int, peg_count: int, powers: PackedInt64Array) -> Array[Move]:
	var path: Array[Move] = []
	var code: int = meet
	while forward[code] != -1:
		path.append(_packed_move(forward[code], code, peg_count, powers))
		code = forward[code]
	path.reverse()
	code = meet
	while backward[code] != -1:
		path.append(_packed_move(code, backward[code], peg_count, powers))
		code = backward[code]
	return path


## The move that turns position `before` into `after`: one disk changed peg,
## or two for a compound move (the smaller disk first).
static func _packed_move(before: int, after: int, peg_count: int, powers: PackedInt64Array) -> Move:
	var parts: Array[int] = []
	for power: int in powers:
		var from_peg: int = (before / power) % peg_count
		var to_peg: int = (after / power) % peg_count
		if from_peg != to_peg:
			parts.append_array([from_peg, to_peg])
	if parts.size() == 4:
		return Move.new(parts[0], parts[1], parts[2], parts[3])
	return Move.new(parts[0], parts[1]) if parts.size() == 2 else null


static func _can_pack(start: PuzzleState, goal: PuzzleState, rules: RuleSet) -> bool:
	var keeps_sorted: bool = false
	for rule: RuleBase in rules.active_rules:
		if not rule.supports_disk_move_check() and not rule.needs_facts() and not rule.uses_memory():
			return false
		keeps_sorted = keeps_sorted or rule.keeps_stacks_sorted()
	if not keeps_sorted:
		return false
	if not rules.is_state_valid(start) or not rules.is_state_valid(goal):
		return false
	if not _pegs_sorted(start) or not _pegs_sorted(goal):
		return false
	var peg_count: int = start.pegs.size()
	var code_range: int = 1
	for i: int in start.get_disk_count():
		if code_range > MAX_PACKED_CODE / peg_count:
			return false
		code_range *= peg_count
	return true


## Every peg strictly decreasing from bottom to top.
static func _pegs_sorted(state: PuzzleState) -> bool:
	for peg: Array in state.pegs:
		for i: int in range(1, peg.size()):
			if peg[i] >= peg[i - 1]:
				return false
	return true


static func _same_pegs_and_disks(a: PuzzleState, b: PuzzleState) -> bool:
	return a.pegs.size() == b.pegs.size() and _sorted_disks(a) == _sorted_disks(b)


static func _sorted_disks(state: PuzzleState) -> Array[int]:
	var disks: Array[int] = []
	for peg: Array in state.pegs:
		for disk: int in peg:
			disks.append(disk)
	disks.sort()
	return disks


static func _result(solvable: bool, path: Array[Move], states_visited: int, limit_reached: bool) -> Dictionary:
	return {
		"solvable": solvable,
		"min_moves": path.size() if solvable else -1,
		"path": path,
		"states_visited": states_visited,
		"limit_reached": limit_reached,
		"strategy": "none",
	}
