extends "res://tests/test_case.gd"
## World 8-9 (MindShift_ICRA_Dunya5-9_Yeni_Modlar_v1.md, sections 3.10-3.14):
## Cəm's sums, the turns of Növbə, Kintsugi's cracked disks and workshops, the
## lamp's light and Pasyans' runs.


static func _rules(id: String, params: Dictionary) -> RuleSet:
	var ids: Array[String] = ["classic_hanoi", id]
	return RuleSet.from_ids(ids, {id: params})


func test_sums_set_the_goal() -> void:
	var sums: RuleSet = _rules("sum", {"sums": [3, 0, 3]})
	assert_not_null(sums.goal_rule())
	assert_true(sums.is_goal_state(PuzzleState.new([[3], [], [2, 1]]), null))
	assert_true(sums.is_goal_state(PuzzleState.new([[2, 1], [], [3]]), null), "any disks with those sums")
	assert_false(sums.is_goal_state(PuzzleState.new([[3, 2, 1], [], []]), null))
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	assert_eq(Solver.solve(start, start, sums, 100000)["min_moves"], 3, "1 aside, 2 over, 1 onto it")
	var counted: RuleSet = _rules("sum", {"sums": [3, 0, 3], "counts": [1, 0, 2]})
	assert_true(counted.is_goal_state(PuzzleState.new([[3], [], [2, 1]]), null))
	assert_false(counted.is_goal_state(PuzzleState.new([[2, 1], [], [3]]), null), "the counts too")
	var doubled: RuleSet = _rules("sum", {"sums": [6, 0, 3], "double": 0})
	assert_true(doubled.is_goal_state(PuzzleState.new([[3], [], [2, 1]]), null), "the doubled peg's 3 counts 6")
	var fair: RuleSet = _rules("sum", {"fair": true})
	assert_true(fair.is_goal_state(PuzzleState.new([[3], [2, 1]]), null), "equal sums")
	assert_false(fair.is_goal_state(PuzzleState.new([[3], [2, 1], []]), null))


func test_turns_take_turns() -> void:
	# Disk 1 white, 2 black, 3 white; white first.
	var turns: RuleSet = _rules("turns", {"colours": [TurnsRule.WHITE, TurnsRule.BLACK, TurnsRule.WHITE]})
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	assert_true(turns.is_move_legal(start, Move.new(0, 1)))
	var after: PuzzleState = turns.apply_move(start, Move.new(0, 1))
	assert_false(turns.is_move_legal(after, Move.new(1, 2)), "black's turn now")
	assert_eq(turns.get_violation_message(after, Move.new(1, 2)), "RULE_TURN_BLACK")
	assert_true(turns.is_move_legal(after, Move.new(0, 2)))
	var grey: RuleSet = _rules("turns", {"colours": [TurnsRule.GREY, TurnsRule.BLACK, TurnsRule.WHITE]})
	var passed: PuzzleState = grey.apply_move(grey.prepared(start), Move.new(0, 1))
	assert_true(grey.is_move_legal(passed, Move.new(0, 2)), "the grey disk took white's turn, black follows")
	assert_true(grey.is_move_legal(passed, Move.new(1, 2)), "the grey disk moves in any turn")
	var double: RuleSet = _rules("turns", {"colours": [TurnsRule.WHITE, TurnsRule.WHITE, TurnsRule.BLACK],
			"order": [TurnsRule.WHITE, TurnsRule.WHITE, TurnsRule.BLACK, TurnsRule.BLACK]})
	var once: PuzzleState = double.apply_move(double.prepared(PuzzleState.new([[3], [2], [1]])), Move.new(2, 0))
	assert_true(double.is_move_legal(once, Move.new(1, 2)), "white moves twice")
	var passer: RuleSet = _rules("turns", {"colours": [TurnsRule.BLACK, TurnsRule.WHITE], "pass": true})
	var stuck: PuzzleState = passer.prepared(PuzzleState.new([[2, 1], [], []]))
	assert_false(passer.is_move_legal(stuck, Move.new(0, 1)), "white's turn, the white disk is covered")
	assert_true(passer.is_move_legal(stuck, Move.new(0, 0)), "the pass")
	var black: PuzzleState = passer.apply_move(stuck, Move.new(0, 0))
	assert_eq(black.pegs, stuck.pegs, "a pass moves no disk")
	assert_true(passer.is_move_legal(black, Move.new(0, 1)), "black's turn after the pass")
	assert_false(passer.is_move_legal(black, Move.new(0, 0)), "only one pass a level")


