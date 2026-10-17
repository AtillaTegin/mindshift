extends "res://tests/test_case.gd"
## The dead-end rule (Mod Kataloqu v1.1, D.3: nobody loses): only levels whose
## rules can leave the goal out of reach are watched; a dead end is proved,
## said kindly, and a free way back leads to the last position that can still
## be solved.

const SAVE_PATH: String = "res://.test_saves/test_dead_end.json"
## A mixed exchange board of the old chapter (4 pegs / 6 disks) where random
## play often runs into a dead end.
const START: Array = [[5, 4, 2], [], [], [6, 3, 1]]
const GOAL: Array = [[6, 4, 2], [], [], [5, 3, 1]]
## Positions explored at most when a sample level is searched to the end.
const CLOSURE_LIMIT: int = 20000

var _nodes: Array[Node] = []


func after_each() -> void:
	for node: Node in _nodes:
		node.get_parent().remove_child(node)
		node.free()
	_nodes.clear()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


static func _mixed_level() -> Level:
	var rule_ids: Array[String] = [ColorSwapRule.ID]
	return make_level(19101, rule_ids, START, GOAL, {ColorSwapRule.ID: {"colour": true}})


## Seeded random play on `level` until a move leaves the goal out of reach:
## the moves, the last one entering the dead end; [] if none was found.
static func _dead_line(level: Level) -> Array[Move]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for walk: int in 40:
		var session: GameSession = GameSession.new(level)
		var line: Array[Move] = []
		for step: int in 30:
			var moves: Array[Move] = session.rules.get_legal_moves(session.state)
			if moves.is_empty() or session.is_solved():
				break
			var move: Move = moves[rng.randi_range(0, moves.size() - 1)]
			session.try_move(move)
			line.append(move)
			if not session.is_solved() and GameSession.is_dead_end(level, session.state, session.rules):
				return line
	return [] as Array[Move]


func _board_for(level: Level) -> GameBoard:
	var board: GameBoard = (load("res://scenes/game_board.tscn") as PackedScene).instantiate()
	board.save_system = SaveSystem.new(SAVE_PATH)
	board.tutorials_enabled = false
	board.background_hints = false
	(Engine.get_main_loop() as SceneTree).root.add_child(board)
	_nodes.append(board)
	board.start_level(level)
	(board.get_node("%Board") as Control).size = Vector2(672.0, 700.0)
	return board


func _play(board: GameBoard, moves: Array[Move]) -> void:
	for move: Move in moves:
		board.on_peg_pressed(move.from_peg)
		board.on_peg_pressed(move.to_peg)


## Positions reachable from `level`'s start from which its goal is out of
## reach, or -1 when there are more than CLOSURE_LIMIT positions to look at.
static func _dead_positions(level: Level) -> int:
	var rules: RuleSet = level.get_rule_set()
	var index: Dictionary = {rules.search_key(level.start): 0}
	var states: Array[PuzzleState] = [level.start]
	var back: Array[PackedInt32Array] = [PackedInt32Array()]
	var live: Array[int] = []
	var head: int = 0
	while head < states.size():
		if rules.is_goal_state(states[head], level.goal):
			live.append(head)
		for move: Move in rules.get_legal_moves(states[head]):
			var next: PuzzleState = rules.apply_move_unchecked(states[head], move)
			var key: String = rules.search_key(next)
			if not index.has(key):
				if states.size() >= CLOSURE_LIMIT:
					return -1
				index[key] = states.size()
				states.append(next)
				back.append(PackedInt32Array())
			back[index[key]].append(head)
		head += 1
	var reached: PackedByteArray = PackedByteArray()
	reached.resize(states.size())
	for goal: int in live:
		reached[goal] = 1
	while not live.is_empty():
		for before: int in back[live.pop_back()]:
			if reached[before] == 0:
				reached[before] = 1
				live.append(before)
	return reached.count(0)


