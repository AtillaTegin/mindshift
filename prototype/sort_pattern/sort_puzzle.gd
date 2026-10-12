class_name SortPuzzle
extends RefCounted
## Prototype level (mechanics prototype, 2026-10-13): colored disks, some of
## equal size, to be stacked on the target peg in a given colour order within a
## move budget. It is kept apart from the Hanoi engine on purpose: PuzzleState
## identifies a disk by its size, which equal-sized disks cannot share.
##
## A disk is an id 0..n-1 with its own size and colour, so equal-sized disks
## keep their identities. A peg is an array of disk ids, bottom -> top; the top
## disk is the last element. Rules: only the top disk moves, and it may go onto
## an empty peg or onto a disk of the same size or larger (equal sizes stack).
## The goal is read by colour, not by identity: the target peg must hold every
## disk, showing `target_colors` from the bottom up.

const LEVEL_PATH: String = "res://prototype/sort_pattern/sort_level.json"
const COLORS: Array[String] = ["red", "blue", "yellow", "green"]

var sizes: Array[int] = []
var colors: Array[String] = []
var start: Array[Array] = []
var target_peg: int = 0
## Colours the target peg must show, bottom -> top, one per disk.
var target_colors: Array[String] = []
## Moves allowed (M). The level file starts it at min_moves + 2.
var move_limit: int = 0
## Length of a shortest solution (S), from the breadth-first search.
var min_moves: int = 0
var solution: Array[Move] = []


static func load_file(path: String, errors: Array[String]) -> SortPuzzle:
	if not FileAccess.file_exists(path):
		errors.append("file not found: %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("%s is not a JSON object" % path)
		return null
	return from_dict(data, errors)


## Builds a puzzle from parsed JSON; problems go to `errors` (null then).
## Consistency and solvability are checked by SortSolver.validate().
static func from_dict(data: Dictionary, errors: Array[String]) -> SortPuzzle:
	var puzzle: SortPuzzle = SortPuzzle.new()
	var error_count: int = errors.size()
	for disk: Variant in data.get("disks", []):
		if typeof(disk) != TYPE_DICTIONARY or not _is_integral(disk.get("size")) or typeof(disk.get("color")) != TYPE_STRING:
			errors.append("each disk needs an integer \"size\" and a \"color\" string")
			return null
		puzzle.sizes.append(int(disk["size"]))
		puzzle.colors.append(disk["color"])
	var pegs: Variant = data.get("start")
	if typeof(pegs) != TYPE_ARRAY:
		errors.append("\"start\" must be a list of pegs")
		return null
	for peg: Variant in pegs:
		if typeof(peg) != TYPE_ARRAY or not peg.all(func(id: Variant) -> bool: return _is_integral(id)):
			errors.append("each peg in \"start\" must be a list of disk ids")
			return null
		var ids: Array = []
		for id: Variant in peg:
			ids.append(int(id))
		puzzle.start.append(ids)
	if not _is_integral(data.get("target_peg")):
		errors.append("\"target_peg\" must be an integer")
	else:
		puzzle.target_peg = int(data["target_peg"])
	var target: Variant = data.get("target")
	if typeof(target) == TYPE_ARRAY and target.all(func(c: Variant) -> bool: return typeof(c) == TYPE_STRING):
		puzzle.target_colors.assign(target)
	else:
		errors.append("\"target\" must be a list of colour names")
	puzzle.move_limit = int(data.get("move_limit", 0)) if _is_integral(data.get("move_limit", 0)) else 0
	puzzle.min_moves = int(data.get("min_moves", 0)) if _is_integral(data.get("min_moves", 0)) else 0
	for pair: Variant in data.get("solution", []):
		var move: Move = Move.from_array(pair)
		if move == null:
			errors.append("\"solution\" entries must be [from, to] pairs")
			break
		puzzle.solution.append(move)
	return puzzle if errors.size() == error_count else null


func to_dict() -> Dictionary:
	var disks: Array = []
	for id: int in sizes.size():
		disks.append({"size": sizes[id], "color": colors[id]})
	var moves: Array = []
	for move: Move in solution:
		moves.append(move.to_array())
	return {"pegs": start.size(), "disks": disks, "start": copy_pegs(start), "target_peg": target_peg,
			"target": target_colors.duplicate(), "min_moves": min_moves, "move_limit": move_limit,
			"solution": moves}


func disk_count() -> int:
	return sizes.size()


func peg_count() -> int:
	return start.size()


static func copy_pegs(pegs: Array[Array]) -> Array[Array]:
	var copy: Array[Array] = []
	for peg: Array in pegs:
		copy.append(peg.duplicate())
	return copy


## Top disk id of `peg_index`, or -1 when it is empty.
static func top_of(pegs: Array[Array], peg_index: int) -> int:
	var peg: Array = pegs[peg_index]
	return -1 if peg.is_empty() else int(peg.back())


## Whether the top disk of `move.from_peg` may go onto `move.to_peg`.
func can_move(pegs: Array[Array], move: Move) -> bool:
	if move.from_peg < 0 or move.from_peg >= pegs.size() or move.to_peg < 0 or move.to_peg >= pegs.size():
		return false
	if move.from_peg == move.to_peg or pegs[move.from_peg].is_empty():
		return false
	var under: int = top_of(pegs, move.to_peg)
	return under == -1 or sizes[under] >= sizes[top_of(pegs, move.from_peg)]


## New pegs with `move` made; the caller has checked can_move().
static func apply(pegs: Array[Array], move: Move) -> Array[Array]:
	var next: Array[Array] = copy_pegs(pegs)
	next[move.to_peg].append(next[move.from_peg].pop_back())
	return next


func colors_on(peg: Array) -> Array[String]:
	var seen: Array[String] = []
	for id: int in peg:
		seen.append(colors[id])
	return seen


func is_goal(pegs: Array[Array]) -> bool:
	return colors_on(pegs[target_peg]) == target_colors


## How many disks at the bottom of the target peg already show the target
## colours in order (the player's progress).
func matched_count(pegs: Array[Array]) -> int:
	var peg: Array = pegs[target_peg]
	var count: int = 0
	while count < peg.size() and count < target_colors.size() and colors[peg[count]] == target_colors[count]:
		count += 1
	return count


## Search key: disks of the same size and colour are interchangeable for the
## goal, so they share a token and such positions count as one.
func key(pegs: Array[Array]) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for peg: Array in pegs:
		var tokens: PackedStringArray = PackedStringArray()
		for id: int in peg:
			tokens.append("%d%s" % [sizes[id], colors[id]])
		parts.append(",".join(tokens))
	return "|".join(parts)


static func _is_integral(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value))
