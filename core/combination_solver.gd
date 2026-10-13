class_name CombinationSolver
extends RefCounted
## Shortest solutions of "Birləşmə Tapmacası" levels (combination puzzle, level
## structure v4, section 4). The size-based Solver cannot be used for them: its
## disks are told apart by size and its goal is one exact position, while here
## every disk has one size and the goal is a colour arrangement (ColorGoal).
##
## A position is one string of colour letters per peg (ColorGoal.LETTERS), so
## disks of one colour count as the same: the search stays small and every
## arrangement of them that meets the goal is found. A disk may go onto any peg
## that is below its capacity (CombinationRule). Such a move can always be taken
## back, so a search outward from all goal positions (distance_map) gives every
## start's shortest solution at once; the level builder uses that.

const DEFAULT_MAX_STATES: int = 2000000


## The shortest move sequence from `from_state` to the level's colour goal:
## { solvable, min_moves, path: Array[Move], states_visited, limit_reached }.
static func solve(level: Level, from_state: PuzzleState, max_states: int = DEFAULT_MAX_STATES) -> Dictionary:
	var capacity: int = capacity_of(level)
	if level.color_goal == null or capacity <= 0:
		return _result(false, [], 0, false)
	return search(ColorGoal.letters_of(from_state, level.disk_colors), capacity, level.color_goal, max_states)


## The capacity of a combination level's pegs (0 if it has no combination rule).
static func capacity_of(level: Level) -> int:
	var rules: RuleSet = level.get_rule_set()
	if rules == null:
		return 0
	for rule: RuleBase in rules.active_rules:
		if rule is CombinationRule:
			return (rule as CombinationRule).capacity
	return 0


## Breadth-first search over colour-letter positions.
static func search(start: PackedStringArray, capacity: int, goal: ColorGoal, max_states: int = DEFAULT_MAX_STATES) -> Dictionary:
	if goal.matches(start):
		return _result(true, [], 1, false)
	var start_key: String = "|".join(start)
	# key -> [previous key, from peg, to peg]; the start maps to [].
	var parents: Dictionary[String, Array] = {start_key: []}
	var frontier: PackedStringArray = PackedStringArray([start_key])
	var head: int = 0
	while head < frontier.size():
		var key: String = frontier[head]
		head += 1
		var pegs: PackedStringArray = key.split("|")
		for a: int in pegs.size():
			var source: String = pegs[a]
			if source.is_empty():
				continue
			var top: String = source.right(1)
			var rest: String = source.left(-1)
			for b: int in pegs.size():
				if b == a or pegs[b].length() >= capacity:
					continue
				var next: PackedStringArray = pegs.duplicate()
				next[a] = rest
				next[b] = pegs[b] + top
				var next_key: String = "|".join(next)
				if parents.has(next_key):
					continue
				parents[next_key] = [key, a, b]
				if goal.matches(next):
					return _result(true, _path_back(parents, next_key), parents.size(), false)
				if parents.size() >= max_states:
					return _result(false, [], parents.size(), true)
				frontier.append(next_key)
	return _result(false, [], parents.size(), false)


## Every position reachable from the goal positions, with its distance to the
## nearest one and the first move of a shortest way there:
## key -> [distance, next key, from peg, to peg] (goals: [0, "", -1, -1]).
static func distance_map(goals: Array[PackedStringArray], capacity: int) -> Dictionary:
	var map: Dictionary = {}
	var frontier: PackedStringArray = PackedStringArray()
	for goal_pegs: PackedStringArray in goals:
		var goal_key: String = "|".join(goal_pegs)
		if not map.has(goal_key):
			map[goal_key] = [0, "", -1, -1]
			frontier.append(goal_key)
	var head: int = 0
	while head < frontier.size():
		var key: String = frontier[head]
		head += 1
		var distance: int = map[key][0]
		var pegs: PackedStringArray = key.split("|")
		for a: int in pegs.size():
			var source: String = pegs[a]
			if source.is_empty():
				continue
			for b: int in pegs.size():
				if b == a or pegs[b].length() >= capacity:
					continue
				var next: PackedStringArray = pegs.duplicate()
				next[a] = source.left(-1)
				next[b] = pegs[b] + source.right(1)
				var next_key: String = "|".join(next)
				if map.has(next_key):
					continue
				# From `next`, moving b -> a leads back here, one step closer.
				map[next_key] = [distance + 1, key, b, a]
				frontier.append(next_key)
	return map


