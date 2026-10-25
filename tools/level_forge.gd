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
##   - full_hidden: every peg that holds a disk is a box, no number on it
##     ("Tam gizli"; current decisions 2026-10-16, B.1);
##   - glass: one or two disks inside the boxes are glass and always show;
##   - empty_box: one more box that holds nothing (the only empty box a
##     level may have);
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
## Search cap for one draw (a draw needing more is dropped); the validator keeps
## MAX_STATES. Stops big boards (Böyük Sınaq, 6-peg scales) from stalling a run.
const DRAW_MAX_STATES: int = 500000
## Sub-elements that only change what the player sees ("three_scales" is a
## board of six pegs).
const LOOKS_ONLY: Array[String] = ["full_hidden", "glass", "empty_box", "reclosing", "three_scales", "double_peg"]
## World 3-4 modes (MindShift_Dunya3-4_Alt_Elementler_v1.md): their settings
## are drawn first, since they decide which positions are allowed at all
## (colours, pans, stops off the road), then a start and a goal the rules
## allow (_shape(), _allowed_state()).
const SHAPED: Array[String] = ["adjacent_pegs", "stripes", "cyclic", "alternation", "balance", "river", "heavy",
		"elements", "kintsugi", "solitaire"]
## How many moves a fading trail's mark lasts ("Silinən iz"; a recipe may set
## its own "fade": [low, high]). Measured 2026-10-18 on 3 pegs / 5 disks:
## from 4 moves on it lengthens nearly every solution of the base trail (the
## disk's last two pegs), 2-3 hardly ever; on 4 pegs it hardly matters.
const FADE_MOVES: Array = [4, 5]
## Allowed positions of a balance board, by its settings (enumerated once).
static var _balanced: Dictionary = {}


