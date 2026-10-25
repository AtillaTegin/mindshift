extends "res://tests/test_case.gd"
## World 7 (MindShift_ICRA_Dunya5-9_Yeni_Modlar_v1.md, sections 3.7-3.9): the
## heavy disks' reach (cart, fatigue, uphill), the five elements (neutral
## earth, bases, creation, the turning peg) and the trail's new waves (the
## fading trail).


static func _rules(id: String, params: Dictionary) -> RuleSet:
	var ids: Array[String] = ["classic_hanoi", id]
	return RuleSet.from_ids(ids, {id: params})


func test_heavy_disks_go_their_reach() -> void:
	var heavy: RuleSet = _rules("heavy", {"reach": [0, 2, 1]})
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], [], [], []])
	assert_true(heavy.is_move_legal(start, Move.new(0, 4)), "the smallest goes any distance")
	var after: PuzzleState = heavy.apply_move(start, Move.new(0, 4))
	assert_false(heavy.is_move_legal(after, Move.new(0, 3)), "the middle one goes two pegs at most")
	assert_eq(heavy.get_violation_message(after, Move.new(0, 3)), "RULE_HEAVY")
	assert_true(heavy.is_move_legal(after, Move.new(0, 2)))
	var cart: RuleSet = _rules("heavy", {"reach": [0, 1], "cart": 2})
	var on_cart: PuzzleState = PuzzleState.new([[], [], [2], [], [1]])
	assert_true(cart.is_move_legal(on_cart, Move.new(2, 0)), "a disk leaving the cart goes any distance")
	var full: PuzzleState = PuzzleState.new([[], [1], [2], [], []])
	assert_false(cart.is_move_legal(full, Move.new(1, 2)), "the cart holds one disk")
	assert_eq(cart.get_violation_message(full, Move.new(1, 2)), "RULE_CART_FULL")
	var tired: RuleSet = _rules("heavy", {"reach": [0, 1], "fatigue": true})
	var moved: PuzzleState = tired.apply_move(PuzzleState.new([[2], [], [], [1]]), Move.new(0, 1))
	assert_false(tired.is_move_legal(moved, Move.new(1, 2)), "a disk of reach 1 never moves twice in a row")
	assert_eq(tired.get_violation_message(moved, Move.new(1, 2)), "RULE_FATIGUE")
	assert_true(tired.is_move_legal(tired.apply_move(moved, Move.new(3, 0)), Move.new(1, 2)), "after another disk it may")
	var uphill: RuleSet = _rules("heavy", {"reach": [0, 2], "uphill": true})
	var middle: PuzzleState = PuzzleState.new([[], [1], [2], [], []])
	assert_true(uphill.is_move_legal(middle, Move.new(2, 0)), "to the left the whole reach")
	assert_false(uphill.is_move_legal(middle, Move.new(2, 4)), "to the right half of it")
	assert_true(uphill.is_move_legal(middle, Move.new(2, 3)))