func test_only_the_mixed_exchange_can_dead_end() -> void:
	for id: String in RuleSet.RULE_IDS:
		assert_false(RuleSet.create_rule(id).can_dead_end(), "%s keeps every position solvable" % id)
	var ids: Array[String] = [ColorSwapRule.ID]
	assert_true(RuleSet.from_ids(ids, {ColorSwapRule.ID: {"colour": true}}).can_dead_end(), "the mixed kind can")
	assert_false(RuleSet.from_ids(ids, {ColorSwapRule.ID: {"colour": false}}).can_dead_end(), "the pure kind cannot")
	assert_false(RuleSet.classic().can_dead_end())


## Every position of small levels of the other rules can still reach the goal
## (the shipped world 1-2 modes and sub-elements, and in-memory levels of the
## modes whose chapters are not built yet), so they need no watching; the
## mixed exchange's board has dead ends.
func test_rules_that_say_so_never_dead_end() -> void:
	var levels: Array[Level] = []
	var seen: Dictionary = {}
	for position: int in range(1, LevelCatalog.track_length(LevelCatalog.MAIN) + 1):
		var level: Level = LevelCatalog.load_at(LevelCatalog.MAIN, position)
		var key: String = level.lesson() + str(level.variants)
		if not seen.has(key) and level.start.get_disk_count() <= 5:
			seen[key] = true
			levels.append(level)
	var samples: Array = [
		[AlternationRule.ID, [[4, 3, 2, 1], [], [], []], [[], [], [], [4, 3, 2, 1]], {}],
		[AdjacentPegsRule.ID, [[4, 3, 2, 1], [], []], [[], [], [4, 3, 2, 1]], {}],
		[CyclicRule.ID, [[4, 3, 2, 1], [], [], []], [[], [], [4, 3, 2, 1], []], {}],
		[StripesRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {}],
		[ChainRule.ID, [[4, 3], [2, 1], [], []], [[2, 1], [4, 3], [], []], {ChainRule.ID: {"disks": [1, 3]}}],
		[BalanceRule.ID, [[3, 1], [], [2], []], [[], [3, 1], [], [2]], {BalanceRule.ID: {"tolerance": 4}}],
		[TrailRule.ID, [[4, 3, 2, 1], [], []], [[], [], [4, 3, 2, 1]], {TrailRule.ID: {"disk": 1, "recent": 2}}],
		[MirrorRule.ID, [[2, 1], [], [], [], [3], [4]], [[], [], [2, 1], [4, 3], [], []], {}],
		# World 3-4 sub-elements.
		[AdjacentPegsRule.ID, [[4, 3, 2, 1], [], [], []], [[], [], [], [4, 3, 2, 1]], {AdjacentPegsRule.ID: {"oasis": [2, 1]}}],
		[AdjacentPegsRule.ID, [[4, 3, 2, 1], [], [], []], [[], [], [], [4, 3, 2, 1]], {AdjacentPegsRule.ID: {"tunnels": [[0, 3]]}}],
		[AdjacentPegsRule.ID, [[4, 3, 2, 1], [], [], []], [[4, 3], [], [], [2, 1]], {AdjacentPegsRule.ID: {"bridges": [[1, 2, 2]]}}],
		[AdjacentPegsRule.ID, [[4, 3, 2, 1], [], [], []], [[], [], [], [4, 3, 2, 1]], {AdjacentPegsRule.ID: {"jump": true}}],
		[StripesRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {StripesRule.ID: {"neutral": 3}}],
		[StripesRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {StripesRule.ID: {"bases": [0, 1, 0, 0]}}],
		[StripesRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {StripesRule.ID: {"paint": 2}}],
		[StripesRule.ID, [[5, 3, 1], [4, 2], [], []], [[], [], [5, 3, 1], [4, 2]], {StripesRule.ID: {"inverse": true}}],
		[CyclicRule.ID, [[4, 3, 2, 1], [], [], []], [[], [], [4, 3, 2, 1], []], {CyclicRule.ID: {"back": 1}}],
		[CyclicRule.ID, [[4, 3, 2, 1], [], [], []], [[], [], [4, 3, 2, 1], []], {CyclicRule.ID: {"skip": 2}}],
		[CyclicRule.ID, [[4, 3, 2, 1], [], [], [], []], [[], [], [4, 3, 2, 1], [], []], {CyclicRule.ID: {"center": 4}}],
		[CyclicRule.ID, [[4, 3, 2, 1], [], [], [], []], [[], [], [4, 3, 2, 1], [], []], {CyclicRule.ID: {"eight": [[0, 1, 2], [0, 4, 3]]}}],
		[AlternationRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {AlternationRule.ID: {"free": 3}}],
		[AlternationRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {AlternationRule.ID: {"reset": 2}}],
		[AlternationRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {AlternationRule.ID: {"leader": 3}}],
		[AlternationRule.ID, [[5, 4, 3, 2, 1], [], [], []], [[], [], [], [5, 4, 3, 2, 1]], {AlternationRule.ID: {"waiting": 4}}],
		[BalanceRule.ID, [[3, 1], [], [2], []], [[], [3, 1], [], [2]], {BalanceRule.ID: {"tolerance": 5, "weights": [0, 0, 1, 0]}}],
		[BalanceRule.ID, [[3, 1], [], [2], []], [[], [3, 1], [], [2]], {BalanceRule.ID: {"tolerance": 8, "factors": [2, 1, 1, 1]}}],
		[BalanceRule.ID, [[3, 1], [], [2], []], [[], [3, 1], [], [2]], {BalanceRule.ID: {"tolerances": [4, 3]}}],
	]
	for sample: Array in samples:
		var ids: Array[String] = [ClassicHanoiRule.ID, sample[0]]
		var made: Level = make_level(19201, ids, sample[1], sample[2], sample[3])
		if made.get_rule_set().can_dead_end():
			# The paint peg and a new leader (measured): their boards do dead-end.
			assert_true(_dead_positions(made) > 0, "%s %s says it can dead-end" % [sample[0], str(sample[3])])
			continue
		levels.append(made)
	# The dial alone never dead-ends; beside a capacity it can (a combination
	# level of World 3 had 13 dead positions, measured 2026-10-17), so that
	# combination is watched.
	var dial_and_capacity: Array[String] = [ClassicHanoiRule.ID, PegCapacityRule.ID, CyclicRule.ID]
	assert_true(RuleSet.from_ids(dial_and_capacity, {PegCapacityRule.ID: {"capacities": [3, 2, 2, 3]}}).can_dead_end())
	var checked: int = 0
	for level: Level in levels:
		# Rules that say so (a one-way road, the dial beside a limit) are watched.
		if level.get_rule_set().can_dead_end():
			continue
		var dead: int = _dead_positions(level)
		if dead == -1:
			continue
		checked += 1
		assert_eq(dead, 0, "level %d (%s %s %s) has no dead end" % [level.id, level.lesson(), str(level.variants),
				JSON.stringify(level.rule_params)])
	assert_true(checked >= 12, "enough boards were searched to the end (%d)" % checked)
	assert_true(_dead_positions(_mixed_level()) > 0, "the mixed exchange's board has dead ends")


