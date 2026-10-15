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
##   it plus 0..slack more, at least 2 (a peg that may hold every disk is no
##   limit);
## - covered_pegs "covered": how many pegs start as boxes (0: every peg that
##   can be one), each holding at least two disks and used within the first
##   LevelValidator.COVERED_REVEAL_WITHIN moves of the stored solution;
## - foundation "locked"/"keys": the largest `locked` disks stay locked until
##   the smallest `keys` disks have stood on their goal pegs; "stages" for a
##   chain of locks;
## - "tower": chance that the goal is a full tower (default
##   TOWER_GOAL_CHANCE), otherwise a random position;
## - "variants": the mode's sub-elements (chapter waves v1, ChapterPlan.WAVES):
##   - narrow: one peg holds a single disk ("Dar keçid");
##   - arch: one peg lets only disks up to N through ("Tağ");
##   - holed: one empty peg takes only disks from N up ("Deşikli qüllə");
##   - count_board: every peg is a box showing how many disks it holds;
##   - glass: one or two disks inside the boxes are glass and always show;
##   - empty_box: one more box that holds nothing;
##   - sealed: one box is sealed (SealedBoxRule) until the smallest disk is put
##     on its lid;
##   - reclosing: boxes close again when left alone (presentation only);
##   - key_disk: one disk of any size opens the lock on a marked peg;
##   - middle_lock: the locked disk sits in the middle of a stack;
##   - chain_lock: two or three locks, each freed disk the next lock's key.
##   Each rule-changing sub-element must make the puzzle longer on its own.

