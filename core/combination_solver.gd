class_name CombinationSolver
extends RefCounted
## Solutions of "Birləşmə Tapmacası" levels (combination puzzle, level structure
## v4 section 4 and correction v2). The size-based Solver cannot be used for
## them: its disks are told apart by size and its goal is one exact position,
## while here every disk has one size and the goal is a colour arrangement
## (ColorGoal).
##
## A position is one string of colour letters per peg (ColorGoal.LETTERS), so
## disks of one colour count as the same. A disk may go onto any peg below its
## capacity (CombinationRule), and every such move can be taken back.
## - search(): breadth-first, shortest; only for small boards.
## - guided_search(): weighted A* with a lower-bound count of disks that must
##   still move; quick on large boards, a short solution, not a proven minimum.
## - scramble(): legal moves walked away from a goal position; walked back they
##   solve the start, which proves every level solvable however large it is.
## - shorten(): drops detours (a disk moved twice in a row, or moved back).

const DEFAULT_MAX_STATES: int = 2000000
## Weight of the heuristic in guided_search (higher: faster, longer solutions).
const GUIDED_WEIGHT: float = 2.0


## A solution of the level from `from_state`: the shortest one when the board is
## small enough for search(), else guided_search() within `budget` expanded
## positions. { solvable, min_moves, path: Array[Move], states_visited, limit_reached }.
static func solve(level: Level, from_state: PuzzleState, budget: int = 20000) -> Dictionary:
	var capacity: int = capacity_of(level)
	if level.color_goal == null or capacity <= 0:
		return _result(false, [], 0, false)
	var pegs: PackedStringArray = ColorGoal.letters_of(from_state, level.disk_colors)
	if from_state.get_disk_count() <= 10:
		return search(pegs, capacity, level.color_goal, maxi(budget * 10, 200000))
	return guided_search(pegs, capacity, level.color_goal, budget)


## The capacity of a combination level's pegs (0 if it has no combination rule).
static func capacity_of(level: Level) -> int:
	var rules: RuleSet = level.get_rule_set()
	if rules == null:
		return 0
	for rule: RuleBase in rules.active_rules:
		if rule is CombinationRule:
			return (rule as CombinationRule).capacity
	return 0


## Breadth-first search over colour-letter positions: a shortest solution.
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
		for move: Vector2i in _moves(pegs, capacity, goal.kind == ColorGoal.SORT):
			var next: PackedStringArray = _apply(pegs, move)
			var next_key: String = "|".join(next)
			if parents.has(next_key):
				continue
			parents[next_key] = [key, move.x, move.y]
			if goal.matches(next):
				return _result(true, _path_back(parents, next_key), parents.size(), false)
			if parents.size() >= max_states:
				return _result(false, [], parents.size(), true)
			frontier.append(next_key)
	return _result(false, [], parents.size(), false)


## Weighted A* (f = g + GUIDED_WEIGHT * h) over colour-letter positions,
## giving up after `budget` expanded positions.
static func guided_search(start: PackedStringArray, capacity: int, goal: ColorGoal, budget: int) -> Dictionary:
	if goal.matches(start):
		return _result(true, [], 1, false)
	var targets: PackedStringArray = goal.target_letters() if goal.kind == ColorGoal.PATTERN else PackedStringArray()
	var start_key: String = "|".join(start)
	var parents: Dictionary[String, Array] = {start_key: []}
	var cost: Dictionary[String, int] = {start_key: 0}
	var heap: Array = []
	var counter: int = 0
	_push(heap, [GUIDED_WEIGHT * heuristic(start, goal, targets), counter, start_key])
	var expanded: int = 0
	while not heap.is_empty() and expanded < budget:
		var key: String = _pop(heap)[2]
		var pegs: PackedStringArray = key.split("|")
		if goal.matches(pegs):
			return _result(true, _path_back(parents, key), parents.size(), false)
		expanded += 1
		var g: int = cost[key] + 1
		for move: Vector2i in _moves(pegs, capacity, goal.kind == ColorGoal.SORT):
			var next: PackedStringArray = _apply(pegs, move)
			var next_key: String = "|".join(next)
			if cost.has(next_key) and cost[next_key] <= g:
				continue
			cost[next_key] = g
			parents[next_key] = [key, move.x, move.y]
			counter += 1
			_push(heap, [g + GUIDED_WEIGHT * heuristic(next, goal, targets), counter, next_key])
	return _result(false, [], parents.size(), true)


## A lower bound on the moves left: every disk that is not yet where it stays
## must move at least once. PATTERN: the disks above each peg's matching
## bottom. SORT: the disks above each peg's single-colour bottom run, plus every
## run but the largest of a colour that lies at the bottom of several pegs.
static func heuristic(pegs: PackedStringArray, goal: ColorGoal, targets: PackedStringArray = PackedStringArray()) -> float:
	var moves: int = 0
	if goal.kind == ColorGoal.PATTERN:
		if targets.is_empty():
			targets = goal.target_letters()
		for peg_index: int in pegs.size():
			var text: String = pegs[peg_index]
			var target: String = targets[peg_index]
			var matched: int = 0
			while matched < text.length() and matched < target.length() and text[matched] == target[matched]:
				matched += 1
			moves += text.length() - matched
		return moves
	var largest: Dictionary = {}
	var runs: Dictionary = {}
	for text: String in pegs:
		if text.is_empty():
			continue
		var run: int = 1
		while run < text.length() and text[run] == text[0]:
			run += 1
		moves += text.length() - run
		runs[text[0]] = runs.get(text[0], 0) + run
		largest[text[0]] = maxi(largest.get(text[0], 0), run)
	for letter: String in runs:
		moves += runs[letter] - largest[letter]
	return moves


