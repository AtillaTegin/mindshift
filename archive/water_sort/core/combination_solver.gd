class_name CombinationSolver
extends RefCounted
## Solutions of "Birləşmə Tapmacası" levels (combination puzzle, level structure
## v4 section 4, Water Sort's rule from the auto-group addendum). The size-based
## Solver cannot be used for them: its disks are told apart by size and its
## goal is one exact position, while here every disk has one size and the goal
## is a colour arrangement (ColorGoal).
##
## A position is one string of colour letters per peg (ColorGoal.LETTERS), so
## disks of one colour count as the same. A move pours the same-colour run at
## the top of a peg onto an empty peg or onto its own colour, as much of it as
## fits (CombinationRule), and counts as one move. A pour cannot always be
## poured back, so moves are not reversible.
## - search(): breadth-first, shortest; only for small boards.
## - guided_search(): weighted A* with a lower bound on the pours still needed;
##   quick on large boards, a short solution, not a proven minimum.
## - shorten(): drops moves a found solution does not need.

const DEFAULT_MAX_STATES: int = 2000000
## Weight of the heuristic in guided_search (higher: faster, longer solutions).
const GUIDED_WEIGHT: float = 2.0
## Disks up to which solve() searches breadth-first (a proven shortest
## solution); larger boards get guided_search().
const EXACT_DISKS: int = 10
## Longest run of moves shorten() tries to drop at once.
const SHORTEN_WINDOW: int = 4


## A solution of the level from `from_state`: the shortest one when the board is
## small enough for search(), else guided_search() within `budget` expanded
## positions. { solvable, min_moves, path: Array[Move], states_visited, limit_reached }.
static func solve(level: Level, from_state: PuzzleState, budget: int = 20000) -> Dictionary:
	var capacity: int = capacity_of(level)
	if level.color_goal == null or capacity <= 0:
		return _result(false, [], 0, false)
	var pegs: PackedStringArray = ColorGoal.letters_of(from_state, level.disk_colors)
	if from_state.get_disk_count() <= EXACT_DISKS:
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
## Positions that differ only in which peg holds what are searched once
## (shape()): the goal does not care, and moves look the same on both.
static func search(start: PackedStringArray, capacity: int, goal: ColorGoal, max_states: int = DEFAULT_MAX_STATES) -> Dictionary:
	if goal.matches(start):
		return _result(true, [], 1, false)
	var start_key: String = "|".join(start)
	# key -> [previous key, from peg, to peg]; the start maps to [].
	var parents: Dictionary[String, Array] = {start_key: []}
	var seen: Dictionary[String, bool] = {shape(start): true}
	var frontier: PackedStringArray = PackedStringArray([start_key])
	var head: int = 0
	while head < frontier.size():
		var key: String = frontier[head]
		head += 1
		var pegs: PackedStringArray = key.split("|")
		for move: Vector2i in moves_of(pegs, capacity):
			var next: PackedStringArray = apply(pegs, move, capacity)
			var next_shape: String = shape(next)
			if seen.has(next_shape):
				continue
			seen[next_shape] = true
			var next_key: String = "|".join(next)
			parents[next_key] = [key, move.x, move.y]
			if goal.matches(next):
				return _result(true, _path_back(parents, next_key), seen.size(), false)
			if seen.size() >= max_states:
				return _result(false, [], seen.size(), true)
			frontier.append(next_key)
	return _result(false, [], seen.size(), false)


## Weighted A* (f = g + GUIDED_WEIGHT * h) over colour-letter positions (one
## per shape(), as in search()), giving up after `budget` expanded positions.
static func guided_search(start: PackedStringArray, capacity: int, goal: ColorGoal, budget: int) -> Dictionary:
	if goal.matches(start):
		return _result(true, [], 1, false)
	var start_key: String = "|".join(start)
	var parents: Dictionary[String, Array] = {start_key: []}
	var cost: Dictionary[String, int] = {shape(start): 0}
	var heap: Array = []
	var counter: int = 0
	_push(heap, [GUIDED_WEIGHT * heuristic(start), counter, start_key, 0])
	var expanded: int = 0
	while not heap.is_empty() and expanded < budget:
		var entry: Array = _pop(heap)
		var key: String = entry[2]
		var pegs: PackedStringArray = key.split("|")
		if goal.matches(pegs):
			return _result(true, _path_back(parents, key), cost.size(), false)
		var g: int = entry[3] + 1
		if entry[3] > cost[shape(pegs)]:
			continue  # reached more cheaply since it was queued
		expanded += 1
		for move: Vector2i in moves_of(pegs, capacity):
			var next: PackedStringArray = apply(pegs, move, capacity)
			var next_shape: String = shape(next)
			if cost.has(next_shape) and cost[next_shape] <= g:
				continue
			cost[next_shape] = g
			var next_key: String = "|".join(next)
			parents[next_key] = [key, move.x, move.y]
			counter += 1
			_push(heap, [g + GUIDED_WEIGHT * heuristic(next), counter, next_key, g])
	return _result(false, [], cost.size(), true)