const TOWER_GOAL_CHANCE: float = 0.5
## Search limit while building (offline, so far above an in-game hint's).
const MAX_STATES: int = LevelValidator.SOLVER_MAX_STATES
## Sub-elements that only change what the player sees.
const LOOKS_ONLY: Array[String] = ["count_board", "glass", "empty_box", "reclosing"]


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
## draw does not fit, else {start, goal, rule_ids, params, covered, glass,
## variants, path, moves, key}.
static func attempt(modes: Array, board: Dictionary, low: int, high: int, used: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	var pegs: int = board["pegs"]
	var disks: int = board["disks"]
	var variants: Array = board.get("variants", [])
	var start: PuzzleState = random_state(rng, pegs, disks)
	var goal: PuzzleState = tower_state(pegs, disks, rng.randi_range(0, pegs - 1)) \
			if rng.randf() < board.get("tower", TOWER_GOAL_CHANCE) else random_state(rng, pegs, disks)
	if start.equals(goal):
		return {}
	var drawn: Variant = _params(modes, board, start, goal, rng)
	if drawn == null:
		return {}
	var params: Dictionary = drawn
	var rule_ids: Array[String] = rule_ids_for(modes)
	var sealed: int = -1
	if variants.has("sealed"):
		sealed = _sealed_peg(start, rng)
		if sealed == -1:
			return {}
		rule_ids.append(SealedBoxRule.ID)
		params[SealedBoxRule.ID] = {"pegs": [sealed]}
	var key: String = puzzle_key(start, goal, rule_ids, params)
	if used.has(key):
		return {}
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	if rules == null or not rules.is_state_valid(start) or not rules.is_state_valid(goal):
		return {}
	if rules.uses_memory() and rules.memory_of(start) != 0:
		return {}  # every lock and seal closed at the start
	var result: Dictionary = Solver.solve(start, goal, rules, MAX_STATES)
	var moves: int = result["min_moves"]
	if not result["solvable"] or moves < low or moves > high:
		return {}
	if not matters(start, goal, rule_ids, params, moves) or not variants_matter(start, goal, rule_ids, params, variants, moves):
		return {}
	var path: Array[Move] = result["path"]
	var covered: Array[int] = []
	var glass: Array[int] = []
	if modes.has(ChapterPlan.COVERED):
		covered = _boxes(start, path, board, variants, sealed, rng)
		if covered.is_empty():
			return {}
		if variants.has("glass"):
			glass = _glass(start, covered, rng)
			if glass.is_empty():
				return {}
	var named: Array[String] = []
	for variant: String in variants:
		if variant != ChapterPlan.BASE:
			named.append(variant)
	return {"start": start, "goal": goal, "rule_ids": rule_ids, "params": params, "covered": covered, "glass": glass,
			"variants": named, "path": path, "moves": moves, "key": key}


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
		if not _shorter(start, goal, others, other_params, moves):
			return false
	return true


## Whether each rule-changing sub-element makes the puzzle longer on its own:
## the same level without just that sub-element (no arch, no hole, the narrow
## peg holding two, the last lock of a chain gone) is shorter.
static func variants_matter(start: PuzzleState, goal: PuzzleState, rule_ids: Array[String], params: Dictionary,
		variants: Array, moves: int) -> bool:
	for variant: String in variants:
		var changed: Dictionary = params.duplicate(true)
		match variant:
			"arch", "holed":
				var list: String = "arches" if variant == "arch" else "holes"
				var zeros: Array = []
				zeros.resize(changed[PegCapacityRule.ID]["capacities"].size())
				zeros.fill(0)
				changed[PegCapacityRule.ID][list] = zeros
			"narrow":
				var caps: Array = changed[PegCapacityRule.ID]["capacities"]
				for i: int in caps.size():
					caps[i] = maxi(caps[i], 2)
			"chain_lock":
				var stages: Array = changed[FoundationRule.ID]["stages"]
				stages.pop_back()
				if stages.size() == 1:
					changed[FoundationRule.ID] = stages[0]
			_:
				continue
		if not _shorter(start, goal, rule_ids, changed, moves):
			return false
	return true


## Whether `rule_ids` with `params` solve start-goal in fewer than `moves`
## (or cannot hold the positions at all, which also shows the change matters).
static func _shorter(start: PuzzleState, goal: PuzzleState, rule_ids: Array[String], params: Dictionary,
		moves: int) -> bool:
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	if rules == null or not rules.is_state_valid(start) or not rules.is_state_valid(goal):
		return true
	var result: Dictionary = Solver.solve(start, goal, rules, MAX_STATES)
	return not result["solvable"] or result["min_moves"] < moves


## Rule settings for `modes` (and their sub-elements) on this start and goal,
## or null when the draw cannot carry them.
static func _params(modes: Array, board: Dictionary, start: PuzzleState, goal: PuzzleState,
		rng: RandomNumberGenerator) -> Variant:
	var params: Dictionary = {}
	var variants: Array = board.get("variants", [])
	var disks: int = board["disks"]
	if modes.has(PegCapacityRule.ID):
		var capacities: Array = []
		var needs: Array[int] = []
		for peg_index: int in start.get_peg_count():
			var need: int = maxi(start.pegs[peg_index].size(), goal.pegs[peg_index].size())
			needs.append(need)
			capacities.append(mini(maxi(need, 2) + rng.randi_range(0, int(board.get("slack", 2))), disks))
		var capacity: Dictionary = {"capacities": capacities}
		if variants.has("narrow"):
			var free: Array = _shuffled(range(capacities.size()).filter(func(p: int) -> bool: return needs[p] <= 1), rng)
			if free.is_empty():
				return null
			capacities[free[0]] = 1
		for variant: String in ["arch", "holed"]:
			if not variants.has(variant):
				continue
			var limits: Array = []
			limits.resize(capacities.size())
			limits.fill(0)
			var placed: bool = false
			for peg_index: int in _shuffled(range(capacities.size()), rng):
				if capacities[peg_index] < 2:
					continue
				var on_peg: Array = start.pegs[peg_index] + goal.pegs[peg_index]
				if variant == "arch":
					# Lets the disks of the start and goal through, but not the largest.
					var widest: int = maxi(on_peg.max() if not on_peg.is_empty() else 1, 1)
					if widest >= disks:
						continue
					limits[peg_index] = rng.randi_range(widest, disks - 1)
				else:
					# Holds the bottom disks of the start and goal, but not the smallest.
					var narrowest: int = disks
					for stack: Array in [start.pegs[peg_index], goal.pegs[peg_index]]:
						if not stack.is_empty():
							narrowest = mini(narrowest, int(stack[0]))
					if narrowest < 2:
						continue
					limits[peg_index] = rng.randi_range(2, narrowest)
				placed = true
				break
			if not placed:
				return null
			capacity["arches" if variant == "arch" else "holes"] = limits
		params[PegCapacityRule.ID] = capacity
	if modes.has(FoundationRule.ID):
		var foundation: Variant = _lock(board, variants, start, goal, rng)
		if foundation == null:
			return null
		params[FoundationRule.ID] = foundation
	return params


## The foundation's settings: its base form (largest disks locked, smallest
## disks the keys, to their goal pegs) changed by the lock sub-elements.
static func _lock(board: Dictionary, variants: Array, start: PuzzleState, goal: PuzzleState,
		rng: RandomNumberGenerator) -> Variant:
	var disks: int = board["disks"]
	var stage_count: int = int(board.get("stages", 2)) if variants.has("chain_lock") else 1
	# The locked disk of each stage, the first one in the middle of a stack if asked.
	var locked: Array[int] = []
	if variants.has("middle_lock"):
		var middles: Array = []
		for stack: Array in start.pegs:
			for i: int in range(1, stack.size() - 1):
				middles.append(stack[i])
		if middles.is_empty():
			return null
		locked.append(middles[rng.randi_range(0, middles.size() - 1)])
	var base_locked: int = int(board.get("locked", 1)) if stage_count == 1 and locked.is_empty() else 1
	for disk: int in range(disks, 0, -1):
		if locked.size() >= maxi(stage_count, base_locked):
			break
		if not locked.has(disk) and disk > 2:
			locked.append(disk)
	if locked.size() < maxi(stage_count, base_locked):
		return null
	# The first stage's keys: the smallest free disks to their goal pegs, or
	# one key disk of any free size to a marked peg it does not start on.
	var keys: Array = []
	var targets: Array = []
	if variants.has("key_disk"):
		var free: Array = []
		for disk: int in range(1, disks + 1):
			if not locked.has(disk):
				free.append(disk)
		var key: int = free[rng.randi_range(0, free.size() - 1)]
		var place: int = _peg_of(start, key)
		var others: Array = range(start.get_peg_count()).filter(func(p: int) -> bool: return p != place)
		keys.append(key)
		targets.append(others[rng.randi_range(0, others.size() - 1)])
	else:
		for disk: int in range(1, disks + 1):
			if keys.size() >= int(board.get("keys", 2)):
				break
			if not locked.has(disk):
				keys.append(disk)
				targets.append(_peg_of(goal, disk))
	if stage_count == 1:
		return {"locked": locked.slice(0, base_locked), "keys": keys, "targets": targets}
	var stages: Array = [{"locked": [locked[0]], "keys": keys, "targets": targets}]
	for i: int in range(1, stage_count):
		# The disk the stage before frees is this lock's key, to a peg it does not start on.
		var key: int = locked[i - 1]
		var place: int = _peg_of(start, key)
		var others: Array = range(start.get_peg_count()).filter(func(p: int) -> bool: return p != place)
		stages.append({"locked": [locked[i]], "keys": [key], "targets": [others[rng.randi_range(0, others.size() - 1)]]})
	return {"stages": stages}


## A peg to seal: it holds at least two disks, not the smallest (which opens
## seals). -1 if the start has none.
static func _sealed_peg(start: PuzzleState, rng: RandomNumberGenerator) -> int:
	var choices: Array = []
	for peg_index: int in start.get_peg_count():
		var stack: Array = start.pegs[peg_index]
		if stack.size() >= 2 and not stack.has(SealedBoxRule.KEY_DISK):
			choices.append(peg_index)
	return choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else -1


## The karakuri boxes of a level: `board.covered` boxes that hide at least two
## disks each and that `path` uses within its first moves (the luck rule, user
## decision 2026-10-09), the sealed one among them (exempt from the early use:
## a tap never opens it), every peg for a count board, and one empty box more
## for "empty_box" (user decision 2026-10-16: those two show enough). Empty
## when the draw does not allow them.
static func _boxes(start: PuzzleState, path: Array[Move], board: Dictionary, variants: Array, sealed: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var none: Array[int] = []
	var boxes: Array[int] = []
	if variants.has("count_board"):
		for peg_index: int in start.get_peg_count():
			boxes.append(peg_index)
		return boxes
	if sealed != -1:
		boxes.append(sealed)
	var wanted: int = int(board.get("covered", 1))
	if wanted == 0:
		var every: Array[int] = _covered(start, path, start.get_peg_count(), true, rng)
		if every.is_empty():
			return none
		boxes = every
	else:
		for peg_index: int in _shuffled(_box_candidates(start, path), rng):
			if boxes.size() >= wanted:
				break
			if not boxes.has(peg_index):
				boxes.append(peg_index)
		if boxes.size() < wanted:
			return none
	if variants.has("empty_box"):
		var empty: Array = range(start.get_peg_count()).filter(func(p: int) -> bool:
			return start.pegs[p].is_empty() and not boxes.has(p))
		if empty.is_empty():
			return none
		boxes.append(empty[rng.randi_range(0, empty.size() - 1)])
	boxes.sort()
	return boxes


## One or two glass disks inside the boxes, below each box's top where there
## is one (the top shows on the first tap anyway). Empty if no box holds any.
static func _glass(start: PuzzleState, boxes: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var inner: Array = []
	var tops: Array = []
	for peg_index: int in boxes:
		var stack: Array = start.pegs[peg_index]
		for i: int in stack.size():
			(tops if i == stack.size() - 1 else inner).append(stack[i])
	var pool: Array = _shuffled(inner if not inner.is_empty() else tops, rng)
	var glass: Array[int] = []
	for disk: int in pool.slice(0, mini(rng.randi_range(1, 2), pool.size())):
		glass.append(disk)
	glass.sort()
	return glass


## Pegs that may be karakuri boxes under the luck rule: at least two disks at
## the start and used within the first moves of `path`.
static func _box_candidates(start: PuzzleState, path: Array[Move]) -> Array[int]:
	var candidates: Array[int] = []
	for peg_index: int in start.get_peg_count():
		if start.pegs[peg_index].size() < 2:
			continue
		for i: int in mini(LevelValidator.COVERED_REVEAL_WITHIN, path.size()):
			if (path[i].from_peg == peg_index or path[i].to_peg == peg_index) and not candidates.has(peg_index):
				candidates.append(peg_index)
	return candidates


## `count` karakuri boxes (all candidates when `every`) among
## _box_candidates(). Empty if there are not enough.
static func _covered(start: PuzzleState, path: Array[Move], count: int, every: bool,
		rng: RandomNumberGenerator) -> Array[int]:
	var candidates: Array[int] = _box_candidates(start, path)
	var none: Array[int] = []
	if every:
		# "Every peg": each one must be able to hide something.
		if candidates.size() < start.get_peg_count():
			return none
		candidates.sort()
		return candidates
	if candidates.size() < count:
		return none
	var shuffled: Array = _shuffled(candidates, rng)
	var chosen: Array[int] = []
	for peg_index: int in shuffled.slice(0, count):
		chosen.append(peg_index)
	chosen.sort()
	return chosen


## A seeded shuffle (Array.shuffle() would use the global generator).
static func _shuffled(items: Array, rng: RandomNumberGenerator) -> Array:
	var copy: Array = items.duplicate()
	for i: int in range(copy.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = copy[i]
		copy[i] = copy[j]
		copy[j] = swap
	return copy


static func _peg_of(state: PuzzleState, disk: int) -> int:
	for peg_index: int in state.get_peg_count():
		if state.pegs[peg_index].has(disk):
			return peg_index
	return -1
