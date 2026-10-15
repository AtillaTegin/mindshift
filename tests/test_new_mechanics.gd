extends "res://tests/test_case.gd"
## The new mechanics of specification v1 (2026-10-15): their rules, their pilot
## levels on the main road (3-4 each), and how the board shows them.

const SAVE_PATH: String = "res://.test_saves/test_new_mechanics_save.json"
const MAIN: String = LevelCatalog.MAIN
const PILOTS: Array[String] = ["peg_capacity", "foundation", "balance", "cyclic", "stripes", "chain", "mirror", "trail"]

var _board: GameBoard


func after_each() -> void:
	if _board != null:
		_board.get_parent().remove_child(_board)
		_board.free()
		_board = null
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _start_board(level: Level) -> GameBoard:
	_board = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	_board.save_system = SaveSystem.new(SAVE_PATH)
	_board.tutorials_enabled = false
	_board.background_hints = false
	(Engine.get_main_loop() as SceneTree).root.add_child(_board)
	_board.start_level(level)
	(_board.get_node("%Board") as Control).size = Vector2(672.0, 700.0)
	return _board


func _rules(id: String, params: Dictionary = {}) -> RuleSet:
	return RuleSet.from_ids(["classic_hanoi", id], {id: params} if not params.is_empty() else {})