## Legal moves walked away from `goal_pegs` (each step a random legal move,
## never straight back), with loops cut out as they appear. Returns the walk:
## { keys: every position on it in order (keys[0] is the goal), walk: the move
## that led to each next one }; walk_back() turns a position on it into a
## solution.
static func scramble(goal_pegs: PackedStringArray, capacity: int, steps: int, rng: RandomNumberGenerator) -> Dictionary:
	var keys: PackedStringArray = PackedStringArray(["|".join(goal_pegs)])
	var walk: Array[Vector2i] = []
	var index: Dictionary[String, int] = {keys[0]: 0}
	var pegs: PackedStringArray = goal_pegs.duplicate()
	for step: int in steps:
		var moves: Array[Vector2i] = _moves(pegs, capacity, false)
		if not walk.is_empty():
			moves.erase(Vector2i(walk[-1].y, walk[-1].x))
		if moves.is_empty():
			break
		var move: Vector2i = moves[rng.randi_range(0, moves.size() - 1)]
		pegs = _apply(pegs, move)
		var key: String = "|".join(pegs)
		if index.has(key):
			# Back where the walk has been: cut the loop out.
			var keep: int = index[key]
			for erased: int in range(keep + 1, keys.size()):
				index.erase(keys[erased])
			keys.resize(keep + 1)
			walk.resize(keep)
		else:
			index[key] = keys.size()
			keys.append(key)
			walk.append(move)
	return {"keys": keys, "walk": walk}


## The way back to the goal from position `index` of a scramble() walk: its
## moves undone in reverse order.
static func walk_back(scrambled: Dictionary, index: int) -> Array[Move]:
	var walk: Array[Vector2i] = scrambled["walk"]
	var back: Array[Move] = []
	for j: int in range(index - 1, -1, -1):
		back.append(Move.new(walk[j].y, walk[j].x))
	return back


## `path` from `start` with its detours taken out: a disk moved twice in a row
## goes straight to its last peg, and a disk moved back where it came from does
## not move at all. Repeats until nothing changes; still a solution if `path`
## was one.
static func shorten(start: PackedStringArray, path: Array[Move]) -> Array[Move]:
	var moves: Array[Move] = path.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		var i: int = 0
		while i < moves.size() - 1:
			var first: Move = moves[i]
			var second: Move = moves[i + 1]
			if second.from_peg == first.to_peg:
				if second.to_peg == first.from_peg:
					moves.remove_at(i + 1)
					moves.remove_at(i)
				else:
					moves[i] = Move.new(first.from_peg, second.to_peg)
					moves.remove_at(i + 1)
				changed = true
				i = maxi(i - 1, 0)
			else:
				i += 1
	return moves


## The goal position of a PATTERN goal, or one goal position of a SORT goal
## (colour after colour on the pegs from the left) for these disk letters.
static func goal_position(goal: ColorGoal, letters: String, peg_count: int) -> PackedStringArray:
	if goal.kind == ColorGoal.PATTERN:
		return goal.target_letters()
	var pegs: PackedStringArray = PackedStringArray()
	pegs.resize(peg_count)
	var index: int = 0
	for letter: String in letters:
		var peg: int = -1
		for p: int in index:
			if pegs[p].begins_with(letter):
				peg = p
		if peg == -1:
			peg = index
			index += 1
		pegs[peg] += letter
	return pegs


## Legal moves as Vector2i(from, to). With `symmetric` (a sort goal, where it
## does not matter which peg holds what) moves that only swap pegs around are
## left out: a lone disk to an empty peg, and a disk to a second empty peg.
static func _moves(pegs: PackedStringArray, capacity: int, symmetric: bool) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for a: int in pegs.size():
		if pegs[a].is_empty():
			continue
		var lone: bool = pegs[a].length() == 1
		var moved_empty: bool = false
		for b: int in pegs.size():
			if b == a or pegs[b].length() >= capacity:
				continue
			if symmetric and pegs[b].is_empty():
				if lone or moved_empty:
					continue
				moved_empty = true
			moves.append(Vector2i(a, b))
	return moves


static func _apply(pegs: PackedStringArray, move: Vector2i) -> PackedStringArray:
	var next: PackedStringArray = pegs.duplicate()
	var source: String = pegs[move.x]
	next[move.x] = source.left(-1)
	next[move.y] = pegs[move.y] + source.right(1)
	return next


## Binary min-heap of [f, counter, key] entries (counter breaks ties FIFO).
static func _push(heap: Array, entry: Array) -> void:
	heap.append(entry)
	var i: int = heap.size() - 1
	while i > 0:
		var parent: int = (i - 1) / 2
		if not _less(heap[i], heap[parent]):
			break
		var swap: Array = heap[i]
		heap[i] = heap[parent]
		heap[parent] = swap
		i = parent


static func _pop(heap: Array) -> Array:
	var top: Array = heap[0]
	var last: Array = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i: int = 0
	while true:
		var smallest: int = i
		for child: int in [2 * i + 1, 2 * i + 2]:
			if child < heap.size() and _less(heap[child], heap[smallest]):
				smallest = child
		if smallest == i:
			break
		var swap: Array = heap[i]
		heap[i] = heap[smallest]
		heap[smallest] = swap
		i = smallest
	return top


static func _less(a: Array, b: Array) -> bool:
	return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1])


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