func test_elements_defeat_and_create() -> void:
	# Disks 1-5: Wood, Fire, Earth, Metal, Water.
	var elements: Array = [ElementsRule.WOOD, ElementsRule.FIRE, ElementsRule.EARTH, ElementsRule.METAL, ElementsRule.WATER]
	var wuxing: RuleSet = _rules("elements", {"elements": elements})
	var state: PuzzleState = PuzzleState.new([[4], [1], [5]])
	assert_false(wuxing.is_move_legal(state, Move.new(1, 0)), "Metal defeats Wood: Wood never goes onto Metal")
	assert_eq(wuxing.get_violation_message(state, Move.new(1, 0)), "RULE_ELEMENT")
	assert_true(wuxing.is_move_legal(state, Move.new(1, 2)), "Wood onto Water")
	var earth: Array = [ElementsRule.EARTH, ElementsRule.WOOD]
	var plain: RuleSet = _rules("elements", {"elements": earth})
	var neutral: RuleSet = _rules("elements", {"elements": earth, "earth": true})
	var pair: PuzzleState = PuzzleState.new([[2], [1], []])
	assert_false(plain.is_move_legal(pair, Move.new(1, 0)), "Wood defeats Earth")
	assert_true(neutral.is_move_legal(pair, Move.new(1, 0)), "neutral Earth touches every element")
	var based: RuleSet = _rules("elements", {"elements": [ElementsRule.WOOD, ElementsRule.FIRE], "bases": [ElementsRule.METAL, -1, -1]})
	var lone: PuzzleState = PuzzleState.new([[], [2, 1], []])
	assert_false(based.is_move_legal(lone, Move.new(1, 0)), "the Metal base counts as a disk under Wood")
	assert_eq(based.get_violation_message(lone, Move.new(1, 0)), "RULE_ELEMENT_BASE")
	var creation: RuleSet = _rules("elements", {"elements": [ElementsRule.FIRE, ElementsRule.WOOD, ElementsRule.WATER], "creation": true})
	var spread: PuzzleState = PuzzleState.new([[2], [1], [3]])
	assert_true(creation.is_move_legal(spread, Move.new(1, 0)), "Wood creates Fire")
	assert_false(creation.is_move_legal(spread, Move.new(1, 2)), "Water does not create Fire")
	assert_eq(creation.get_violation_message(spread, Move.new(1, 2)), "RULE_CREATION")
	var turning: RuleSet = _rules("elements", {"elements": [ElementsRule.WOOD, ElementsRule.WOOD], "turning": 1})
	var turned: PuzzleState = turning.apply_move(turning.prepared(PuzzleState.new([[2, 1], [], []])), Move.new(0, 1))
	var rule: ElementsRule = turning.memory_rule() as ElementsRule
	assert_eq(rule.element_of(1, turning.memory_of(turned)), ElementsRule.FIRE, "the turning peg makes Wood Fire")
	assert_eq(rule.element_of(2, turning.memory_of(turned)), ElementsRule.WOOD)


func test_a_fading_trail_counts_moves() -> void:
	var trail: RuleSet = _rules("trail", {"disk": 1, "fade": 2})
	var rule: TrailRule = trail.memory_rule() as TrailRule
	var state: PuzzleState = trail.prepared(PuzzleState.new([[2, 1], [], [], []]))
	state = trail.apply_move(state, Move.new(0, 1))
	assert_eq(rule.fade_left(trail.memory_of(state), 0, 0, 4), 2, "the peg it left is marked for two moves")
	state = trail.apply_move(state, Move.new(0, 2))
	assert_eq(rule.fade_left(trail.memory_of(state), 0, 0, 4), 1, "one move older")
	assert_false(trail.is_move_legal(state, Move.new(1, 0)), "the mark still keeps the disk out")
	assert_eq(trail.get_violation_message(state, Move.new(1, 0)), "RULE_TRAIL")
	state = trail.apply_move(state, Move.new(2, 3))
	assert_true(trail.is_move_legal(state, Move.new(1, 0)), "two moves later the mark has faded")
	var clean: RuleSet = _rules("trail", {"disk": 1, "fade": 3, "clean": 0})
	var left: PuzzleState = clean.apply_move(clean.prepared(PuzzleState.new([[2, 1], [], []])), Move.new(0, 1))
	assert_eq((clean.memory_rule() as TrailRule).fade_left(clean.memory_of(left), 0, 0, 3), 0, "the clean peg keeps no mark")
	allow_engine_errors = true
	assert_null(RuleSet.from_ids(["classic_hanoi", "trail"] as Array[String], {"trail": {"disk": 1, "recent": 2, "fade": 3}}),
			"a trail fades one way only")
	# On three pegs a mark that lasts four moves is longer than the base trail.
	var start: PuzzleState = PuzzleState.new([[4, 3, 2, 1], [], []])
	var goal: PuzzleState = PuzzleState.new([[], [], [4, 3, 2, 1]])
	var base: Dictionary = Solver.solve(start, goal, _rules("trail", {"disk": 1, "recent": 2}), 200000)
	var faded: Dictionary = Solver.solve(start, goal, _rules("trail", {"disk": 1, "fade": 4}), 200000)
	assert_true(faded["solvable"])
	assert_true(faded["min_moves"] >= base["min_moves"], "%d vs %d" % [faded["min_moves"], base["min_moves"]])
