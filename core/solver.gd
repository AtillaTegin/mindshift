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
## - Generic search: standard BFS over PuzzleState with a hash_key() visited set.
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
##   strategy: String     - "packed", "generic", or "none" when no search was needed
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
	if _can_pack(start, goal, rules):
		result = _solve_packed(start, goal, rules, max_states)
		result["strategy"] = "packed"
	else:
		result = _solve_generic(start, goal, rules, max_states)
		result["strategy"] = "generic"
	return result


static func _solve_generic(start: PuzzleState, goal: PuzzleState, rules: RuleSet,
		max_states: int) -> Dictionary:
	var start_key: String = start.hash_key()
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
			var next_key: String = next.hash_key()
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


## The single move that turns position `before` into `after`.
static func _packed_move(before: int, after: int, peg_count: int, powers: PackedInt64Array) -> Move:
	for power: int in powers:
		var from_peg: int = (before / power) % peg_count
		var to_peg: int = (after / power) % peg_count
		if from_peg != to_peg:
			return Move.new(from_peg, to_peg)
	return null


static func _can_pack(start: PuzzleState, goal: PuzzleState, rules: RuleSet) -> bool:
	var keeps_sorted: bool = false
	for rule: RuleBase in rules.active_rules:
		if not rule.supports_disk_move_check():
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