## A position with its pegs in sorted order: the same for positions that only
## differ in which peg holds what.
static func shape(pegs: PackedStringArray) -> String:
	var sorted: PackedStringArray = pegs.duplicate()
	sorted.sort()
	return "|".join(sorted)


## A lower bound on the pours left. A pour moves (part of) one same-colour run,
## so every run that does not lie at the bottom of its peg must be poured off at
## least once, and of the runs of one colour lying at the bottom of several
## pegs all but one must be poured onto another.
static func heuristic(pegs: PackedStringArray) -> float:
	var moves: int = 0
	var bottoms: Dictionary = {}
	for text: String in pegs:
		if text.is_empty():
			continue
		for i: int in range(1, text.length()):
			moves += 1 if text[i] != text[i - 1] else 0
		bottoms[text[0]] = bottoms.get(text[0], 0) + 1
	for letter: String in bottoms:
		moves += bottoms[letter] - 1
	return moves


## `path` from `start` without the moves it does not need: runs of up to
## SHORTEN_WINDOW moves are dropped wherever the rest is still legal and still
## meets `goal` (pours are not reversible, so a detour cannot be spotted from
## the moves alone). Repeats until nothing changes.
static func shorten(start: PackedStringArray, path: Array[Move], capacity: int, goal: ColorGoal) -> Array[Move]:
	var moves: Array[Move] = path.duplicate()
	var changed: bool = true
	while changed:
		changed = false
		for window: int in range(SHORTEN_WINDOW, 0, -1):
			var i: int = 0
			while i + window <= moves.size():
				var trial: Array[Move] = moves.slice(0, i) + moves.slice(i + window)
				if solves(start, trial, capacity, goal):
					moves = trial
					changed = true
				else:
					i += 1
	return moves


## Whether `path` is legal from `start` and ends meeting `goal`.
static func solves(start: PackedStringArray, path: Array[Move], capacity: int, goal: ColorGoal) -> bool:
	var pegs: PackedStringArray = start
	for move: Move in path:
		var step: Vector2i = Vector2i(move.from_peg, move.to_peg)
		if not is_legal(pegs, step, capacity):
			return false
		pegs = apply(pegs, step, capacity)
	return goal.matches(pegs)


## Whether the top run of peg `move.x` may be poured onto peg `move.y`.
static func is_legal(pegs: PackedStringArray, move: Vector2i, capacity: int) -> bool:
	if move.x == move.y or move.x < 0 or move.y < 0 or move.x >= pegs.size() or move.y >= pegs.size():
		return false
	var source: String = pegs[move.x]
	var target: String = pegs[move.y]
	return not source.is_empty() and target.length() < capacity and (target.is_empty() or target[-1] == source[-1])


## Legal moves as Vector2i(from, to). Moves that only swap pegs around are left
## out (which peg holds a colour does not matter): pouring a peg of one colour
## onto an empty one, and pouring onto a second empty peg.
static func moves_of(pegs: PackedStringArray, capacity: int) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	for a: int in pegs.size():
		var source: String = pegs[a]
		if source.is_empty():
			continue
		var top: String = source[-1]
		var single: bool = source.count(top) == source.length()
		var poured_empty: bool = false
		for b: int in pegs.size():
			var target: String = pegs[b]
			if b == a or target.length() >= capacity:
				continue
			if target.is_empty():
				if single or poured_empty:
					continue
				poured_empty = true
			elif target[-1] != top:
				continue
			moves.append(Vector2i(a, b))
	return moves


## How many disks of one colour stand together at the top of `text`.
static func top_run(text: String) -> int:
	var run: int = 0
	while run < text.length() and text[text.length() - 1 - run] == text[-1]:
		run += 1
	return run


## `pegs` after pouring the top run of peg `move.x` onto peg `move.y`, as much
## of it as fits.
static func apply(pegs: PackedStringArray, move: Vector2i, capacity: int) -> PackedStringArray:
	var next: PackedStringArray = pegs.duplicate()
	var source: String = pegs[move.x]
	var count: int = mini(top_run(source), capacity - pegs[move.y].length())
	next[move.x] = source.left(source.length() - count)
	next[move.y] = pegs[move.y] + source.right(count)
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