## The shortest way from `key` to a goal along a distance_map().
static func path_from(map: Dictionary, key: String) -> Array[Move]:
	var path: Array[Move] = []
	var current: String = key
	while map[current][0] > 0:
		path.append(Move.new(map[current][2], map[current][3]))
		current = map[current][1]
	return path


## Every position that meets `goal` with these disks (`letters`: one letter per
## disk) on `peg_count` pegs of `capacity`.
static func goal_positions(goal: ColorGoal, letters: String, peg_count: int, capacity: int) -> Array[PackedStringArray]:
	var counts: Dictionary = {}
	for letter: String in letters:
		counts[letter] = counts.get(letter, 0) + 1
	var positions: Array[PackedStringArray] = []
	if goal.kind == ColorGoal.SORT:
		var colours: Array = counts.keys()
		colours.sort()
		_assign_pegs(colours, counts, peg_count, PackedStringArray(), positions)
		return positions
	var pattern: String = goal.pattern_letters()
	for letter: String in pattern:
		counts[letter] -= 1
	var others: Array[int] = []
	for peg_index: int in peg_count:
		if peg_index != goal.peg:
			others.append(peg_index)
	var empty: PackedStringArray = PackedStringArray()
	empty.resize(peg_count)
	empty[goal.peg] = pattern
	_fill_pegs(others, 0, counts, capacity, empty, positions)
	return positions


## SORT goals: each colour (in order) on a different peg, all of it.
static func _assign_pegs(colours: Array, counts: Dictionary, peg_count: int, pegs: PackedStringArray,
		positions: Array[PackedStringArray]) -> void:
	if pegs.is_empty():
		pegs.resize(peg_count)
	var placed: int = 0
	for text: String in pegs:
		placed += 1 if not text.is_empty() else 0
	if placed == colours.size():
		positions.append(pegs.duplicate())
		return
	var letter: String = colours[placed]
	for peg_index: int in peg_count:
		if pegs[peg_index].is_empty():
			pegs[peg_index] = letter.repeat(counts[letter])
			_assign_pegs(colours, counts, peg_count, pegs, positions)
			pegs[peg_index] = ""


## PATTERN goals: the remaining disks spread over the other pegs in every order.
static func _fill_pegs(others: Array[int], index: int, counts: Dictionary, capacity: int, pegs: PackedStringArray,
		positions: Array[PackedStringArray]) -> void:
	var remaining: int = 0
	for letter: String in counts:
		remaining += counts[letter]
	if index == others.size():
		if remaining == 0:
			positions.append(pegs.duplicate())
		return
	var room_after: int = (others.size() - index - 1) * capacity
	for length: int in range(maxi(remaining - room_after, 0), mini(capacity, remaining) + 1):
		for stack: String in _sequences(counts, length):
			for letter: String in stack:
				counts[letter] -= 1
			pegs[others[index]] = stack
			_fill_pegs(others, index + 1, counts, capacity, pegs, positions)
			for letter: String in stack:
				counts[letter] += 1
	pegs[others[index]] = ""


## Every string of `length` letters that `counts` can supply.
static func _sequences(counts: Dictionary, length: int) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if length == 0:
		found.append("")
		return found
	for letter: String in counts:
		if counts[letter] == 0:
			continue
		counts[letter] -= 1
		for rest: String in _sequences(counts, length - 1):
			found.append(letter + rest)
		counts[letter] += 1
	return found


static func _path_back(parents: Dictionary[String, Array], last_key: String) -> Array[Move]:
	var path: Array[Move] = []
	var key: String = last_key
	while not parents[key].is_empty():
		path.push_front(Move.new(parents[key][1], parents[key][2]))
		key = parents[key][0]
	return path


static func _result(solvable: bool, path: Array[Move], visited: int, limit_reached: bool) -> Dictionary:
	return {"solvable": solvable, "min_moves": path.size() if solvable else -1, "path": path,
			"states_visited": visited, "limit_reached": limit_reached}
