extends SceneTree
## Measures E_min(C, N) for the "Birləşmə Tapmacası" sort goal (correction v3,
## section 3): the fewest empty pegs with which random Water Sort starts (C
## full pegs of N disks, one colour per N disks, no peg of a single colour)
## are solvable. For each E from 1 up, SAMPLES starts are drawn (fixed seed)
## and searched: exhaustively (BFS, which also proves a start unsolvable) while
## the board has at most EXACT_DISKS disks, else by guided search within
## BUDGET expanded positions (a start it does not solve then is only "not
## found"). E_min is the first E at which at least SOLVED_SHARE of the starts
## are solved. From the project folder:
##   godot --headless --path . --script res://tools/combination_e_min.gd
##   ... -- --pairs=4x7,8x7   (colours x capacity; default PAIRS)
## The result is copied into Difficulty.COMBINATION_E_MIN.

const PAIRS: Array[Vector2i] = [Vector2i(2, 4), Vector2i(3, 4), Vector2i(3, 5), Vector2i(3, 6), Vector2i(4, 6),
		Vector2i(4, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7), Vector2i(9, 7), Vector2i(10, 7)]
const SAMPLES: int = 8
const SOLVED_SHARE: float = 0.75
const EXACT_DISKS: int = 12
const BUDGET: int = 40000
const MAX_EMPTY: int = 3
const SEED: int = 20261013


func _initialize() -> void:
	var pairs: Array[Vector2i] = PAIRS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pairs="):
			pairs.clear()
			for item: String in arg.trim_prefix("--pairs=").split(","):
				var parts: PackedStringArray = item.split("x")
				pairs.append(Vector2i(int(parts[0]), int(parts[1])))
	for pair: Vector2i in pairs:
		print(measure(pair.x, pair.y))
	quit(0)


## One line for C colours of capacity N: the solved share per E and E_min.
static func measure(colours: int, capacity: int) -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = SEED + colours * 100 + capacity
	var letters: Array = ColorGoal.LETTERS.values().slice(0, colours)
	var parts: PackedStringArray = PackedStringArray()
	var e_min: int = -1
	var started: int = Time.get_ticks_msec()
	for empty: int in range(1, MAX_EMPTY + 1):
		var solved: int = 0
		var proven_unsolvable: int = 0
		for sample: int in SAMPLES:
			var start: PackedStringArray = random_start(letters, capacity, colours + empty, rng)
			var result: Dictionary
			if colours * capacity <= EXACT_DISKS:
				result = CombinationSolver.search(start, capacity, ColorGoal.sort(), 5000000)
				proven_unsolvable += 0 if result["solvable"] or result["limit_reached"] else 1
			else:
				result = CombinationSolver.guided_search(start, capacity, ColorGoal.sort(), BUDGET)
			solved += 1 if result["solvable"] else 0
		parts.append("E=%d: %d/%d solved%s" % [empty, solved, SAMPLES,
				" (%d proven unsolvable)" % proven_unsolvable if proven_unsolvable > 0 else ""])
		if solved >= SOLVED_SHARE * SAMPLES:
			e_min = empty
			break
	return "C=%d N=%d (%d disks): %s -> E_min %s (%d ms)" % [colours, capacity, colours * capacity, ", ".join(parts),
			str(e_min) if e_min > 0 else "not found up to %d" % MAX_EMPTY, Time.get_ticks_msec() - started]


## C full pegs of N shuffled disks plus the empty ones, no peg of one colour.
static func random_start(letters: Array, capacity: int, peg_count: int, rng: RandomNumberGenerator) -> PackedStringArray:
	while true:
		var disks: Array = []
		for letter: String in letters:
			for i: int in capacity:
				disks.append(letter)
		for i: int in range(disks.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var swap: Variant = disks[i]
			disks[i] = disks[j]
			disks[j] = swap
		var pegs: PackedStringArray = PackedStringArray()
		var mixed: bool = true
		for p: int in peg_count:
			var text: String = ""
			if p < letters.size():
				text = "".join(PackedStringArray(disks.slice(p * capacity, (p + 1) * capacity)))
				mixed = mixed and text.count(text[0]) != text.length()
			pegs.append(text)
		if mixed:
			return pegs
	return PackedStringArray()
