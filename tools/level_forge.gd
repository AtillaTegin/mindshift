class_name LevelForge
extends RefCounted
## Draws one level for a slot of the road (tools/road_builder.gd): classic
## Hanoi, one mode or a combination of modes (ChapterPlan), on a board from a
## recipe, with its shortest solution in a move range. Every mode must matter:
## without any one of its rules the puzzle gets shorter (a combination is
## longer than either of its modes alone, section 4.4 of the chapter plan);
## karakuri boxes are presentation only and need no such proof.
##
## A recipe board: {"pegs": int, "disks": int} plus, per mode:
## - peg_capacity "slack": each peg holds what the start and the goal put on
##   it plus 0..slack more (a peg that may hold every disk is no limit);
## - covered_pegs "covered": how many pegs start as boxes (0: every peg that
##   can be one), each holding at least two disks and used within the first
##   LevelValidator.COVERED_REVEAL_WITHIN moves of the stored solution;
## - foundation "locked"/"keys": the largest `locked` disks stay locked until
##   the smallest `keys` disks have stood on their goal pegs.
## - "tower": chance that the goal is a full tower (default
##   TOWER_GOAL_CHANCE), otherwise a random position.

const TOWER_GOAL_CHANCE: float = 0.5
## Search limit while building (offline, so far above an in-game hint's).
const MAX_STATES: int = LevelValidator.SOLVER_MAX_STATES