func test_a_dead_end_is_proved_and_its_first_position_found() -> void:
	var level: Level = _mixed_level()
	var line: Array[Move] = _dead_line(level)
	assert_false(line.is_empty(), "random play runs into a dead end")
	var session: GameSession = GameSession.new(level)
	var positions: Array[PuzzleState] = []
	for move: Move in line:
		session.try_move(move)
		positions.append(session.state.duplicate_state())
	assert_true(Solver.solve(session.position_after(line.size() - 1), level.goal, session.rules)["solvable"],
			"the position before is still solvable")
	assert_eq(GameSession.first_dead_end(level, positions, session.rules), positions.size() - 1)
	# Deeper into the dead end: still found where it began.
	for extra: int in 3:
		var moves: Array[Move] = session.rules.get_legal_moves(session.state)
		if moves.is_empty():
			break
		session.try_move(moves[0])
		positions.append(session.state.duplicate_state())
	assert_eq(GameSession.first_dead_end(level, positions, session.rules), line.size() - 1)
	assert_eq(GameSession.first_dead_end(level, positions.slice(0, line.size() - 1), session.rules), -1,
			"the line before it has none")


func test_the_way_back_is_free_and_exact() -> void:
	var level: Level = _mixed_level()
	var session: GameSession = GameSession.new(level)
	for i: int in 3:
		session.try_move(session.rules.get_legal_moves(session.state)[0])
	var after_one: PuzzleState = session.position_after(1).duplicate_state()
	assert_true(session.rewind_to(1))
	assert_eq(session.history.size(), 1)
	assert_eq(session.move_count, 1)
	assert_eq(session.undo_count, 0, "not counted as an undo")
	assert_true(session.state.equals(after_one))
	assert_false(session.rewind_to(1), "nothing more to take back to there")
	assert_true(session.undo(), "an undo still works after it")
	assert_true(session.state.equals(level.start))