func test_kintsugi_cracks_and_mends() -> void:
	var kintsugi: RuleSet = _rules("kintsugi", {"cracked": [3], "workshops": [3]})
	var state: PuzzleState = kintsugi.prepared(PuzzleState.new([[3], [2], [1], []]))
	var carried: PuzzleState = kintsugi.apply_move(state, Move.new(1, 0))
	assert_false(kintsugi.is_move_legal(carried, Move.new(2, 0)), "a cracked disk carries one disk at most")
	assert_eq(kintsugi.get_violation_message(carried, Move.new(2, 0)), "RULE_CRACKED")
	var mended: PuzzleState = kintsugi.apply_move(state, Move.new(0, 3))
	assert_true((kintsugi.memory_rule() as KintsugiRule).is_mended(kintsugi.memory_of(mended), 3), "the workshop mends it")
	var stacked: PuzzleState = kintsugi.apply_move(kintsugi.apply_move(mended, Move.new(1, 3)), Move.new(2, 3))
	assert_eq(stacked.pegs[3], [3, 2, 1], "mended, it carries anything")
	var deep: RuleSet = _rules("kintsugi", {"cracked": [3], "workshops": [3], "deep": true})
	assert_false(deep.is_move_legal(deep.prepared(PuzzleState.new([[3], [2], [1], []])), Move.new(1, 0)), "nothing on a deep crack")
	assert_eq(deep.get_violation_message(PuzzleState.new([[3], [2], [1], []]), Move.new(1, 0)), "RULE_DEEP_CRACK")
	var ordered: RuleSet = _rules("kintsugi", {"cracked": [2, 3], "workshops": [3], "ordered": true})
	var pair: PuzzleState = ordered.prepared(PuzzleState.new([[3], [2], [1], []]))
	assert_false(ordered.is_move_legal(pair, Move.new(1, 3)), "the larger cracked disk is mended first")
	assert_eq(ordered.get_violation_message(pair, Move.new(1, 3)), "RULE_REPAIR_ORDER")
	var single: RuleSet = _rules("kintsugi", {"cracked": [2, 3], "workshops": [3], "single": true})
	var once: PuzzleState = single.apply_move(single.prepared(PuzzleState.new([[3], [2], [1], []])), Move.new(0, 3))
	var rule: KintsugiRule = single.memory_rule() as KintsugiRule
	assert_true(rule.is_closed(single.memory_of(once), 3), "the workshop closes after one disk")
	assert_false(rule.is_mended(single.memory_of(single.apply_move(once, Move.new(1, 3))), 2))
	# Classic: a tower of three over four pegs in 5 moves; the cracked largest
	# must visit the workshop first (the search reads where it lies).
	var tower: Dictionary = Solver.solve(PuzzleState.new([[3, 2, 1], [], [], []]), PuzzleState.new([[], [], [3, 2, 1], []]),
			kintsugi, 200000)
	assert_true(tower["min_moves"] > 5, "the crack makes the tower longer (%d)" % tower["min_moves"])