## Every disk on a random peg; each peg is sorted, so the position is legal.
static func random_state(rng: RandomNumberGenerator, peg_count: int, disk_count: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	for size: int in range(disk_count, 0, -1):
		layout[rng.randi_range(0, peg_count - 1)].append(size)
	return PuzzleState.new(layout)


## Every disk on one of `stacks` random pegs (a recipe's "stacks": a start
## scattered over a few tall stacks, so a goal of heights or sums is far).
static func stacked_state(rng: RandomNumberGenerator, peg_count: int, disk_count: int, stacks: int) -> PuzzleState:
	var layout: Array = []
	for i: int in peg_count:
		layout.append([])
	var homes: Array = _shuffled(range(peg_count), rng).slice(0, mini(stacks, peg_count))
	for size: int in range(disk_count, 0, -1):
		layout[homes[rng.randi_range(0, homes.size() - 1)]].append(size)
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


## Rule ids of a level with `modes`: classic Hanoi plus each rule mode (the
## great exchange brings its own size rule instead).
static func rule_ids_for(modes: Array) -> Array[String]:
	var ids: Array[String] = []
	if not modes.has(ColorSwapRule.ID):
		ids.append(ClassicHanoiRule.ID)
	ids.append_array(rule_modes(modes))
	return ids


## Identity of a puzzle for duplicate checks: its canonical form
## (PuzzleIdentity, current decisions 2026-10-16, E), the same for every
## reordering or mirror image of the pegs and for swapped colours. Karakuri
## boxes do not count: a boxed board is the same puzzle as the open one.
static func puzzle_key(start: PuzzleState, goal: PuzzleState, rule_ids: Array, params: Dictionary) -> String:
	return PuzzleIdentity.key(start, goal, rule_ids, params)


## One try at a level of `modes` on `board` whose shortest solution has
## `low`-`high` moves, avoiding the puzzle keys in `used`. Returns {} when the
## draw does not fit, else {start, goal, rule_ids, params, covered, glass,
## variants, path, moves, key}.
static func attempt(modes: Array, board: Dictionary, low: int, high: int, used: Dictionary,
		rng: RandomNumberGenerator) -> Dictionary:
	board = fitted(board)
	var pegs: int = board["pegs"]
	var disks: int = board["disks"]
	var variants: Array = board.get("variants", [])
	var shape: Variant = _shape(modes, board, rng)
	var aim: Variant = _goal_shape(modes, board, rng)
	if shape == null or aim == null:
		return {}
	var start: PuzzleState
	var goal: PuzzleState
	if modes.has(ColorSwapRule.ID):
		var pair: Array[PuzzleState] = _swap_positions(board, rng)
		if pair.is_empty():
			return {}
		start = pair[0]
		goal = pair[1]
	elif (shape as Dictionary).is_empty():
		start = random_state(rng, pegs, disks) if int(board.get("stacks", 0)) == 0 \
				else stacked_state(rng, pegs, disks, board["stacks"])
		goal = tower_state(pegs, disks, rng.randi_range(0, pegs - 1)) \
				if rng.randf() < board.get("tower", TOWER_GOAL_CHANCE) else random_state(rng, pegs, disks)
	else:
		var positions: Array[PuzzleState] = _shaped_positions(modes, shape, board.merged({"low": low, "high": high}), rng)
		if positions.is_empty():
			return {}
		start = positions[0]
		goal = positions[1]
	if variants.has("siege") and not _besieged(start):
		return {}
	# A rule that sets the goal (ICRA section 2) aims at a condition: until the
	# search ends at a position that meets it, the goal is the start itself.
	var king: Dictionary = (aim as Dictionary).get(KingRule.ID, {})
	var aimed: bool = not (aim as Dictionary).is_empty() and not king.has("odd_even")
	if king.has("odd_even"):
		goal = _odd_even_state(pegs, disks, king["odd_even"])
	if aimed:
		goal = start
	elif start.equals(goal):
		return {}
	var drawn: Variant = _params(modes, board, start, goal, rng)
	if drawn == null:
		return {}
	var params: Dictionary = drawn
	if not (shape as Dictionary).is_empty():
		params.merge(shape["params"])
	params.merge(aim)
	if board.get("cut", false) and params.has(PegCapacityRule.ID):
		var cut: Variant = _cut_capacities(modes, start, goal, params, rng)
		if cut == null:
			return {}
		params[PegCapacityRule.ID]["capacities"] = cut
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
	if (rule_ids.has(FoundationRule.ID) or rule_ids.has(SealedBoxRule.ID)) and rules.memory_of(start) != 0:
		return {}  # every lock and seal closed at the start
	var result: Dictionary = Solver.solve(start, goal, rules, DRAW_MAX_STATES)
	var moves: int = result["min_moves"]
	if not result["solvable"] or moves < low or moves > high:
		return {}
	var path: Array[Move] = result["path"]
	# A chain that never moves teaches nothing.
	if rules.has_partners(start) or rules.needs_generic_groups(start):
		if not path.any(func(move: Move) -> bool: return move.is_compound()):
			return {}
	if aimed:
		goal = end_of(start, path, rules)
	if not matters(start, goal, rule_ids, params, moves) or not variants_matter(start, goal, rule_ids, params, variants, moves):
		return {}
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
	# The caravanserai only lets colours mix where the colour rule holds.
	if named.has("caravanserai") and not named.has("mixed"):
		named.append("mixed")
	return {"start": start, "goal": goal, "rule_ids": rule_ids, "params": params, "covered": covered, "glass": glass,
			"variants": named, "path": path, "moves": moves, "key": key}


## Whether every rule beyond classic Hanoi makes the puzzle longer: without
## any one of them the shortest solution of the same start and goal is shorter
## than `moves`.
static func matters(start: PuzzleState, goal: PuzzleState, rule_ids: Array[String], params: Dictionary,
		moves: int) -> bool:
	# A rule that only says what the goal is (RuleBase.only_aims) is the
	# puzzle's aim (ICRA 1a: its start is scattered); without it the stored
	# goal is only where one solution ended.
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	var aims: Array[String] = []
	if rules != null:
		for rule: RuleBase in rules.active_rules:
			if rule.only_aims():
				aims.append(rule.get_id())
	for rule_id: String in rule_ids:
		if rule_id == ClassicHanoiRule.ID or aims.has(rule_id):
			continue
		var others: Array[String] = []
		var other_params: Dictionary = {}
		# Without the exchange's own size rule, classic Hanoi keeps the stacks.
		if rule_id == ColorSwapRule.ID and not rule_ids.has(ClassicHanoiRule.ID):
			others.append(ClassicHanoiRule.ID)
		for other: String in rule_ids:
			if other != rule_id:
				others.append(other)
				if params.has(other):
					other_params[other] = params[other]
		if not _shorter(start, goal, others, other_params, moves):
			return false
	return true


## Whether each rule-changing sub-element changes the puzzle on its own (World
## 3-4 spec, section 0): without just that sub-element (no arch, no hole, the
## narrow peg holding two, the last lock of a chain gone, no tunnel...) a
## limiting one leaves it shorter, a helping one (ChapterPlan.HELPERS) longer
## or impossible: the shortest solution uses it.
static func variants_matter(start: PuzzleState, goal: PuzzleState, rule_ids: Array[String], params: Dictionary,
		variants: Array, moves: int) -> bool:
	for variant: String in variants:
		var changed: Variant = settings_without(variant, params)
		if changed == null:
			continue
		if ChapterPlan.HELPERS.has(variant):
			if not _longer(start, goal, rule_ids, changed, moves):
				return false
		elif not _shorter(start, goal, rule_ids, changed, moves):
			return false
	return true


## The rule settings `params` without just `variant`, or null for one that
## changes no rule (looks, a board shape, the turned stripes: a rule of its
## own, measured by matters()).
static func settings_without(variant: String, params: Dictionary) -> Variant:
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
		"oasis":
			# The oasis stays, cut off from the road.
			var road: Dictionary = changed[AdjacentPegsRule.ID]
			road["oasis"] = [road["oasis"][0], road["oasis"][0]]
		"tunnel", "bridge", "one_way", "jump":
			var name: String = {"tunnel": "tunnels", "bridge": "bridges", "one_way": "one_way", "jump": "jump"}[variant]
			(changed[AdjacentPegsRule.ID] as Dictionary).erase(name)
		"neutral", "colored_base", "paint":
			var name: String = {"neutral": "neutral", "colored_base": "bases", "paint": "paint"}[variant]
			(changed[StripesRule.ID] as Dictionary).erase(name)
		"back_peg", "shortcut", "eight":
			var name: String = {"back_peg": "back", "shortcut": "skip", "eight": "eight"}[variant]
			(changed[CyclicRule.ID] as Dictionary).erase(name)
		"center":
			# The centre stays, cut off from the circle.
			changed[CyclicRule.ID]["center_closed"] = true
		"broken_ring", "reset_peg", "new_leader", "waiting_ring":
			var name: String = {"broken_ring": "free", "reset_peg": "reset", "new_leader": "leader",
				"waiting_ring": "waiting"}[variant]
			(changed[AlternationRule.ID] as Dictionary).erase(name)
		"stone", "long_arm", "moving_stone":
			var scales: Dictionary = changed[BalanceRule.ID]
			if variant == "long_arm":
				scales.erase("factors")
			else:
				scales.erase("moving_stone")
				if variant == "stone":
					scales.erase("weights")
		"own_limits":
			var scales: Dictionary = changed[BalanceRule.ID]
			scales["tolerance"] = (scales["tolerances"] as Array).max()
			scales.erase("tolerances")
		# World 5 (ICRA 3.1-3.3).
		"vizier":
			var crowns: Array = changed[KingRule.ID]["crowns"]
			crowns.pop_back()
		"narrow_gate":
			(changed[KingRule.ID] as Dictionary).erase("narrow")
		"stone_bridge", "two_crossings":
			(changed[RiverRule.ID] as Dictionary).erase("bridges" if variant == "stone_bridge" else "crossings")
		"ferry":
			# The ferry stays, for the small disks only.
			changed[RiverRule.ID]["ferry_small"] = true
		"mixed":
			changed[ColorSwapRule.ID]["colour"] = false
		"caravanserai":
			(changed[ColorSwapRule.ID] as Dictionary).erase("caravanserai")
		# World 6 (ICRA 3.4-3.6).
		"navel", "coloured":
			var carpet: Dictionary = changed[CarpetRule.ID]
			if variant == "navel":
				carpet.erase("navel")
			else:
				carpet.erase("colours")
				carpet.erase("tops")
		"free_peg", "long_ko", "two_stones":
			var name: String = {"free_peg": "free", "long_ko": "turns", "two_stones": "both"}[variant]
			(changed[KoRule.ID] as Dictionary).erase(name)
		"two_chains", "long_chain", "breaking", "rubber":
			var chain: Dictionary = changed[ChainRule.ID]
			if variant == "breaking" or variant == "rubber":
				chain.erase(variant)
			elif variant == "two_chains":
				chain["groups"] = [chain["groups"][0]]
			else:
				chain["groups"] = [(chain["groups"][0] as Array).slice(0, 2)]
		# World 7 (ICRA 3.7-3.9).
		"cart":
			# The cart's peg stays, a plain one-disk stop without the free way out.
			var heavy: Dictionary = changed[HeavyRule.ID]
			heavy["stop"] = heavy["cart"]
			heavy.erase("cart")
		"fatigue", "uphill":
			(changed[HeavyRule.ID] as Dictionary).erase(variant)
		"neutral_earth", "element_base", "creation", "element_peg":
			var name: String = {"neutral_earth": "earth", "element_base": "bases", "creation": "creation",
				"element_peg": "turning"}[variant]
			(changed[ElementsRule.ID] as Dictionary).erase(name)
		"clean_peg":
			(changed[TrailRule.ID] as Dictionary).erase("clean")
		"fading":
			var trail: Dictionary = changed[TrailRule.ID]
			trail.erase("fade")
			trail["recent"] = 2
		"two_trails":
			var trail: Dictionary = changed[TrailRule.ID]
			trail["disk"] = trail["disks"][0]
			trail.erase("disks")
		# World 8-9 (ICRA 3.10-3.14).
		"sum_and_height":
			(changed[SumRule.ID] as Dictionary).erase("counts")
		"pass", "grey", "double_turn":
			var turns: Dictionary = changed[TurnsRule.ID]
			if variant == "pass":
				turns.erase("pass")
			elif variant == "double_turn":
				turns.erase("order")
			else:
				# The grey disk takes the colour of the turn it would be missed in: white.
				var colours: Array = turns["colours"]
				colours[colours.find(TurnsRule.GREY)] = TurnsRule.WHITE
		"deep_crack", "single_repair", "ordered_repair":
			(changed[KintsugiRule.ID] as Dictionary).erase({"deep_crack": "deep", "single_repair": "single",
				"ordered_repair": "ordered"}[variant])
		"two_workshops":
			var kintsugi: Dictionary = changed[KintsugiRule.ID]
			kintsugi["workshops"] = [kintsugi["workshops"][0]]
		"long_light", "fixed_lantern", "two_lamps", "lamp_disk":
			(changed[LampRule.ID] as Dictionary).erase({"long_light": "radius", "fixed_lantern": "fixed", "two_lamps": "two",
				"lamp_disk": "carrier"}[variant])
		"free_cell":
			# The cell stays, closed to every disk.
			changed[SolitaireRule.ID]["closed"] = true
		"red_black", "run_arch", "run_narrow":
			(changed[SolitaireRule.ID] as Dictionary).erase({"red_black": "colours", "run_arch": "arches",
					"run_narrow": "limits"}[variant])
		_:
			return null
	return changed


## Whether `rule_ids` with `params` solve start-goal in fewer than `moves`
## (or cannot hold the positions at all, which also shows the change matters).
static func _shorter(start: PuzzleState, goal: PuzzleState, rule_ids: Array[String], params: Dictionary,
		moves: int) -> bool:
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	if rules == null or not rules.is_state_valid(start) or not rules.is_state_valid(goal):
		return true
	var result: Dictionary = Solver.solve(start, goal, rules, MAX_STATES)
	return not result["solvable"] or result["min_moves"] < moves


## Whether `rule_ids` with `params` solve start-goal only in more than `moves`
## (or not at all, or cannot hold the positions: then too the sub-element
## taken away was needed).
static func _longer(start: PuzzleState, goal: PuzzleState, rule_ids: Array[String], params: Dictionary,
		moves: int) -> bool:
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	if rules == null or not rules.is_state_valid(start) or not rules.is_state_valid(goal):
		return true
	var result: Dictionary = Solver.solve(start, goal, rules, MAX_STATES)
	return not result["solvable"] or result["min_moves"] > moves


## Rule settings for `modes` (and their sub-elements) on this start and goal,
## or null when the draw cannot carry them.
static func _params(modes: Array, board: Dictionary, start: PuzzleState, goal: PuzzleState,
		rng: RandomNumberGenerator) -> Variant:
	var params: Dictionary = {}
	var variants: Array = board.get("variants", [])
	var disks: int = board["disks"]
	if modes.has(ColorSwapRule.ID):
		params[ColorSwapRule.ID] = _swap_params(board, variants)
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
	# World 6 (ICRA 3.5-3.6): Ko's kind of breathing, the chains' disks.
	if modes.has(KoRule.ID):
		var ko: Dictionary = {}
		if variants.has("target_ko"):
			ko["target"] = true
		if variants.has("two_stones"):
			ko["both"] = true
		if variants.has("long_ko"):
			ko["turns"] = 2
		if variants.has("free_peg"):
			ko["free"] = rng.randi_range(0, start.get_peg_count() - 1)
		params[KoRule.ID] = ko
	if modes.has(ChainRule.ID):
		var pool: Array = _shuffled(range(1, disks + 1), rng)
		var groups: Array = [pool.slice(0, 3 if variants.has("long_chain") else 2)]
		if variants.has("two_chains"):
			groups.append(pool.slice(2, 4))
		for group: Array in groups:
			group.sort()
		var chain: Dictionary = {"groups": groups}
		if groups.size() == 1 and groups[0].size() == 2:
			chain = {"disks": groups[0]}
		if variants.has("breaking"):
			chain["breaking"] = true
		if variants.has("rubber"):
			chain["rubber"] = true
		params[ChainRule.ID] = chain
	# World 7 (ICRA 3.9): the trail's disk (the smallest, a second one for "İki
	# izli disk"), how long it lasts (the disk's last two pegs, or a mark per peg
	# fading after a few moves of any disk: "Silinən iz"), a clean peg.
	if modes.has(TrailRule.ID):
		var trail: Dictionary = {"disk": 1}
		if variants.has("fading"):
			var span: Array = board.get("fade", FADE_MOVES)
			trail["fade"] = rng.randi_range(span[0], span[1])
		else:
			trail["recent"] = 2
		if variants.has("two_trails"):
			trail.erase("disk")
			trail["disks"] = [1, rng.randi_range(2, mini(3, disks))]
		if variants.has("clean_peg"):
			trail["clean"] = rng.randi_range(0, start.get_peg_count() - 1)
		params[TrailRule.ID] = trail
	# World 8-9 (ICRA 3.11, 3.13): the disks' colours and the order of turns; the
	# lamp's start and its kind.
	if modes.has(TurnsRule.ID):
		var three: bool = variants.has("three_colours")
		# Every colour about as many disks: a colour short of disks soon has none
		# it can move when its turn comes (measured 2026-10-18: with random
		# colours nearly every three-colour board was stuck).
		var hues: int = 3 if three else 2
		var colours: Array = []
		for size: int in disks:
			colours.append(size % hues)
		colours = _shuffled(colours, rng)
		if variants.has("grey"):
			colours[rng.randi_range(0, disks - 1)] = TurnsRule.GREY
		var turns: Dictionary = {"colours": colours}
		if three:
			turns["order"] = [TurnsRule.WHITE, TurnsRule.BLACK, TurnsRule.RED]
		elif variants.has("double_turn"):
			turns["order"] = [TurnsRule.WHITE, TurnsRule.WHITE, TurnsRule.BLACK, TurnsRule.BLACK]
		if variants.has("pass"):
			turns["pass"] = true
		params[TurnsRule.ID] = turns
	if modes.has(LampRule.ID):
		var pegs: int = start.get_peg_count()
		var lamp: Dictionary = {"start": rng.randi_range(0, pegs - 1)}
		if board.get("circle", false):
			lamp["circle"] = true
		if variants.has("long_light"):
			lamp["radius"] = 2
		if variants.has("fixed_lantern"):
			lamp["fixed"] = rng.randi_range(0, pegs - 1)
		if variants.has("two_lamps"):
			lamp["two"] = true
		if variants.has("lamp_disk"):
			# One of the small disks: a large one, buried under the others, kept
			# the lamp where it stood (measured 2026-10-18: no level at all).
			lamp["carrier"] = rng.randi_range(1, mini(3, disks))
		params[LampRule.ID] = lamp
	return params


## Capacities that cut the other modes' own shortest solution (a recipe's
## "cut": the stacks of the river and the exchange need room that random
## capacities either leave, so the capacity changes nothing, or take, so
## nothing is solvable; measured 2026-10-17): each peg holds the most disks
## that solution ever puts on it, one peg one disk fewer (never below what the
## start and the goal put there). Null when no peg can be cut.
static func _cut_capacities(modes: Array, start: PuzzleState, goal: PuzzleState, params: Dictionary,
		rng: RandomNumberGenerator) -> Variant:
	var others: Array = modes.filter(func(mode: String) -> bool: return mode != PegCapacityRule.ID)
	var other_params: Dictionary = params.duplicate(true)
	other_params.erase(PegCapacityRule.ID)
	var rules: RuleSet = RuleSet.from_ids(rule_ids_for(others), other_params)
	if rules == null:
		return null
	var result: Dictionary = Solver.solve(start, goal, rules, MAX_STATES)
	if not result["solvable"]:
		return null
	var heights: Array = []
	for peg_index: int in start.get_peg_count():
		heights.append(maxi(start.pegs[peg_index].size(), goal.pegs[peg_index].size()))
	var state: PuzzleState = start
	for move: Move in result["path"]:
		state = rules.apply_move_unchecked(state, move)
		for peg_index: int in state.get_peg_count():
			heights[peg_index] = maxi(heights[peg_index], state.pegs[peg_index].size())
	var cuttable: Array = range(heights.size()).filter(func(peg: int) -> bool:
		return heights[peg] >= 2 and heights[peg] - 1 >= maxi(start.pegs[peg].size(), goal.pegs[peg].size()))
	if cuttable.is_empty():
		return null
	var caps: Array = heights.duplicate()
	var peg: int = cuttable[rng.randi_range(0, cuttable.size() - 1)]
	caps[peg] = int(heights[peg]) - 1
	return caps


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


## A recipe `board` grown to what its sub-elements need: an oasis or a centre
## is one more peg, the figure eight an odd number of pegs, three scales six;
## the free cell takes the last peg (_shape()).
static func fitted(board: Dictionary) -> Dictionary:
	var variants: Array = board.get("variants", [])
	var fit: Dictionary = board.duplicate()
	if variants.has("oasis") or variants.has("center") or variants.has("ferry") or variants.has("cart") \
			or variants.has("free_cell"):
		fit["pegs"] = int(board["pegs"]) + 1
	if variants.has("eight") and int(fit["pegs"]) % 2 == 0:
		fit["pegs"] = int(fit["pegs"]) + 1
	if variants.has("three_scales") or variants.has("twin"):
		fit["pegs"] = 6
	return fit


## The settings of the World 3-4 modes in `modes` (SHAPED) with the
## sub-elements of `board.variants`, drawn before the positions: {params,
## keep (pegs that start and end empty: an oasis, a centre)}; {} without such
## a mode, null when the board cannot carry them.
static func _shape(modes: Array, board: Dictionary, rng: RandomNumberGenerator) -> Variant:
	if not SHAPED.any(func(mode: String) -> bool: return modes.has(mode)):
		return {}
	var pegs: int = board["pegs"]
	var disks: int = board["disks"]
	var variants: Array = board.get("variants", [])
	var params: Dictionary = {}
	var keep: Array[int] = []
	if modes.has(AdjacentPegsRule.ID):
		var road: Dictionary = {}
		var stops: Array = range(pegs)
		if variants.has("oasis"):
			# Beside its stop (the peg right after it), holding one disk.
			var oasis: int = rng.randi_range(1, pegs - 1)
			road["oasis"] = [oasis, oasis - 1]
			keep.append(oasis)
			stops.erase(oasis)
		if variants.has("tunnel"):
			if stops.size() < 3:
				return null
			var a: int = rng.randi_range(0, stops.size() - 3)
			var b: int = rng.randi_range(a + 2, stops.size() - 1)
			road["tunnels"] = [[stops[a], stops[b]]]
		var segments: Array = _shuffled(range(stops.size() - 1), rng)
		if variants.has("bridge"):
			var at: int = segments.pop_back()
			# Only the largest few may not cross: a narrower bridge mostly cuts the
			# road (measured 2026-10-17).
			road["bridges"] = [[stops[at], stops[at + 1], rng.randi_range(maxi(disks / 2, 1), disks - 1)]]
		if variants.has("one_way"):
			if segments.is_empty():
				return null
			var at: int = segments.pop_back()
			road["one_way"] = [[stops[at], stops[at + 1]] if rng.randf() < 0.5 else [stops[at + 1], stops[at]]]
		if variants.has("jump"):
			road["jump"] = true
		params[AdjacentPegsRule.ID] = road
	if modes.has(StripesRule.ID):
		var stripes: Dictionary = {}
		if variants.has("neutral"):
			stripes["neutral"] = rng.randi_range(1, disks)
		var free: Array = _shuffled(range(pegs), rng)
		if variants.has("colored_base"):
			var bases: Array = []
			bases.resize(pegs)
			bases.fill(StripesRule.NONE)
			for i: int in rng.randi_range(1, 2):
				bases[free.pop_back()] = rng.randi_range(StripesRule.ODD, StripesRule.EVEN)
			stripes["bases"] = bases
		if variants.has("paint"):
			stripes["paint"] = free.pop_back()
		if variants.has("inverse"):
			stripes["inverse"] = true
		params[StripesRule.ID] = stripes
	if modes.has(CyclicRule.ID):
		var dial: Dictionary = {}
		var ring: Array = range(pegs)
		if variants.has("center"):
			dial["center"] = pegs - 1
			keep.append(pegs - 1)
			ring.erase(pegs - 1)
		var places: Array = _shuffled(ring, rng)
		if variants.has("back_peg"):
			dial["back"] = places.pop_back()
		if variants.has("shortcut"):
			dial["skip"] = places.pop_back()
		if variants.has("eight"):
			# The shared peg first; the first circle in index order, the second
			# the other way round, so the two run like the strokes of an 8.
			if pegs < 5 or pegs % 2 == 0:
				return null
			var half: int = (pegs - 1) / 2
			var second: Array = [0]
			for peg: int in range(pegs - 1, half, -1):
				second.append(peg)
			dial["eight"] = [range(half + 1), second]
		params[CyclicRule.ID] = dial
	if modes.has(AlternationRule.ID):
		var rings: Dictionary = {}
		var disk_pool: Array = _shuffled(range(2, disks + 1), rng)
		if variants.has("new_leader"):
			rings["leader"] = disk_pool.pop_back()
		if variants.has("broken_ring"):
			rings["free"] = disk_pool.pop_back()
		if variants.has("waiting_ring"):
			if disk_pool.is_empty():
				return null
			rings["waiting"] = disk_pool.pop_back()
		if variants.has("reset_peg"):
			rings["reset"] = rng.randi_range(0, pegs - 1)
		params[AlternationRule.ID] = rings
	if modes.has(BalanceRule.ID):
		var scales: Dictionary = {}
		var span: Array = board.get("tolerance", [1, 6])
		if variants.has("own_limits"):
			var limits: Array = []
			for i: int in pegs / 2:
				limits.append(rng.randi_range(span[0], span[1]))
			if limits.all(func(n: int) -> bool: return n == limits[0]):
				limits[0] = span[1] if limits[0] != span[1] else span[0]
			scales["tolerances"] = limits
		else:
			scales["tolerance"] = rng.randi_range(span[0], span[1])
		var pans: Array = _shuffled(range(pegs), rng)
		if variants.has("stone") or variants.has("moving_stone"):
			var weights: Array = []
			weights.resize(pegs)
			weights.fill(0)
			weights[pans.pop_back()] = rng.randi_range(1, 3)
			scales["weights"] = weights
		if variants.has("long_arm"):
			var factors: Array = []
			factors.resize(pegs)
			factors.fill(1)
			factors[pans.pop_back()] = 2
			scales["factors"] = factors
		if variants.has("moving_stone"):
			scales["moving_stone"] = true
		params[BalanceRule.ID] = scales
	if modes.has(RiverRule.ID):
		var river: Variant = _river_shape(board, rng)
		if river == null:
			return null
		params[RiverRule.ID] = river
		var boat: int = (river["banks"] as Array).find(RiverRule.FERRY)
		if boat >= 0:
			keep.append(boat)
	# World 7 (ICRA 3.7-3.8).
	if modes.has(HeavyRule.ID):
		# Reach by size: the smallest third any distance, the middle two pegs,
		# the largest one (reversed for "Tərs çəki").
		var reach: Array = []
		for size: int in range(1, disks + 1):
			var third: int = (size - 1) * 3 / disks
			reach.append([0, 2, 1][2 - third] if variants.has("reverse_weight") else [0, 2, 1][third])
		var heavy: Dictionary = {"reach": reach}
		if variants.has("cart"):
			heavy["cart"] = rng.randi_range(1, pegs - 2)
			keep.append(heavy["cart"])
		if variants.has("fatigue"):
			heavy["fatigue"] = true
		if variants.has("uphill"):
			heavy["uphill"] = true
		params[HeavyRule.ID] = heavy
	if modes.has(ElementsRule.ID):
		var elements: Array = []
		if variants.has("creation"):
			# Down the cycle of creation from the largest disk, so a tower is a
			# legal goal (ICRA 3.8: the generator shares the elements out so the
			# goal is legal); with random elements nearly nothing could stack and
			# no level was solvable (measured 2026-10-18).
			var first: int = rng.randi_range(ElementsRule.WOOD, ElementsRule.WATER)
			for size: int in range(1, disks + 1):
				elements.append((first + disks - size) % 5)
		else:
			for size: int in disks:
				elements.append(rng.randi_range(ElementsRule.WOOD, ElementsRule.WATER))
		var wuxing: Dictionary = {"elements": elements}
		if variants.has("neutral_earth"):
			wuxing["earth"] = true
			if not elements.has(ElementsRule.EARTH):
				elements[rng.randi_range(0, disks - 1)] = ElementsRule.EARTH
		if variants.has("element_base"):
			var bases: Array = []
			bases.resize(pegs)
			bases.fill(-1)
			for peg: int in _shuffled(range(pegs), rng).slice(0, rng.randi_range(1, 2)):
				bases[peg] = rng.randi_range(ElementsRule.WOOD, ElementsRule.WATER)
			wuxing["bases"] = bases
		if variants.has("creation"):
			wuxing["creation"] = true
		if variants.has("element_peg"):
			wuxing["turning"] = rng.randi_range(0, pegs - 1)
		if variants.has("changing"):
			wuxing["changing"] = true
		params[ElementsRule.ID] = wuxing
	# World 8-9 (ICRA 3.12, 3.14).
	if modes.has(KintsugiRule.ID):
		var places: Array = _shuffled(range(pegs), rng)
		var kintsugi: Dictionary = {"cracked": _shuffled(range(2, disks + 1), rng).slice(0, rng.randi_range(1, 2)),
				"workshops": places.slice(0, 2 if variants.has("two_workshops") else 1)}
		for flag: Array in [["deep_crack", "deep"], ["single_repair", "single"], ["ordered_repair", "ordered"]]:
			if variants.has(flag[0]):
				kintsugi[flag[1]] = true
		# An order, a workshop that closes or a second one only shows with two
		# cracked disks.
		if (variants.has("ordered_repair") or variants.has("single_repair") or variants.has("two_workshops")) \
				and (kintsugi["cracked"] as Array).size() < 2:
			kintsugi["cracked"] = _shuffled(range(2, disks + 1), rng).slice(0, 2)
		params[KintsugiRule.ID] = kintsugi
	if modes.has(SolitaireRule.ID):
		var solitaire: Dictionary = {}
		if variants.has("free_cell"):
			solitaire["cell"] = pegs - 1
			keep.append(pegs - 1)
		if variants.has("red_black"):
			# The colours take turns up the sizes but for one or two places where
			# two neighbours share a colour (such a pair never stacks): with
			# random colours nearly every board was cut into pieces that could
			# not be solved (measured 2026-10-18).
			var breaks: Array = _shuffled(range(1, disks), rng).slice(0, 1 if disks < 8 else rng.randi_range(1, 2))
			var colours: Array = []
			var colour: int = rng.randi_range(0, 1)
			for size: int in range(1, disks + 1):
				if size > 1 and not breaks.has(size - 1):
					colour = 1 - colour
				colours.append(colour)
			solitaire["colours"] = colours
		# The arch and the narrow tower sit on a peg other than the cell: the arch
		# lets through at least the disks of the start and goal (so they stay
		# solvable) but not the largest, the tower holds at least the tallest
		# stack of either (a run is one stack, so it limits only longer runs).
		var plain: Array = range(pegs).filter(func(p: int) -> bool: return not keep.has(p))
		if variants.has("run_arch"):
			var arches: Array = []
			arches.resize(pegs)
			arches.fill(0)
			var widest: int = maxi(disks - 2, 1)
			arches[_shuffled(plain, rng)[0]] = rng.randi_range(maxi(disks / 2, 1), maxi(widest, 1))
			solitaire["arches"] = arches
		if variants.has("run_narrow"):
			var limits: Array = []
			limits.resize(pegs)
			limits.fill(0)
			limits[_shuffled(plain, rng)[0]] = rng.randi_range(2, maxi(disks / 2, 2))
			solitaire["limits"] = limits
		params[SolitaireRule.ID] = solitaire
	return {"params": params, "keep": keep}


## Fil Çayı's settings (ICRA 3.2): two banks of at least two pegs, a ferry
## between them if asked (LevelForge.fitted() gave it its peg), the largest
## 2 to half of the disks elephants (3 and up at the bonfire), a stone bridge
## or two crossings. A crossing lets the largest small disk over, the other
## one fewer. Measured 2026-10-17: the river only lengthens a solution where
## the disks that stay must rearrange on a bank with fewer pegs than the
## board (a bank of three, many of them), so few elephants on two pegs a bank
## never made a level of the base form.
static func _river_shape(board: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var variants: Array = board.get("variants", [])
	var disks: int = board["disks"]
	var land: int = int(board["pegs"]) - (1 if variants.has("ferry") else 0)
	if land < 4:
		return null
	# A bank of three pegs where the board has room for one.
	var left: int = 2 if land == 4 else (3 if rng.randf() < 0.5 or land - 3 < 2 else land - 3)
	var banks: Array = []
	for i: int in land:
		banks.append(RiverRule.LEFT if i < left else RiverRule.RIGHT)
	if variants.has("ferry"):
		banks.insert(left, RiverRule.FERRY)
	# Many elephants, so their stack must move on its own bank; few where the
	# river is reversed (then the small disks' stack stays on its bank).
	var elephants: int = rng.randi_range(2, 3) if variants.has("reverse") \
			else rng.randi_range(maxi(3, disks / 2), maxi(3, disks - 2))
	var river: Dictionary = {"banks": banks, "elephant": maxi(disks - elephants + 1, 2)}
	if variants.has("bonfire"):
		river["elephant"] = 3
		river["fire"] = true
	var lefts: Array = range(banks.size()).filter(func(p: int) -> bool: return banks[p] == RiverRule.LEFT)
	var rights: Array = range(banks.size()).filter(func(p: int) -> bool: return banks[p] == RiverRule.RIGHT)
	if variants.has("stone_bridge"):
		river["bridges"] = [[lefts[rng.randi_range(0, lefts.size() - 1)], rights[rng.randi_range(0, rights.size() - 1)]]]
	if variants.has("two_crossings"):
		var largest_small: int = int(river["elephant"]) - 1
		if largest_small < 2:
			return null
		var first: Array = [lefts[rng.randi_range(0, lefts.size() - 1)], rights[rng.randi_range(0, rights.size() - 1)]]
		var second: Array = first
		for again: int in 10:
			if second != first:
				break
			second = [lefts[rng.randi_range(0, lefts.size() - 1)], rights[rng.randi_range(0, rights.size() - 1)]]
		if second == first:
			return null
		river["crossings"] = [first + [largest_small], second + [rng.randi_range(1, largest_small - 1)]]
	if variants.has("reverse"):
		river["reverse"] = true
	return river


## A river start (ICRA 3.2): the disks that stay on their bank (the elephants;
## the small ones where the river is reversed) stacked on one peg of the
## larger bank, the others stacked too or (half the time) spread over the
## land; the ferry empty. Measured 2026-10-17: the river only lengthens a
## solution where a stack must move on a bank with fewer pegs than the board
## (spread positions never made a base level: every one as short as classic).
static func _river_start(river: Dictionary, disks: int, rng: RandomNumberGenerator) -> PuzzleState:
	var banks: Array = river["banks"]
	var elephant: int = river["elephant"]
	var reverse: bool = river.get("reverse", false)
	var sides: Array = [_bank_pegs(banks, RiverRule.LEFT), _bank_pegs(banks, RiverRule.RIGHT)]
	var big: Array = sides[0] if sides[0].size() > sides[1].size() or (sides[0].size() == sides[1].size() and rng.randf() < 0.5) \
			else sides[1]
	var home: int = big[rng.randi_range(0, big.size() - 1)]
	var land: Array = sides[0] + sides[1]
	var other_home: int = land[rng.randi_range(0, land.size() - 1)]
	var spread: bool = rng.randf() < 0.5
	var layout: Array = []
	for i: int in banks.size():
		layout.append([])
	for size: int in range(disks, 0, -1):
		if (size >= elephant) != reverse:
			layout[home].append(size)
		else:
			layout[land[rng.randi_range(0, land.size() - 1)] if spread else other_home].append(size)
	return PuzzleState.new(layout)


## The pegs of `bank` (RiverRule.LEFT / RIGHT) in `banks`.
static func _bank_pegs(banks: Array, bank: int) -> Array:
	return range(banks.size()).filter(func(peg: int) -> bool: return banks[peg] == bank)


## A river goal for `start` (ICRA 3.2): the small disks cross to the other
## bank (the elephants where the river is reversed); where a bridge or the
## ferry lets elephants over, one or two elephants cross too (else they would
## never be used). The disks of a bank that stay move together to another peg
## of their bank, the crossing ones of a bank to one peg of the other; each
## peg sorted. The ferry starts and ends empty.
static func _river_goal(river: Dictionary, start: PuzzleState, variants: Array, rng: RandomNumberGenerator) -> PuzzleState:
	var banks: Array = river["banks"]
	var elephant: int = river["elephant"]
	var reverse: bool = river.get("reverse", false)
	var disks: int = start.get_disk_count()
	var crossing: Dictionary = {}
	for size: int in range(1, disks + 1):
		crossing[size] = (size >= elephant) == reverse
	if (variants.has("stone_bridge") or variants.has("ferry")) and not reverse:
		var elephants: Array = _shuffled(range(elephant, disks + 1), rng)
		for i: int in mini(rng.randi_range(1, 2), elephants.size()):
			crossing[elephants[i]] = true
	var sides: Array = [_bank_pegs(banks, RiverRule.LEFT), _bank_pegs(banks, RiverRule.RIGHT)]
	# Per bank and kind (staying, crossing) the one peg it goes to.
	var targets: Dictionary = {}
	var layout: Array = []
	for i: int in banks.size():
		layout.append([])
	for size: int in range(disks, 0, -1):
		var from: int = _peg_of(start, size)
		var bank: int = banks[from]
		var key: String = "%d/%s" % [bank, crossing[size]]
		if not targets.has(key):
			var pegs: Array = sides[1 - bank] if crossing[size] else sides[bank].filter(func(peg: int) -> bool: return peg != from)
			if pegs.is_empty():
				pegs = sides[bank]
			targets[key] = pegs[rng.randi_range(0, pegs.size() - 1)]
		layout[targets[key]].append(size)
	return PuzzleState.new(layout)


## The goal-setting modes' settings (ICRA section 2-3), drawn before the
## positions: {} without such a mode, null when the board cannot carry them.
## Kral: the largest disk crowned with a random gate, a vizier (one of the
## larger half) with a gate of its own, a narrow gate entered from one
## neighbour; or the odd and even towers ("Tək-Cüt") on two marked pegs.
static func _goal_shape(modes: Array, board: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var params: Dictionary = {}
	var pegs: int = board["pegs"]
	var disks: int = board["disks"]
	var variants: Array = board.get("variants", [])
	if modes.has(KingRule.ID):
		var king: Dictionary = {}
		var places: Array = _shuffled(range(pegs), rng)
		if variants.has("odd_even") or variants.has("goal_odd_even"):
			king["odd_even"] = [places[0], places[1]]
		else:
			var crowns: Array = [[disks, places[0]]]
			if variants.has("vizier"):
				crowns.append([rng.randi_range(maxi(disks / 2, 1), disks - 1), places[1]])
			king["crowns"] = crowns
			if variants.has("narrow_gate"):
				var narrow: Array = []
				for crown: Array in crowns:
					var gate: int = crown[1]
					var sides: Array = [gate - 1, gate + 1].filter(func(p: int) -> bool: return p >= 0 and p < pegs)
					narrow.append([gate, sides[rng.randi_range(0, sides.size() - 1)]])
				king["narrow"] = narrow
		params[KingRule.ID] = king
	if modes.has(CarpetRule.ID):
		var carpet: Variant = _carpet_shape(pegs, disks, variants, rng)
		if carpet == null:
			return null
		params[CarpetRule.ID] = carpet
	if modes.has(SumRule.ID):
		params[SumRule.ID] = _sum_shape(pegs, disks, variants, rng)
	return params


## Cəm's settings (ICRA 3.10), read off a random position so they can be met:
## its sums under the pegs; for "Ədalət" no numbers but equal sums (that board
## must split 1..n evenly, else the draw tries again); its counts too ("Cəm və
## hündürlük"); one peg doubled ("İkiqat qüllə"); for "Tək-cüt cəm" only each
## sum's parity on most pegs.
static func _sum_shape(pegs: int, disks: int, variants: Array, rng: RandomNumberGenerator) -> Dictionary:
	var model: PuzzleState = random_state(rng, pegs, disks)
	var sums: Array = []
	var counts: Array = []
	for stack: Array in model.pegs:
		sums.append(stack.reduce(func(a: int, b: int) -> int: return a + b, 0))
		counts.append(stack.size())
	var total: int = disks * (disks + 1) / 2
	var sum: Dictionary = {}
	if variants.has("fair") and total % pegs == 0:
		sum["fair"] = true
	elif variants.has("parity"):
		var parity: Array = []
		for value: int in sums:
			parity.append((2 if value % 2 == 0 else 1) if rng.randf() < 0.75 else 0)
		sum["parity"] = parity
	else:
		sum["sums"] = sums
	if variants.has("sum_and_height"):
		sum["counts"] = counts
	if variants.has("double_peg") and sum.has("sums"):
		var peg: int = rng.randi_range(0, pegs - 1)
		sum["double"] = peg
		sums[peg] = int(sums[peg]) * 2
	return sum


## Xalça's settings (ICRA 3.4): a silhouette of `disks` disks on `pegs` pegs,
## symmetric with its highest peg in the middle (a carpet's navel), uneven
## for "buta", three pegs repeated on a twin carpet's six; the navel's disk on
## top of the middle peg; for a coloured carpet the disks in two or three
## colours and the top colour of two or three pegs.
static func _carpet_shape(pegs: int, disks: int, variants: Array, rng: RandomNumberGenerator) -> Variant:
	var heights: Array = []
	if variants.has("twin"):
		if pegs != 6 or disks % 2 != 0:
			return null
		var half: Array = _composition(3, disks / 2, rng)
		heights = half + half
	elif variants.has("buta"):
		for again: int in 20:
			heights = _composition(pegs, disks, rng)
			var mirrored: Array = heights.duplicate()
			mirrored.reverse()
			if heights != mirrored:
				break
		var reversed: Array = heights.duplicate()
		reversed.reverse()
		if heights == reversed:
			return null
	else:
		# Rising to the middle: pairs from the edges in, the rest in the middle.
		heights.resize(pegs)
		heights.fill(0)
		var left: int = disks
		var pairs: int = pegs / 2
		# Every peg has a share where the disks allow it (1-3-5-3-1, not 0-0-9-0-0).
		var low: int = 1 if disks >= pegs + 2 else 0
		for i: int in pairs:
			var room: int = (left - (pegs % 2)) / (2 * (pairs - i) + (pegs % 2))
			var height: int = rng.randi_range(low, maxi(room, low))
			if pegs % 2 == 0 and i == pairs - 1:
				height = left / 2  # the middle pair takes the rest
			if 2 * height > left:
				height = left / 2
			heights[i] = height
			heights[pegs - 1 - i] = height
			left -= 2 * height
			low = height
		if pegs % 2 == 1:
			heights[pegs / 2] = left
		elif left > 0:
			return null
	var carpet: Dictionary = {"heights": heights}
	if variants.has("navel"):
		var middle: int = pegs / 2
		if int(heights[middle]) < 1:
			return null
		carpet["navel"] = [middle, rng.randi_range(1, disks)]
	if variants.has("coloured"):
		var hues: int = rng.randi_range(2, 3)
		var colours: Array = []
		for disk: int in disks:
			colours.append(rng.randi_range(0, hues - 1))
		var tops: Array = []
		tops.resize(pegs)
		tops.fill(-1)
		var filled: Array = _shuffled(range(pegs).filter(func(peg: int) -> bool: return int(heights[peg]) > 0), rng)
		for i: int in mini(rng.randi_range(2, 3), filled.size()):
			tops[filled[i]] = colours[rng.randi_range(0, disks - 1)]
		carpet["colours"] = colours
		carpet["tops"] = tops
	return carpet


## `total` split into `parts` random counts (each 0 or more).
static func _composition(parts: int, total: int, rng: RandomNumberGenerator) -> Array:
	var cuts: Array = []
	for i: int in parts - 1:
		cuts.append(rng.randi_range(0, total))
	cuts.sort()
	var counts: Array = []
	var previous: int = 0
	for cut: int in cuts:
		counts.append(cut - previous)
		previous = cut
	counts.append(total - previous)
	return counts


## "Mühasirə" (ICRA 3.1): the king, the largest disk, under the tallest stack
## (taller than every other).
static func _besieged(start: PuzzleState) -> bool:
	var king: int = start.get_disk_count()
	var home: int = _peg_of(start, king)
	for peg_index: int in start.get_peg_count():
		if peg_index != home and start.pegs[peg_index].size() >= start.pegs[home].size():
			return false
	return true


## "Tək-Cüt": the odd sizes stacked on `pegs_pair[0]`, the even ones on `pegs_pair[1]`.
static func _odd_even_state(pegs: int, disks: int, pegs_pair: Array) -> PuzzleState:
	var layout: Array = []
	for i: int in pegs:
		layout.append([])
	for size: int in range(disks, 0, -1):
		layout[pegs_pair[0] if size % 2 == 1 else pegs_pair[1]].append(size)
	return PuzzleState.new(layout)


## Where `path` leads from `start` under `rules`.
static func end_of(start: PuzzleState, path: Array[Move], rules: RuleSet) -> PuzzleState:
	var state: PuzzleState = start
	for move: Move in path:
		state = rules.apply_move_unchecked(state, move)
	var end: PuzzleState = PuzzleState.new(state.pegs)
	return end


## "Böyük Mübadilə" (ICRA 3.3): k disks of each colour on the end pegs, k =
## disks / colours. Two colours: the pure kind all white on the left (the
## stacks swap); the mixed kind ("mixed", "caravanserai": the colour rule)
## both ends mixed, the largest pair on the wrong ends; the goal every black
## disk on the left end, every white one on the right. Three colours ("Üç
## karvan"): white, black and red stacks on the left end, the middle peg and
## the right end, each going to the next one's place (white to black's, black
## to red's, red to white's). "mid_start": the start a few random legal moves
## on from there. Empty if the board does not fit.
static func _swap_positions(board: Dictionary, rng: RandomNumberGenerator) -> Array[PuzzleState]:
	var none: Array[PuzzleState] = []
	var variants: Array = board.get("variants", [])
	var pegs: int = board["pegs"]
	var colours: int = 3 if variants.has("three_caravans") else 2
	var k: int = int(board["disks"]) / colours
	if k < 2 or k * colours != int(board["disks"]) or pegs < 4:
		return none
	var last: int = pegs - 1
	var start: PuzzleState
	var goal: PuzzleState = swap_goal(pegs, k, colours)
	if colours == 3:
		start = swap_start_three(pegs, k)
	else:
		var mixed: bool = variants.has("mixed") or variants.has("caravanserai")
		var white_left: Array[bool] = []
		for size: int in range(k, 0, -1):
			white_left.append(true if not mixed or size == k else rng.randf() < 0.5)
		if mixed and white_left.all(func(left: bool) -> bool: return left):
			white_left[rng.randi_range(1, k - 1)] = false
		var layout: Array = []
		for i: int in pegs:
			layout.append([])
		for i: int in k:
			var size: int = k - i
			layout[0].append(ColorSwapRule.disk_of(size, white_left[i]))
			layout[last].append(ColorSwapRule.disk_of(size, not white_left[i]))
		start = PuzzleState.new(layout)
	if variants.has("mid_start"):
		# A few random legal moves on from the ends (the rules of the level).
		var params: Dictionary = {ColorSwapRule.ID: _swap_params(board, variants)}
		var rules: RuleSet = RuleSet.from_ids([ColorSwapRule.ID], params)
		var steps: int = rng.randi_range(3, 10)
		var state: PuzzleState = start
		for step: int in steps:
			var moves: Array[Move] = rules.get_legal_moves(state)
			if moves.is_empty():
				return none
			state = rules.apply_move_unchecked(state, moves[rng.randi_range(0, moves.size() - 1)])
		start = PuzzleState.new(state.pegs)
		if start.equals(goal):
			return none
	var pair: Array[PuzzleState] = [start, goal]
	return pair


## The homes of three caravans on `pegs` pegs: the left end, the middle, the
## right end.
static func swap_homes(pegs: int) -> Array[int]:
	return [0, pegs / 2, pegs - 1]


## The great exchange's goal: with two colours every black disk on the left
## end and every white one on the right; with three each caravan on the next
## one's home (white on black's, black on red's, red on white's).
static func swap_goal(pegs: int, k: int, colours: int) -> PuzzleState:
	var layout: Array = []
	for i: int in pegs:
		layout.append([])
	for colour: int in colours:
		var home: int = (pegs - 1 if colour == ColorSwapRule.WHITE else 0) if colours == 2 \
				else swap_homes(pegs)[(colour + 1) % 3]
		for size: int in range(k, 0, -1):
			layout[home].append(ColorSwapRule.disk_with(size, colour, colours))
	return PuzzleState.new(layout)


## Three caravans at home: white on the left end, black in the middle, red on
## the right end.
static func swap_start_three(pegs: int, k: int) -> PuzzleState:
	var layout: Array = []
	for i: int in pegs:
		layout.append([])
	for colour: int in 3:
		for size: int in range(k, 0, -1):
			layout[swap_homes(pegs)[colour]].append(ColorSwapRule.disk_with(size, colour, 3))
	return PuzzleState.new(layout)


## Whether every disk of an exchange position is on an end peg (two colours)
## or on its own caravan's home (three): not a start on the way ("mid_start").
static func swap_at_home(state: PuzzleState, colours: int) -> bool:
	var last: int = state.get_peg_count() - 1
	for peg_index: int in state.get_peg_count():
		for disk: int in state.pegs[peg_index]:
			var home: int = swap_homes(state.get_peg_count())[ColorSwapRule.colour_of(disk, 3)] if colours == 3 else -1
			if (colours == 2 and peg_index != 0 and peg_index != last) or (colours == 3 and peg_index != home):
				return false
	return true


## The great exchange's settings for `variants`: the colour rule for the
## mixed kind and the caravanserai (a middle peg where colours may mix), three
## colours for "Üç karvan".
static func _swap_params(board: Dictionary, variants: Array) -> Dictionary:
	var params: Dictionary = {"colour": variants.has("mixed") or variants.has("caravanserai")}
	if variants.has("three_caravans"):
		params["colours"] = 3
	if variants.has("caravanserai"):
		params["caravanserai"] = int(board["pegs"]) / 2
	return params


## A start and a goal the shaped rules allow (`shape` from _shape()): a
## balance board's from all its allowed positions; otherwise disk by disk,
## largest first, each on a peg where the rules allow it there. The turned
## stripes' goal is one colour on one peg and the other on another (the World
## 3-4 spec); others are a tower now and then. Empty if none was found.
static func _shaped_positions(modes: Array, shape: Dictionary, board: Dictionary,
		rng: RandomNumberGenerator) -> Array[PuzzleState]:
	var none: Array[PuzzleState] = []
	var pegs: int = board["pegs"]
	var disks: int = board["disks"]
	var ids: Array[String] = [ClassicHanoiRule.ID]
	for mode: String in SHAPED:
		if modes.has(mode):
			ids.append(mode)
	# The positions are drawn as they stand before anything is painted or turned.
	var drawing: Dictionary = (shape["params"] as Dictionary).duplicate(true)
	if drawing.has(StripesRule.ID):
		(drawing[StripesRule.ID] as Dictionary).erase("paint")
	if drawing.has(ElementsRule.ID):
		(drawing[ElementsRule.ID] as Dictionary).erase("turning")
		(drawing[ElementsRule.ID] as Dictionary).erase("changing")
	var rules: RuleSet = RuleSet.from_ids(ids, drawing)
	if rules == null:
		return none
	var keep: Array[int] = shape["keep"]
	var pair: Array[PuzzleState] = []
	if modes.has(BalanceRule.ID):
		# Random balanced pairs lie close together (measured 2026-10-17: mostly
		# 5-15 moves), so the goal is taken at the wanted distance from the start.
		var allowed: Array = _balanced_positions(rules, ids, drawing, pegs, disks)
		if allowed.size() < 2:
			return none
		var start: PuzzleState = allowed[rng.randi_range(0, allowed.size() - 1)]
		var full: RuleSet = RuleSet.from_ids(ids, shape["params"])
		var far: Array[PuzzleState] = _positions_at(full, start, int(board.get("low", 1)), int(board.get("high", 70)))
		if far.is_empty():
			return none
		pair.append(start)
		pair.append(far[rng.randi_range(0, far.size() - 1)])
		return pair
	var river: Dictionary = shape["params"].get(RiverRule.ID, {})
	var start: PuzzleState = _river_start(river, disks, rng) if not river.is_empty() \
			else _allowed_state(rules, pegs, disks, keep, rng)
	if start == null:
		return none
	var goal: PuzzleState = null
	var stripes: Dictionary = shape["params"].get(StripesRule.ID, {})
	if not river.is_empty():
		goal = _river_goal(river, start, board.get("variants", []), rng)
		if goal == null or not rules.is_state_valid(goal):
			return none
	elif stripes.get("inverse", false):
		var places: Array = _shuffled(range(pegs).filter(func(p: int) -> bool: return not keep.has(p)), rng)
		var layout: Array = []
		for i: int in pegs:
			layout.append([])
		for size: int in range(disks, 0, -1):
			layout[places[0] if size % 2 == 1 else places[1]].append(size)
		goal = PuzzleState.new(layout)
	elif rng.randf() < board.get("tower", TOWER_GOAL_CHANCE):
		var places: Array = range(pegs).filter(func(p: int) -> bool: return not keep.has(p))
		goal = tower_state(pegs, disks, places[rng.randi_range(0, places.size() - 1)])
		if not rules.is_state_valid(goal):
			goal = null
	if goal == null:
		goal = _allowed_state(rules, pegs, disks, keep, rng)
	# A narrow bridge cuts the road for the larger disks and a one-way road
	# lets disks cross one way only: a goal they cannot reach is drawn again
	# (otherwise nearly every draw had no solution, measured 2026-10-17).
	var road: Dictionary = shape["params"].get(AdjacentPegsRule.ID, {})
	for again: int in 20:
		if goal == null or _road_allows(road, start, goal):
			break
		goal = _allowed_state(rules, pegs, disks, keep, rng)
	if goal == null or not _road_allows(road, start, goal):
		return none
	pair.append(start)
	pair.append(goal)
	return pair


## Whether every disk can get from its peg in `start` to its peg in `goal`
## past `road`'s narrow bridges (the larger ones stay on their side) and
## one-way roads (crossed only their way).
static func _road_allows(road: Dictionary, start: PuzzleState, goal: PuzzleState) -> bool:
	var oasis: int = (road.get("oasis", [-1, -1]) as Array)[0]
	var place: Callable = func(peg: int) -> int: return peg - 1 if oasis >= 0 and peg > oasis else peg
	var crossings: Array = []
	for bridge: Array in road.get("bridges", []):
		crossings.append([bridge[0], bridge[1], bridge[2], false])
	for arrow: Array in road.get("one_way", []):
		crossings.append([arrow[0], arrow[1], 0, true])
	for crossing: Array in crossings:
		var cut: float = (place.call(crossing[0]) + place.call(crossing[1])) * 0.5
		var forward: bool = place.call(crossing[1]) > place.call(crossing[0])
		for peg: int in start.get_peg_count():
			for disk: int in start.pegs[peg]:
				var to_peg: int = _peg_of(goal, disk)
				if peg == oasis or to_peg == oasis:
					continue
				var before: bool = place.call(peg) > cut
				var after: bool = place.call(to_peg) > cut
				if before == after:
					continue
				if not crossing[3] and disk > crossing[2]:
					return false
				if crossing[3] and after != forward:
					return false
	return true


## A position of `disks` on `pegs` the rules allow, the `keep` pegs empty:
## the disks largest first, each on a random peg where the rules still allow
## the position; null after a few dead ends.
static func _allowed_state(rules: RuleSet, pegs: int, disks: int, keep: Array[int],
		rng: RandomNumberGenerator) -> PuzzleState:
	for attempt: int in 20:
		var layout: Array = []
		for i: int in pegs:
			layout.append([])
		var placed: bool = true
		for size: int in range(disks, 0, -1):
			var choices: Array = []
			for peg: int in pegs:
				if keep.has(peg):
					continue
				layout[peg].append(size)
				if rules.is_state_valid(PuzzleState.new(layout)):
					choices.append(peg)
				layout[peg].pop_back()
			if choices.is_empty():
				placed = false
				break
			layout[choices[rng.randi_range(0, choices.size() - 1)]].append(size)
		if placed:
			return PuzzleState.new(layout)
	return null


## The positions whose shortest way from `start` under `rules` takes `low` to
## `high` moves (a breadth-first search; for the small spaces of a balance
## board).
static func _positions_at(rules: RuleSet, start: PuzzleState, low: int, high: int) -> Array[PuzzleState]:
	var found: Array[PuzzleState] = []
	var seen: Dictionary = {rules.search_key(start): true}
	var first: Dictionary = {start.hash_key(): true}
	var frontier: Array[PuzzleState] = [start]
	var depth: int = 0
	while not frontier.is_empty() and depth < high:
		depth += 1
		var next: Array[PuzzleState] = []
		for state: PuzzleState in frontier:
			for move: Move in rules.get_legal_moves(state):
				var after: PuzzleState = rules.apply_move_unchecked(state, move)
				var key: String = rules.search_key(after)
				if seen.has(key):
					continue
				seen[key] = true
				next.append(after)
				var place: String = after.hash_key()
				if not first.has(place):
					first[place] = true
					if depth >= low:
						found.append(after)
		frontier = next
	return found


## Every position of a balance board the rules allow (stacks sorted), once
## per board and settings.
static func _balanced_positions(rules: RuleSet, ids: Array[String], params: Dictionary, pegs: int, disks: int) -> Array:
	var key: String = "%d/%d %s %s" % [pegs, disks, str(ids), JSON.stringify(params)]
	if _balanced.has(key):
		return _balanced[key]
	var found: Array = []
	for code: int in int(pow(pegs, disks)):
		var layout: Array = []
		for i: int in pegs:
			layout.append([])
		var rest: int = code
		for size: int in range(disks, 0, -1):
			layout[rest % pegs].append(size)
			rest /= pegs
		var state: PuzzleState = PuzzleState.new(layout)
		if rules.is_state_valid(state):
			found.append(state)
	_balanced[key] = found
	return found


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
## a tap never opens it). Current decisions 2026-10-16 (B.1, B.2, B.5): a
## "full_hidden" level boxes every peg that holds a disk (one disk is enough,
## no early use); an "empty_box" level boxes any pegs that hold a disk plus
## its one empty box (no early use). No other box is ever empty. Empty when
## the draw does not allow them.
static func _boxes(start: PuzzleState, path: Array[Move], board: Dictionary, variants: Array, sealed: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var none: Array[int] = []
	var boxes: Array[int] = []
	if variants.has("full_hidden"):
		for peg_index: int in start.get_peg_count():
			if not start.pegs[peg_index].is_empty():
				boxes.append(peg_index)
		return boxes if boxes.size() >= 2 else none
	if sealed != -1:
		boxes.append(sealed)
	var wanted: int = int(board.get("covered", 1))
	if variants.has("empty_box"):
		# Relaxed luck rule (chapter waves 5a, current decisions B.5): any peg
		# with a disk may be a box, used early or not, and one empty peg more.
		for peg_index: int in _shuffled(range(start.get_peg_count()), rng):
			if boxes.size() < wanted and not boxes.has(peg_index) and not start.pegs[peg_index].is_empty():
				boxes.append(peg_index)
		var empty: Array = range(start.get_peg_count()).filter(func(p: int) -> bool:
			return start.pegs[p].is_empty() and not boxes.has(p))
		if boxes.size() < wanted or empty.is_empty():
			return none
		boxes.append(empty[rng.randi_range(0, empty.size() - 1)])
		boxes.sort()
		return boxes
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