## The pilot levels of `mechanic` on the main road, in road order.
func _pilots(mechanic: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for position: int in range(1, LevelCatalog.track_length(MAIN) + 1):
		if LevelCatalog.mechanic_at(MAIN, position) == mechanic:
			found.append({"position": position, "level": LevelCatalog.load_at(MAIN, position)})
	return found


func test_capacity_rule() -> void:
	var rules: RuleSet = _rules(PegCapacityRule.ID, {"capacities": [3, 1, 3]})
	var state: PuzzleState = PuzzleState.new([[3], [2], [1]])
	assert_false(rules.is_move_legal(state, Move.new(2, 1)), "1 fits on 2, but the short peg is full")
	assert_eq(rules.get_violation_message(state, Move.new(2, 1)), "RULE_PEG_FULL")
	assert_true(rules.is_move_legal(state, Move.new(2, 0)))
	assert_false(rules.is_state_valid(PuzzleState.new([[3], [2, 1], []])), "over capacity")
	assert_false(rules.is_state_valid(PuzzleState.new([[3], [], [], [2, 1]])), "one capacity per peg")
	assert_null(RuleSet.from_ids(["peg_capacity"], {"peg_capacity": {"capacities": [0, 2]}}))


func test_foundation_opens_once_and_stays_open() -> void:
	var rules: RuleSet = _rules(FoundationRule.ID, {"locked": [4], "keys": [1, 2], "targets": [2, 2]})
	var start: PuzzleState = PuzzleState.new([[4, 3, 2, 1], [], []])
	assert_eq(rules.memory_of(start), 0, "locked at the start")
	var state: PuzzleState = rules.apply_move(start, Move.new(0, 1))  # 1 -> peg 1
	state = rules.apply_move(state, Move.new(0, 2))  # 2 -> peg 2
	assert_eq(state.memory, 0)
	assert_false(rules.is_move_legal(PuzzleState.new([[4], [3], [2, 1]]), Move.new(0, 1)), "the lock holds the big disk")
	state = rules.apply_move(state, Move.new(1, 2))  # 1 onto 2 on peg 2: both keys in place
	assert_eq(state.memory, 1, "the foundation is laid")
	state = rules.apply_move(state, Move.new(2, 1))  # a key leaves again
	assert_eq(state.memory, 1, "opened once, open for good")
	var locked: PuzzleState = PuzzleState.new([[4, 3], [1], [2]])
	assert_false(rules.can_pick_up(locked, 0) and locked.get_top_disk(0) == 4)
	assert_eq(rules.get_pick_up_violation_message(PuzzleState.new([[4], [3, 1], [2]]), 0), "RULE_FOUNDATION")


func test_balance_keeps_every_pair_within_its_tolerance() -> void:
	var rules: RuleSet = _rules(BalanceRule.ID, {"tolerance": 2})
	var state: PuzzleState = PuzzleState.new([[3], [2], [4, 1], [5]])
	assert_true(rules.is_state_valid(state))
	assert_false(rules.is_state_valid(PuzzleState.new([[5, 3], [], [4, 1], [2]])), "a pair tipped too far")
	assert_false(rules.is_move_legal(state, Move.new(1, 0)), "2 onto 3 tips the first pair by 5")
	assert_eq(rules.get_violation_message(state, Move.new(1, 0)), "RULE_BALANCE")
	assert_true(rules.is_move_legal(state, Move.new(2, 1)), "1 to peg 1: 3 / 3 and 4 / 5")
	assert_false(rules.is_state_valid(PuzzleState.new([[1], [], []])), "pegs come in pairs")
	assert_eq(BalanceRule.pan_of(2), 3)
	assert_eq(BalanceRule.pan_of(3), 2)


func test_cyclic_moves_only_clockwise_to_the_next_peg() -> void:
	var rules: RuleSet = _rules(CyclicRule.ID)
	var state: PuzzleState = PuzzleState.new([[2, 1], [], [], []])
	assert_true(rules.is_move_legal(state, Move.new(0, 1)))
	assert_false(rules.is_move_legal(state, Move.new(0, 3)), "not back")
	assert_false(rules.is_move_legal(state, Move.new(0, 2)), "no jumps")
	assert_eq(rules.get_violation_message(state, Move.new(0, 3)), "RULE_CYCLIC")
	assert_true(rules.is_move_legal(PuzzleState.new([[], [], [], [1]]), Move.new(3, 0)), "the last peg leads to the first")
	# Known values of the cyclic tower of Hanoi: 3 disks to the next peg 15, two on 21.
	assert_eq(Solver.solve(PuzzleState.new([[3, 2, 1], [], []]), PuzzleState.new([[], [3, 2, 1], []]), rules)["min_moves"], 15)
	assert_eq(Solver.solve(PuzzleState.new([[3, 2, 1], [], []]), PuzzleState.new([[], [], [3, 2, 1]]), rules)["min_moves"], 21)


func test_stripes_never_put_one_colour_on_itself() -> void:
	var rules: RuleSet = _rules(StripesRule.ID)
	var state: PuzzleState = PuzzleState.new([[5, 3], [4], [1]])
	assert_false(rules.is_state_valid(state), "5 and 3 share a colour")
	state = PuzzleState.new([[5], [4, 3], [1]])
	assert_false(rules.is_move_legal(state, Move.new(2, 1)), "1 onto 3: both odd")
	assert_eq(rules.get_violation_message(state, Move.new(2, 1)), "RULE_STRIPES")
	assert_false(rules.is_move_legal(state, Move.new(1, 0)), "3 onto 5: both odd")
	assert_true(rules.is_move_legal(PuzzleState.new([[5], [4], [1]]), Move.new(1, 0)), "4 onto 5")


func test_chained_disks_move_only_together() -> void:
	var rules: RuleSet = _rules(ChainRule.ID, {"disks": [1, 3]})
	var state: PuzzleState = PuzzleState.new([[4, 3], [2, 1], [], []])
	assert_false(rules.is_move_legal(state, Move.new(1, 2)), "a chained disk never moves alone")
	assert_eq(rules.get_violation_message(state, Move.new(1, 2)), "RULE_CHAIN")
	var together: Move = Move.new(1, 2, 0, 3)
	assert_true(rules.is_move_legal(state, together), "1 and 3 at once")
	var after: PuzzleState = rules.apply_move(state, together)
	assert_true(after.equals(PuzzleState.new([[4], [2], [1], [3]])))
	assert_false(rules.is_move_legal(state, Move.new(1, 2, 0, 2)), "two different targets")
	assert_true(rules.get_legal_moves(state).any(func(move: Move) -> bool: return move.is_compound()))
	assert_false(rules.can_pick_up(PuzzleState.new([[4, 3, 2], [1], [], []]), 1), "the partner is not on top")
	# Level JSON keeps compound moves as four numbers.
	assert_eq(together.to_array(), [1, 2, 0, 3])
	assert_true(Move.from_array([1.0, 2.0, 0.0, 3.0]).equals(together))
	assert_null(Move.from_array([1, 2, 3]))
	# Reachable only by moving the chain: 3 to 4, 1 to 2, swapping the stacks' tops.
	var result: Dictionary = Solver.solve(state, PuzzleState.new([[2, 1], [4, 3], [], []]), rules)
	assert_true(result["solvable"], "a way exists")
	assert_true((result["path"] as Array).any(func(move: Move) -> bool: return move.is_compound()), "the solver moves the chain")
	assert_false(Solver.solve(PuzzleState.new([[4, 2], [3, 1], [], []]), PuzzleState.new([[], [], [4, 3], [2, 1]]), rules)["solvable"],
			"1 sits on its own partner: the chain can never move")


func test_mirror_boards_are_separate() -> void:
	var rules: RuleSet = _rules(MirrorRule.ID)
	var state: PuzzleState = PuzzleState.new([[2, 1], [], [], [4, 3], [], []])
	assert_false(rules.is_move_legal(state, Move.new(0, 4)), "never to the other board")
	assert_eq(rules.get_violation_message(state, Move.new(0, 4)), "RULE_MIRROR")
	assert_true(rules.is_move_legal(state, Move.new(3, 5)))
	var goal: PuzzleState = PuzzleState.new([[], [], [2, 1], [], [4, 3], []])
	var result: Dictionary = Solver.solve(state, goal, rules)
	assert_eq(result["strategy"], "split", "each board solved on its own")
	assert_eq(result["min_moves"], 6, "3 + 3")


func test_trail_remembers_its_last_two_pegs() -> void:
	var rules: RuleSet = _rules(TrailRule.ID, {"disk": 1, "recent": 2})
	var start: PuzzleState = PuzzleState.new([[3, 2, 1], [], []])
	assert_eq(rules.memory_of(start), 1, "the start peg is on the trail")
	var state: PuzzleState = rules.apply_move(start, Move.new(0, 1))
	assert_false(rules.is_move_legal(state, Move.new(1, 0)), "not back to its last peg")
	assert_eq(rules.get_violation_message(state, Move.new(1, 0)), "RULE_TRAIL")
	assert_true(rules.is_move_legal(state, Move.new(1, 2)))
	state = rules.apply_move(state, Move.new(1, 2))
	assert_false(rules.is_move_legal(state, Move.new(2, 1)), "the peg before is still remembered")
	assert_true(rules.is_move_legal(state, Move.new(2, 0)), "two pegs back is free again")
	var whole: RuleSet = _rules(TrailRule.ID, {"disk": 1})
	var walked: PuzzleState = whole.apply_move(whole.apply_move(start, Move.new(0, 1)), Move.new(1, 2))
	assert_false(whole.is_move_legal(walked, Move.new(2, 0)), "the whole history remembers every peg")


func test_magnet_faces_turn_and_repel() -> void:
	var rules: RuleSet = _rules(MagnetRule.ID)
	var start: PuzzleState = PuzzleState.new([[2], [1], []])
	assert_false(rules.is_move_legal(start, Move.new(1, 0)), "both show red: the touching faces repel")
	assert_eq(rules.get_violation_message(start, Move.new(1, 0)), "RULE_MAGNET")
	var state: PuzzleState = rules.apply_move(start, Move.new(0, 2))  # 2 turns over: blue up
	assert_true(MagnetRule.blue_up(state.memory, 2))
	assert_true(rules.is_move_legal(state, Move.new(1, 2)), "1 shows red, 2 blue: they attract")
	assert_eq(Solver.solve(PuzzleState.new([[3, 2, 1], [], []]), PuzzleState.new([[], [], [3, 2, 1]]), rules)["min_moves"], 11)
	assert_true(_pilots(MagnetRule.ID).is_empty(), "no magnet level until the user decides where they go")


func test_each_pilot_chapter_is_on_the_road() -> void:
	for mechanic: String in PILOTS:
		var road: Array[Dictionary] = _pilots(mechanic)
		assert_true(road.size() >= 3 and road.size() <= 4, "%s: 3-4 pilots (%d)" % [mechanic, road.size()])
		assert_eq(road[0]["position"], PathBuilder.CHAPTER_STARTS[mechanic], "%s starts at its slot" % mechanic)
		var previous: int = 0
		for entry: Dictionary in road:
			var level: Level = entry["level"]
			assert_true(level.min_moves >= previous, "%s: easiest first" % mechanic)
			previous = level.min_moves
			assert_true(level.min_moves <= 33, "on the main road")
			var errors: Array[String] = []
			LevelValidator.validate_mechanic_design(level, errors)
			assert_eq(errors, [] as Array[String], "%s main %d" % [mechanic, entry["position"]])
		assert_true(TutorialDirector.is_mechanic_intro(road[0]["level"]), "%s is introduced" % mechanic)


func test_hints_off_the_path_are_found() -> void:
	for mechanic: String in PILOTS:
		for entry: Dictionary in _pilots(mechanic):
			var level: Level = entry["level"]
			var session: GameSession = GameSession.new(level)
			var off: Move = null
			for move: Move in session.rules.get_legal_moves(session.state):
				if not move.equals(level.solution_path[0]):
					off = move
					break
			if off == null:
				continue
			session.try_move(off)
			var hint: Move = GameSession.solve_hint(level, session.state.duplicate_state(), session.rules)
			if hint == null:
				assert_not_null(session.return_to_path_move(), "%s main %d: a hint or a way back" % [mechanic, entry["position"]])
			else:
				assert_true(session.rules.is_move_legal(session.state, hint), "%s main %d: a legal hint" % [mechanic, entry["position"]])


func test_board_shows_each_mechanic() -> void:
	# Unequal capacity: each rod as tall as its capacity.
	var capacity: Level = _pilots(PegCapacityRule.ID)[0]["level"]
	_start_board(capacity)
	var rods: Array[float] = []
	for peg: PegView in _board.get_node("%PegLayer").get_children():
		rods.append(peg.base_top - peg.rod_top)
	var caps: Array[int] = (capacity.get_rule_set().active_rules[1] as PegCapacityRule).capacities
	for i: int in caps.size():
		for j: int in caps.size():
			if caps[i] > caps[j]:
				assert_true(rods[i] > rods[j], "a taller rod holds more (%d vs %d)" % [i, j])
	assert_eq(_board.get_board_skin().skin, "temple")
	_board.free()
	_board = null
	# Cyclic: pegs around a circle, clockwise from the top.
	var cyclic: Level = _pilots(CyclicRule.ID)[0]["level"]
	_start_board(cyclic)
	var pegs: Array[Node] = _board.get_node("%PegLayer").get_children()
	var top: PegView = pegs[0]
	for peg: PegView in pegs:
		assert_true(top.position.y <= peg.position.y, "peg 0 stands at the top")
	assert_true((pegs[1] as PegView).position.x > top.position.x, "peg 1 to the right of it: clockwise")
	_board.free()
	_board = null
	# Twin boards: two rows, each board numbering its own disks from 1.
	var mirror: Level = _pilots(MirrorRule.ID)[0]["level"]
	_start_board(mirror)
	var rows: Dictionary = {}
	for peg: PegView in _board.get_node("%PegLayer").get_children():
		rows[peg.position.y] = true
	assert_eq(rows.size(), 2, "one board above the other")
	var first: int = BoardDress.first_board_disks(mirror)
	for view: DiskView in _board.get_node("%DiskLayer").get_children():
		assert_eq(view.label, view.disk_size if view.disk_size <= first else view.disk_size - first, "disk %d" % view.disk_size)
	_board.free()
	_board = null
	# Stripes: two colours by parity.
	var stripes: Level = _pilots(StripesRule.ID)[0]["level"]
	_start_board(stripes)
	for view: DiskView in _board.get_node("%DiskLayer").get_children():
		assert_eq(view.color, ThemeManager.STRIPE_DISKS["odd" if view.disk_size % 2 == 1 else "even"]["fill"])


func test_a_refused_move_says_why_and_a_chain_takes_two_targets() -> void:
	var chain: Level = _pilots(ChainRule.ID)[0]["level"]
	_start_board(chain)
	var status: Label = _board.get_node("%StatusLabel")
	var move: Move = chain.solution_path.filter(func(m: Move) -> bool: return m.is_compound())[0]
	# Play up to the first compound move, then make it by taps.
	for step: Move in chain.solution_path:
		if step == move:
			break
		_board.session.try_move(step)
	_board.on_peg_pressed(move.from_peg)
	assert_eq(_board.session.get_selected_disks().size(), 2, "both chained disks are picked up")
	_board.on_peg_pressed(move.to_peg)
	assert_eq(_board.session.pending_target, move.to_peg)
	assert_eq(status.text, tr("CHAIN_SECOND_TARGET"))
	var count: int = _board.session.move_count
	_board.on_peg_pressed(move.to_peg_2)
	assert_eq(_board.session.move_count, count + 1, "one compound move")
	assert_true(_board.session.undo(), "and it can be taken back")
	_board.free()
	_board = null
	# Cyclic: a move the size rule allows but not clockwise to the next peg.
	var cyclic: Level = _pilots(CyclicRule.ID)[0]["level"]
	_start_board(cyclic)
	status = _board.get_node("%StatusLabel")
	var pegs: int = cyclic.get_peg_count()
	var wrong: Move = null
	for from: int in pegs:
		var disk: int = cyclic.start.get_top_disk(from)
		for to: int in pegs:
			var top: int = cyclic.start.get_top_disk(to)
			if disk != -1 and to != from and to != (from + 1) % pegs and (top == -1 or top > disk):
				wrong = Move.new(from, to)
	assert_not_null(wrong, "a move against the clock")
	_board.on_peg_pressed(wrong.from_peg)
	_board.on_peg_pressed(wrong.to_peg)
	assert_eq(status.text, tr("RULE_CYCLIC"), "the broken rule in words")
	assert_eq(status.theme_type_variation, &"SecondaryLabel", "said calmly")
