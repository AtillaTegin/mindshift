extends "res://tests/test_case.gd"
## PuzzleState and Move data structures.


func test_hash_key_format() -> void:
	assert_eq(PuzzleState.new([[3, 2, 1], [], []]).hash_key(), "0:3,2,1|1:|2:")
	assert_eq(PuzzleState.new([[1, 3], [5], []]).hash_key(), "0:1,3|1:5|2:", "spec example")
	assert_eq(PuzzleState.new([]).hash_key(), "")


func test_hash_key_is_stable_for_equal_states() -> void:
	var a: PuzzleState = PuzzleState.new([[5, 3, 1], [4], [2], []])
	var b: PuzzleState = PuzzleState.new([[5, 3, 1], [4], [2], []])
	assert_eq(a.hash_key(), a.hash_key(), "same object twice")
	assert_eq(a.hash_key(), b.hash_key(), "equal objects")
	assert_eq(a.hash_key(), a.duplicate_state().hash_key(), "duplicate")
	assert_eq(a.hash_key(), PuzzleState.from_array([[5.0, 3.0, 1.0], [4.0], [2.0], []]).hash_key(), "from JSON floats")


func test_hash_key_has_no_collisions() -> void:
	# Every arrangement of 4 disks on 3 pegs, in any order on each peg (360).
	# Multi-digit sizes check that "1,2" and "12" etc. stay distinct.
	var states: Array[PuzzleState] = _all_arrangements([1, 2, 12, 21], 3)
	assert_eq(states.size(), 360, "arrangement count")
	var keys: Dictionary[String, bool] = {}
	for state: PuzzleState in states:
		keys[state.hash_key()] = true
	assert_eq(keys.size(), states.size(), "distinct states give distinct keys")


func test_hash_key_tricky_pairs_differ() -> void:
	var pairs: Array = [
		[[[1, 2], []], [[12], []]],
		[[[1, 2], []], [[1], [2]]],
		[[[1], []], [[], [1]]],
		[[[1], []], [[1], [], []]],
		[[[21], []], [[2, 1], []]],
		[[[], []], [[], [], []]],
	]
	for pair: Array in pairs:
		var a: PuzzleState = PuzzleState.new(pair[0])
		var b: PuzzleState = PuzzleState.new(pair[1])
		assert_ne(a.hash_key(), b.hash_key(), "%s vs %s" % [str(pair[0]), str(pair[1])])
		assert_false(a.equals(b), "equals: %s vs %s" % [str(pair[0]), str(pair[1])])


func test_equals() -> void:
	var a: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	assert_true(a.equals(PuzzleState.new([[3, 2, 1], [], []])))
	assert_true(a.equals(a))
	assert_false(a.equals(PuzzleState.new([[3, 2], [1], []])))
	assert_false(a.equals(PuzzleState.new([[3, 2, 1], []])))
	assert_false(a.equals(null))


func test_equals_compares_disk_values() -> void:
	# Same shape (one disk per peg), different disks.
	var a: PuzzleState = PuzzleState.new([[3], [2], [1]])
	var b: PuzzleState = PuzzleState.new([[3], [1], [2]])
	assert_false(a.equals(b))
	assert_ne(a.hash_key(), b.hash_key())


func test_duplicate_state_is_deep() -> void:
	var original: PuzzleState = PuzzleState.new([[3, 2], [1], []])
	var copy: PuzzleState = original.duplicate_state()
	assert_true(copy.equals(original))
	copy.pegs[2].append(copy.pegs[1].pop_back())
	assert_eq(original.to_array(), [[3, 2], [1], []], "original unchanged")
	assert_eq(copy.to_array(), [[3, 2], [], [1]])


func test_constructor_copies_input_arrays() -> void:
	var source: Array = [[3, 2], [1], []]
	var state: PuzzleState = PuzzleState.new(source)
	source[0].append(1)
	source.append([])
	assert_eq(state.to_array(), [[3, 2], [1], []])


func test_constructor_converts_floats_to_int() -> void:
	var state: PuzzleState = PuzzleState.new([[3.0, 2.0], [1.0], []])
	assert_eq(typeof(state.pegs[0][0]), TYPE_INT)
	assert_true(RuleSet.classic().is_state_valid(state))


func test_to_array_is_deep() -> void:
	var state: PuzzleState = PuzzleState.new([[3, 2], [1], []])
	var data: Array = state.to_array()
	data[0].append(9)
	data.append([])
	assert_eq(state.to_array(), [[3, 2], [1], []])