## Every disk on a random peg; each peg is sorted, so the position is legal.
static func random_state(rng: RandomNumberGenerator, peg_count: int, disk_count: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	for size: int in range(disk_count, 0, -1):
		layout[rng.randi_range(0, peg_count - 1)].append(size)
	return PuzzleState.new(layout)


## All disks stacked on one peg.
static func tower_state(peg_count: int, disk_count: int, on_peg: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	for size: int in range(disk_count, 0, -1):
		layout[on_peg].append(size)
	return PuzzleState.new(layout)


## The rule modes of `modes` (all but karakuri boxes), in ChapterPlan order.
static func rule_modes(modes: Array) -> Array[String]:
	var found: Array[String] = []
	for mode: String in ChapterPlan.MODES:
		if modes.has(mode) and mode != ChapterPlan.COVERED:
			found.append(mode)
	return found


## Rule ids of a level with `modes`: classic Hanoi plus each rule mode.
static func rule_ids_for(modes: Array) -> Array[String]:
	var ids: Array[String] = [ClassicHanoiRule.ID]
	ids.append_array(rule_modes(modes))
	return ids


## Identity of a puzzle for duplicate checks: start and goal, plus the rules
## and their settings when there are rules beyond classic Hanoi. Karakuri
## boxes do not count: a boxed board is the same puzzle as the open one.
static func puzzle_key(start: PuzzleState, goal: PuzzleState, rule_ids: Array, params: Dictionary) -> String:
	var key: String = LevelValidator.pair_key(start, goal)
	if rule_ids.size() > 1:
		var sorted: Dictionary = {}
		var names: Array = params.keys()
		names.sort()
		for name: Variant in names:
			sorted[name] = params[name]
		key += " %s %s" % [str(rule_ids), JSON.stringify(sorted)]
	return key


## One try at a level of `modes` on `board` whose shortest solution has
## `low`-`high` moves, avoiding the puzzle keys in `used`. Returns {} when the
## draw does not fit, else {start, goal, rule_ids, params, covered, path,
## moves, key}.
static func attempt(modes: Array, board: Dictionary, low: int, high: int, used: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var pegs: int = board["pegs"]
	var disks: int = board["disks"]
	var start: PuzzleState = random_state(rng, pegs, disks)
	var goal: PuzzleState = tower_state(pegs, disks, rng.randi_range(0, pegs - 1)) \
			if rng.randf() < board.get("tower", TOWER_GOAL_CHANCE) else random_state(rng, pegs, disks)
	if start.equals(goal):
		return {}
	var params: Dictionary = _params(modes, board, start, goal, rng)
	var rule_ids: Array[String] = rule_ids_for(modes)
	var key: String = puzzle_key(start, goal, rule_ids, params)
	if used.has(key):
		return {}
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	if rules == null or not rules.is_state_valid(start) or not rules.is_state_valid(goal):
		return {}
	if modes.has(FoundationRule.ID) and rules.memory_of(start) != 0:
		return {}  # the lock must be closed at the start
	var result: Dictionary = Solver.solve(start, goal, rules, MAX_STATES)
	var moves: int = result["min_moves"]
	if not result["solvable"] or moves < low or moves > high:
		return {}
	if not matters(start, goal, rule_ids, params, moves):
		return {}
	var path: Array[Move] = result["path"]
	var covered: Array[int] = []
	if modes.has(ChapterPlan.COVERED):
		covered = _covered(start, path, pegs if int(board.get("covered", 0)) == 0 else int(board["covered"]),
				int(board.get("covered", 0)) == 0, rng)
		if covered.is_empty():
			return {}
	return {"start": start, "goal": goal, "rule_ids": rule_ids, "params": params, "covered": covered,
			"path": path, "moves": moves, "key": key}


## Whether every rule beyond classic Hanoi makes the puzzle longer: without
## any one of them the shortest solution of the same start and goal is shorter
## than `moves`.
static func matters(start: PuzzleState, goal: PuzzleState, rule_ids: Array[String], params: Dictionary,
		moves: int) -> bool:
	for rule_id: String in rule_ids:
		if rule_id == ClassicHanoiRule.ID:
			continue
		var others: Array[String] = []
		var other_params: Dictionary = {}
		for other: String in rule_ids:
			if other != rule_id:
				others.append(other)
				if params.has(other):
					other_params[other] = params[other]
		var without: RuleSet = RuleSet.from_ids(others, other_params)
		if not without.is_state_valid(start) or not without.is_state_valid(goal):
			continue
		var result: Dictionary = Solver.solve(start, goal, without, MAX_STATES)
		if result["solvable"] and result["min_moves"] >= moves:
			return false
	return true


## Rule settings for `modes` on this start and goal.
static func _params(modes: Array, board: Dictionary, start: PuzzleState, goal: PuzzleState,
		rng: RandomNumberGenerator) -> Dictionary:
	var params: Dictionary = {}
	var disks: int = board["disks"]
	if modes.has(PegCapacityRule.ID):
		var capacities: Array = []
		for peg_index: int in start.get_peg_count():
			var need: int = maxi(start.pegs[peg_index].size(), goal.pegs[peg_index].size())
			capacities.append(mini(maxi(need, 1) + rng.randi_range(0, int(board.get("slack", 2))), disks))
		params[PegCapacityRule.ID] = {"capacities": capacities}
	if modes.has(FoundationRule.ID):
		var locked: Array = []
		for i: int in int(board.get("locked", 1)):
			locked.append(disks - i)
		var keys: Array = []
		var targets: Array = []
		for disk: int in range(1, int(board.get("keys", 2)) + 1):
			keys.append(disk)
			for peg_index: int in goal.get_peg_count():
				if goal.pegs[peg_index].has(disk):
					targets.append(peg_index)
		params[FoundationRule.ID] = {"locked": locked, "keys": keys, "targets": targets}
	return params


## `count` karakuri boxes (all candidates when `every`): pegs holding at least
## two disks at the start and used within the first moves of `path`. Empty if
## there are not enough.
static func _covered(start: PuzzleState, path: Array[Move], count: int, every: bool,
		rng: RandomNumberGenerator) -> Array[int]:
	var candidates: Array[int] = []
	for peg_index: int in start.get_peg_count():
		if start.pegs[peg_index].size() < 2:
			continue
		for i: int in mini(LevelValidator.COVERED_REVEAL_WITHIN, path.size()):
			if (path[i].from_peg == peg_index or path[i].to_peg == peg_index) and not candidates.has(peg_index):
				candidates.append(peg_index)
	var none: Array[int] = []
	if every:
		# "Every peg": each one must be able to hide something.
		if candidates.size() < start.get_peg_count():
			return none
		candidates.sort()
		return candidates
	if candidates.size() < count:
		return none
	# Seeded shuffle (Array.shuffle() would use the global generator).
	for i: int in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: int = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var chosen: Array[int] = candidates.slice(0, count)
	chosen.sort()
	return chosen
