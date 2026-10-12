class_name SortSolver
extends RefCounted
## Breadth-first search and validation for the colour-order prototype
## (SortPuzzle). The main Solver is not used: it identifies disks by size and
## its goal is one exact position, while here equal-sized disks exist and the
## goal is a colour order. With 3 pegs and 6 disks the whole position space has
## at most a few thousand entries, so a plain search is instant.

const MAX_STATES: int = 200000


## A shortest move sequence from `pegs` to the goal:
## { solvable: bool, path: Array[Move] } (empty path when `pegs` is solved).
static func solve(puzzle: SortPuzzle, pegs: Array[Array]) -> Dictionary:
	if puzzle.is_goal(pegs):
		return {"solvable": true, "path": [] as Array[Move]}
	var start_key: String = puzzle.key(pegs)
	# key -> [previous key, move]; the start maps to [].
	var parents: Dictionary[String, Array] = {start_key: []}
	var frontier: Array = [pegs]
	var head: int = 0
	while head < frontier.size() and parents.size() < MAX_STATES:
		var current: Array[Array] = frontier[head]
		head += 1
		var current_key: String = puzzle.key(current)
		for from_peg: int in current.size():
			for to_peg: int in current.size():
				var move: Move = Move.new(from_peg, to_peg)
				if not puzzle.can_move(current, move):
					continue
				var next: Array[Array] = SortPuzzle.apply(current, move)
				var next_key: String = puzzle.key(next)
				if parents.has(next_key):
					continue
				parents[next_key] = [current_key, move]
				if puzzle.is_goal(next):
					return {"solvable": true, "path": _path(parents, next_key)}
				frontier.append(next)
	return {"solvable": false, "path": [] as Array[Move]}


## Every problem with the level, or an empty list: the disk set, the start
## position, a target that holds every disk once by colour, solvability, the
## stored shortest solution and a move limit the solution fits in.
static func validate(puzzle: SortPuzzle) -> Array[String]:
	var errors: Array[String] = []
	var count: int = puzzle.disk_count()
	if count == 0 or puzzle.colors.size() != count:
		errors.append("the level needs disks, each with a size and a colour")
		return errors
	for id: int in count:
		if puzzle.sizes[id] <= 0 or not SortPuzzle.COLORS.has(puzzle.colors[id]):
			errors.append("disk %d: size must be positive and colour one of %s" % [id, str(SortPuzzle.COLORS)])
	if puzzle.peg_count() < 3:
		errors.append("the level needs at least 3 pegs")
		return errors
	var seen: Array[int] = []
	for peg: Array in puzzle.start:
		for i: int in peg.size():
			var id: int = peg[i]
			if id < 0 or id >= count or seen.has(id):
				errors.append("start must hold every disk id 0..%d exactly once" % (count - 1))
				return errors
			seen.append(id)
			if i > 0 and puzzle.sizes[peg[i - 1]] < puzzle.sizes[id]:
				errors.append("start has a larger disk on a smaller one")
	if seen.size() != count:
		errors.append("start must hold every disk id 0..%d exactly once" % (count - 1))
		return errors
	if puzzle.target_peg < 0 or puzzle.target_peg >= puzzle.peg_count():
		errors.append("target_peg %d is not a peg" % puzzle.target_peg)
		return errors
	var wanted: Array[String] = puzzle.target_colors.duplicate()
	var have: Array[String] = puzzle.colors.duplicate()
	wanted.sort()
	have.sort()
	if wanted != have:
		errors.append("the target must use every disk's colour exactly once (%s)" % str(have))
		return errors
	if puzzle.is_goal(puzzle.start):
		errors.append("the start is already solved")
		return errors
	if not errors.is_empty():
		return errors
	var result: Dictionary = solve(puzzle, puzzle.start)
	if not result["solvable"]:
		errors.append("the target cannot be reached with legal moves")
		return errors
	var shortest: int = (result["path"] as Array).size()
	if puzzle.min_moves != shortest:
		errors.append("min_moves is %d, the shortest solution has %d" % [puzzle.min_moves, shortest])
	if puzzle.solution.size() != shortest:
		errors.append("the stored solution has %d moves, the shortest has %d" % [puzzle.solution.size(), shortest])
	var pegs: Array[Array] = SortPuzzle.copy_pegs(puzzle.start)
	for i: int in puzzle.solution.size():
		if not puzzle.can_move(pegs, puzzle.solution[i]):
			errors.append("solution move %d (%s) is illegal" % [i + 1, str(puzzle.solution[i])])
			return errors
		pegs = SortPuzzle.apply(pegs, puzzle.solution[i])
	if not puzzle.is_goal(pegs):
		errors.append("the stored solution does not reach the target")
	if puzzle.move_limit < shortest:
		errors.append("move_limit %d is below the shortest solution (%d)" % [puzzle.move_limit, shortest])
	return errors


static func _path(parents: Dictionary[String, Array], last_key: String) -> Array[Move]:
	var path: Array[Move] = []
	var key: String = last_key
	while not parents[key].is_empty():
		path.push_front(parents[key][1])
		key = parents[key][0]
	return path