func test_get_top_disk() -> void:
	var state: PuzzleState = PuzzleState.new([[5, 3, 1], [4], []])
	assert_eq(state.get_top_disk(0), 1)
	assert_eq(state.get_top_disk(1), 4)
	assert_eq(state.get_top_disk(2), -1, "empty peg")
	assert_eq(state.get_top_disk(3), -1, "index past the end")
	assert_eq(state.get_top_disk(-1), -1, "negative index")
	# GDScript arrays wrap negative indexes; make sure -1 is not read as "last peg".
	assert_eq(PuzzleState.new([[2], [1]]).get_top_disk(-1), -1, "negative index, last peg not empty")


func test_counts() -> void:
	var state: PuzzleState = PuzzleState.new([[5, 3, 1], [4], [2], []])
	assert_eq(state.get_peg_count(), 4)
	assert_eq(state.get_disk_count(), 5)


func test_from_array_converts_json_floats_to_int() -> void:
	var parsed: Variant = JSON.parse_string("[[5,3,1],[4],[2],[]]")
	var state: PuzzleState = PuzzleState.from_array(parsed)
	assert_not_null(state)
	assert_eq(state.to_array(), [[5, 3, 1], [4], [2], []])
	assert_eq(typeof(state.pegs[0][0]), TYPE_INT)
	assert_eq(state.get_top_disk(0), 1)


func test_from_array_accepts_int_data() -> void:
	var state: PuzzleState = PuzzleState.from_array([[3, 2, 1], [], []])
	assert_not_null(state)
	assert_eq(state.to_array(), [[3, 2, 1], [], []])


func test_from_array_rejects_malformed_data() -> void:
	assert_null(PuzzleState.from_array(null))
	assert_null(PuzzleState.from_array("[[1]]"))
	assert_null(PuzzleState.from_array([1, 2]), "peg is not an array")
	assert_null(PuzzleState.from_array([["a"]]), "disk is not a number")
	assert_null(PuzzleState.from_array([[1.5]]), "disk is not integral")
	assert_null(PuzzleState.from_array([[INF]]), "disk is infinite")


func test_to_array_round_trip_through_json() -> void:
	var state: PuzzleState = PuzzleState.new([[5, 3, 1], [4], [2], []])
	var restored: PuzzleState = PuzzleState.from_array(JSON.parse_string(JSON.stringify(state.to_array())))
	assert_true(restored.equals(state))


func test_move_basics() -> void:
	var move: Move = Move.new(0, 2)
	assert_eq(move.to_array(), [0, 2])
	assert_true(move.equals(Move.new(0, 2)))
	assert_false(move.equals(Move.new(2, 0)))
	assert_false(move.equals(Move.new(1, 2)), "from differs")
	assert_false(move.equals(Move.new(0, 1)), "to differs")
	assert_false(move.equals(null))
	assert_eq(str(move), "Move(0 -> 2)")


func test_move_from_array() -> void:
	var move: Move = Move.from_array(JSON.parse_string("[1, 3]"))
	assert_not_null(move)
	assert_eq(move.from_peg, 1)
	assert_eq(move.to_peg, 3)
	var from_ints: Move = Move.from_array([2, 0])
	assert_not_null(from_ints, "int pair")
	assert_true(from_ints.equals(Move.new(2, 0)))
	assert_null(Move.from_array([INF, 1]), "infinite value")
	assert_null(Move.from_array([1]), "too short")
	assert_null(Move.from_array([1, 2, 3]), "too long")
	assert_null(Move.from_array([1, "2"]), "string value")
	assert_null(Move.from_array([0.5, 1]), "non-integral value")
	assert_null(Move.from_array(null), "null")


## All ways to place `disks` on `peg_count` pegs where the order on each peg
## matters (not limited to classic-valid stacks).
static func _all_arrangements(disks: Array, peg_count: int) -> Array[PuzzleState]:
	var empty: Array = []
	for i: int in peg_count:
		empty.append([])
	var layouts: Array = [empty]
	for disk: int in disks:
		var next_layouts: Array = []
		for layout: Array in layouts:
			for peg_index: int in peg_count:
				for position: int in layout[peg_index].size() + 1:
					var copy: Array = layout.duplicate(true)
					copy[peg_index].insert(position, disk)
					next_layouts.append(copy)
		layouts = next_layouts
	var states: Array[PuzzleState] = []
	for layout: Array in layouts:
		states.append(PuzzleState.new(layout))
	return states