func test_the_lamp_lights_its_neighbours() -> void:
	var lamp: RuleSet = _rules("lamp", {"start": 0})
	var start: PuzzleState = PuzzleState.new([[2, 1], [], [], [], []])
	assert_true(lamp.is_move_legal(start, Move.new(0, 1)))
	assert_false(lamp.is_move_legal(start, Move.new(0, 3)), "peg 3 is dark")
	assert_eq(lamp.get_violation_message(start, Move.new(0, 3)), "RULE_DARK")
	var lit: PuzzleState = lamp.apply_move(start, Move.new(0, 1))
	assert_true(lamp.is_move_legal(lit, Move.new(0, 2)), "the lamp went with the disk to peg 1")
	assert_true(_rules("lamp", {"start": 0, "radius": 2}).is_move_legal(start, Move.new(0, 2)), "a long light reaches two pegs")
	assert_true(_rules("lamp", {"start": 0, "fixed": 4}).is_move_legal(start, Move.new(0, 4)), "the lantern's peg is always lit")
	var carried: RuleSet = _rules("lamp", {"start": 0, "carrier": 2})
	var away: PuzzleState = carried.apply_move(PuzzleState.new([[2], [1], [], [], []]), Move.new(1, 2))
	assert_false(carried.is_move_legal(away, Move.new(2, 3)), "the lamp stays with disk 2 on peg 0")
	var two: RuleSet = _rules("lamp", {"start": 0, "two": true})
	var walked: PuzzleState = two.apply_move(two.apply_move(two.prepared(PuzzleState.new([[3, 2, 1], [], [], [], []])),
			Move.new(0, 1)), Move.new(1, 2))
	assert_true(two.is_move_legal(walked, Move.new(0, 1)), "the lamp before still lights peg 0")


func test_solitaire_runs() -> void:
	var solitaire: RuleSet = _rules("solitaire", {})
	var state: PuzzleState = PuzzleState.new([[3], [1], [2], []])
	assert_false(solitaire.is_move_legal(state, Move.new(1, 0)), "1 only onto 2")
	assert_eq(solitaire.get_violation_message(state, Move.new(1, 0)), "RULE_SOLITAIRE")
	assert_true(solitaire.is_move_legal(state, Move.new(1, 2)))
	assert_true(solitaire.is_move_legal(state, Move.new(1, 3)), "or onto an empty peg")
	var cell: RuleSet = _rules("solitaire", {"cell": 3})
	var parked: PuzzleState = cell.apply_move(PuzzleState.new([[3], [2], [1], []]), Move.new(0, 3))
	assert_false(cell.is_move_legal(parked, Move.new(2, 3)), "the cell holds one disk")
	assert_eq(cell.get_violation_message(parked, Move.new(2, 3)), "RULE_CELL_FULL")
	var colours: RuleSet = _rules("solitaire", {"colours": [0, 0, 1]})
	assert_false(colours.is_move_legal(state, Move.new(1, 2)), "1 and 2 share a colour")
	assert_eq(colours.get_violation_message(state, Move.new(1, 2)), "RULE_RED_BLACK")
	assert_true(colours.is_move_legal(PuzzleState.new([[3], [2], [1], []]), Move.new(1, 0)), "2 and 3 take turns")
	var arch: RuleSet = _rules("solitaire", {"arches": [0, 0, 0, 2]})
	var spread: PuzzleState = PuzzleState.new([[3], [2], [1], []])
	assert_false(arch.is_move_legal(spread, Move.new(0, 3)), "3 is wider than the arch of 2")
	assert_eq(arch.get_violation_message(spread, Move.new(0, 3)), "RULE_ARCH")
	assert_true(arch.is_move_legal(spread, Move.new(1, 3)))
	var narrow: RuleSet = _rules("solitaire", {"limits": [0, 0, 0, 1]})
	var filled: PuzzleState = narrow.apply_move(spread, Move.new(0, 3))
	assert_false(narrow.is_move_legal(filled, Move.new(2, 3)), "the narrow tower holds one disk")
	assert_eq(narrow.get_violation_message(filled, Move.new(2, 3)), "RULE_NARROW_FULL")


func test_arch_changes_the_solution() -> void:
	# Measured 2026-10-25 (BFS): this 4 peg / 4 disk board takes 6 moves; an arch of 1 over the
	# spare peg 3 makes it 9. A narrow tower only changes a level the forge draws for it
	# (LevelForge.variants_matter): on 4 pegs a limit of 1-2 on one spare peg left 6.
	var start: PuzzleState = PuzzleState.new([[4, 3], [2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[], [], [4, 3, 2, 1], []])
	assert_eq(_length(start, goal, {}), 6)
	assert_eq(_length(start, goal, {"arches": [0, 0, 0, 1]}), 9)
	assert_eq(_length(start, goal, {"limits": [0, 0, 0, 1]}), 6, "a narrow tower never shortens a solution")


func _length(start: PuzzleState, goal: PuzzleState, params: Dictionary) -> int:
	return int(Solver.solve(start, goal, _rules("solitaire", params))["min_moves"])