func test_the_board_offers_a_free_way_back() -> void:
	var level: Level = _mixed_level()
	var line: Array[Move] = _dead_line(level)
	var board: GameBoard = _board_for(level)
	var status: Label = board.get_node("%StatusLabel")
	var button: Button = board.get_node("%WayBackButton")
	assert_false(button.visible, "no way back while the goal is in reach")
	_play(board, line.slice(0, line.size() - 1))
	assert_false(button.visible)
	assert_eq(board.dead_ends.dead_at, -1)
	_play(board, line.slice(line.size() - 1))
	assert_eq(board.dead_ends.dead_at, line.size(), "found right after the move")
	assert_true(button.visible, "the way back shows")
	assert_eq(tr(button.text), "Geri qayıt", "a key, translated on screen")
	assert_eq(status.text, tr("DEAD_END"), "said kindly")
	assert_eq(status.theme_type_variation, &"SecondaryLabel", "a grey note, not a red warning")
	# A hint costs nothing here and says the same.
	var coins: int = board.economy.coins
	var free_undos: int = board.economy.free_undos_left()
	board.request_hint()
	assert_eq(board.economy.coins, coins, "no coins for a hint in a dead end")
	assert_eq(status.text, tr("DEAD_END"))
	# Deeper into the dead end, then back in one tap.
	var moves: Array[Move] = board.session.rules.get_legal_moves(board.session.state)
	if not moves.is_empty():
		var deeper: Array[Move] = [moves[0]]
		_play(board, deeper)
		assert_true(button.visible, "still a dead end")
	button.pressed.emit()
	assert_eq(board.session.history.size(), line.size() - 1, "back to the last position that can be solved")
	assert_false(button.visible)
	assert_eq(status.text, "")
	assert_eq(board.economy.coins, coins, "free")
	assert_eq(board.economy.free_undos_left(), free_undos, "and no undo used")
	assert_true(Solver.solve(board.session.state, level.goal, board.session.rules)["solvable"])
	# An undo out of a dead end hides the way back too.
	_play(board, line.slice(line.size() - 1))
	assert_true(button.visible)
	board.request_undo()
	assert_false(button.visible)
	# Solved from there: no dead end left behind.
	var rest: Array[Move] = []
	rest.assign(Solver.solve(board.session.state, level.goal, board.session.rules)["path"])
	_play(board, rest)
	assert_true(board.session.is_solved())
	assert_false(button.visible)


func test_other_levels_are_never_searched() -> void:
	var board: GameBoard = _board_for(LevelCatalog.load_at(LevelCatalog.MAIN, 3))
	for i: int in 4:
		var one: Array[Move] = [board.session.rules.get_legal_moves(board.session.state)[-1]]
		_play(board, one)
	assert_eq(board.dead_ends.searches, 0, "a classic level is never checked")
	assert_false((board.get_node("%WayBackButton") as Button).visible)
	board.start_level(_mixed_level())
	var first: Array[Move] = [board.session.rules.get_legal_moves(board.session.state)[0]]
	_play(board, first)
	assert_eq(board.dead_ends.searches, 1, "a mixed exchange level is, after each move")
