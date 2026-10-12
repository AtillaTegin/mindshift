extends SceneTree
## Fills in the prototype level's shortest solution, its length and the move
## limit, then validates the file. The disks, start and target are written by
## hand in sort_level.json; this tool only computes. From the project folder:
##   godot --headless --path . --script res://prototype/sort_pattern/sort_builder.gd
##   ... -- --slack=3     limit = shortest solution + 3 (default 2)
##   ... -- --limit=18    an exact limit (at least the shortest solution)

const DEFAULT_SLACK: int = 2
const KEY_ORDER: Array[String] = ["pegs", "disks", "start", "target_peg", "target", "min_moves", "move_limit", "solution"]


func _initialize() -> void:
	quit(0 if _build() else 1)


func _build() -> bool:
	var errors: Array[String] = []
	var puzzle: SortPuzzle = SortPuzzle.load_file(SortPuzzle.LEVEL_PATH, errors)
	if puzzle == null:
		printerr("Cannot read the level: %s" % "; ".join(errors))
		return false
	var result: Dictionary = SortSolver.solve(puzzle, puzzle.start)
	if not result["solvable"]:
		printerr("The target cannot be reached from the start.")
		return false
	puzzle.solution.assign(result["path"])
	puzzle.min_moves = puzzle.solution.size()
	puzzle.move_limit = puzzle.min_moves + DEFAULT_SLACK
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--slack="):
			puzzle.move_limit = puzzle.min_moves + int(arg.trim_prefix("--slack="))
		elif arg.begins_with("--limit="):
			puzzle.move_limit = int(arg.trim_prefix("--limit="))
	errors = SortSolver.validate(puzzle)
	if not errors.is_empty():
		printerr("Invalid level: %s" % "; ".join(errors))
		return false
	var data: Dictionary = puzzle.to_dict()
	var lines: PackedStringArray = PackedStringArray()
	for key: String in KEY_ORDER:
		lines.append("  %s: %s" % [JSON.stringify(key), JSON.stringify(data[key], "", false)])
	var file: FileAccess = FileAccess.open(SortPuzzle.LEVEL_PATH, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write %s" % SortPuzzle.LEVEL_PATH)
		return false
	file.store_string("{\n%s\n}\n" % ",\n".join(lines))
	file.close()
	var moves: PackedStringArray = PackedStringArray()
	for move: Move in puzzle.solution:
		moves.append("%d>%d" % [move.from_peg, move.to_peg])
	print("Shortest solution S = %d moves: %s" % [puzzle.min_moves, " ".join(moves)])
	print("Move limit M = %d (S + %d). Written to %s" % [puzzle.move_limit, puzzle.move_limit - puzzle.min_moves, SortPuzzle.LEVEL_PATH])
	return true
