extends "res://tests/test_case.gd"
## The similarity check (current decisions 2026-10-16, E): one canonical form
## per puzzle, the same for its pegs reordered or mirrored and for swapped
## colours, and no two shipped levels share one.

const MAIN: String = LevelCatalog.MAIN


static func _key(rule_ids: Array, start: Array, goal: Array, params: Dictionary = {}) -> String:
	return PuzzleIdentity.key(PuzzleState.new(start), PuzzleState.new(goal), rule_ids, params)


func test_classic_pegs_may_be_reordered_or_mirrored() -> void:
	var c: Array = ["classic_hanoi"]
	var key: String = _key(c, [[3, 2, 1], [], []], [[], [], [3, 2, 1]])
	assert_eq(_key(c, [[], [3, 2, 1], []], [[3, 2, 1], [], []]), key, "another tower to tower")
	assert_eq(_key(c, [[], [], [3, 2, 1]], [[3, 2, 1], [], []]), key, "mirrored")
	assert_ne(_key(c, [[3, 2], [1], []], [[], [], [3, 2, 1]]), key, "another start")
	assert_ne(_key(c, [[], [], [3, 2, 1]], [[3, 2, 1], [], []]), _key(["classic_hanoi", "alternation"],
			[[], [], [3, 2, 1]], [[3, 2, 1], [], []]), "another rule")


func test_peg_settings_travel_with_their_pegs() -> void:
	var ids: Array = ["classic_hanoi", "peg_capacity"]
	var caps: Dictionary = {"peg_capacity": {"capacities": [4, 1, 2, 4]}}
	var key: String = _key(ids, [[4, 3], [2], [1], []], [[], [], [], [4, 3, 2, 1]], caps)
	assert_eq(_key(ids, [[], [1], [2], [4, 3]], [[4, 3, 2, 1], [], [], []], {"peg_capacity": {"capacities": [4, 2, 1, 4]}}),
			key, "mirrored with its capacities")
	assert_ne(_key(ids, [[4, 3], [1], [2], []], [[], [], [], [4, 3, 2, 1]], caps), key,
			"disks 1 and 2 swapped pegs, the capacities did not")
	var lock: Array = ["classic_hanoi", "foundation"]
	var locked: String = _key(lock, [[4, 3], [2, 1], []], [[], [], [4, 3, 2, 1]], {"foundation": {"locked": [4], "keys": [1], "targets": [2]}})
	assert_eq(_key(lock, [[2, 1], [4, 3], []], [[], [], [4, 3, 2, 1]], {"foundation": {"locked": [4], "keys": [1], "targets": [2]}}),
			locked, "the key place stays with its peg")
	assert_ne(_key(lock, [[4, 3], [2, 1], []], [[], [], [4, 3, 2, 1]], {"foundation": {"locked": [4], "keys": [1], "targets": [0]}}),
			locked, "another key place")
	var seal: Array = ["classic_hanoi", "sealed_box"]
	assert_eq(_key(seal, [[1], [3, 2], []], [[], [], [3, 2, 1]], {"sealed_box": {"pegs": [1]}}),
			_key(seal, [[3, 2], [1], []], [[], [], [3, 2, 1]], {"sealed_box": {"pegs": [0]}}), "the seal stays on its box")


func test_board_shapes_limit_the_reorderings() -> void:
	var road: Array = ["classic_hanoi", "adjacent_pegs"]
	var key: String = _key(road, [[3, 2], [1], []], [[], [], [3, 2, 1]])
	assert_eq(_key(road, [[], [1], [3, 2]], [[3, 2, 1], [], []]), key, "the road read from its other end")
	assert_ne(_key(road, [[1], [3, 2], []], [[], [], [3, 2, 1]]), key, "a middle peg moved to an end is another road")
	var dial: Array = ["classic_hanoi", "cyclic"]
	var turned: String = _key(dial, [[2, 1], [], [], []], [[], [], [2, 1], []])
	assert_eq(_key(dial, [[], [2, 1], [], []], [[], [], [], [2, 1]]), turned, "the dial turned")
	assert_ne(_key(dial, [[2, 1], [], [], []], [[], [2, 1], [], []]), _key(dial, [[2, 1], [], [], []], [[], [], [], [2, 1]]),
			"clockwise one step and three steps differ (a mirror runs the other way round)")
	var scales: Array = ["classic_hanoi", "balance"]
	var params: Dictionary = {"balance": {"tolerance": 4}}
	var pair: String = _key(scales, [[3, 1], [], [2], []], [[], [3, 1], [], [2]], params)
	assert_eq(_key(scales, [[], [3, 1], [2], []], [[3, 1], [], [], [2]], params), pair, "pans of one scale swapped")
	assert_eq(_key(scales, [[2], [], [3, 1], []], [[], [2], [], [3, 1]], params), pair, "the two scales swapped")
	assert_ne(_key(scales, [[3, 1], [2], [], []], [[], [], [3, 1], [2]], params), pair, "pans of two scales mixed")


func test_the_exchange_may_swap_its_colours() -> void:
	var ids: Array = ["color_swap"]
	var params: Dictionary = {"color_swap": {"colour": true}}
	# Size s: white 2s - 1, black 2s. A start halfway: no peg order alone
	# turns one into the other, the colour swap does.
	var key: String = _key(ids, [[5, 4, 1], [2], [], [6, 3]], [[6, 4, 2], [], [], [5, 3, 1]], params)
	assert_eq(_key(ids, [[6, 3, 2], [1], [], [5, 4]], [[5, 3, 1], [], [], [6, 4, 2]], params), key,
			"colours swapped, the goal's sides too")
	assert_ne(_key(["color_swap"], [[6, 3, 2], [1], [], [5, 4]], [[6, 4, 2], [], [], [5, 3, 1]], params), key,
			"colours swapped in the start only: another puzzle")


func test_no_two_shipped_levels_are_the_same_puzzle() -> void:
	var seen: Dictionary = {}
	var levels: int = 0
	for track: String in LevelCatalog.tracks():
		for position: int in range(1, LevelCatalog.track_length(track) + 1):
			var level: Level = LevelCatalog.load_at(track, position)
			var key: String = LevelValidator.puzzle_key(level)
			assert_false(seen.has(key), "%s %d is the same puzzle as %s" % [track, position, seen.get(key, "")])
			seen[key] = "%s %d" % [track, position]
			levels += 1
	assert_eq(seen.size(), levels)
