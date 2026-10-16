extends SceneTree
## Builds the pilot levels of Güzgü "Əks-səda" (Fəsil Sistemi v1.2, section 6:
## 4-5 pilots and a report before its chapter), deterministic:
##   godot --headless --path . --script res://prototype/pilots/pilot_builder.gd
## Each pilot: random top start and goal, a bottom board that is the top
## start's mirror with one to three disks moved elsewhere, the goal the top
## goal with its mirror below. Kept only if the echo solution is at least
## RATIO times the top board's own and in the pilot's move range. Prints the
## report numbers.

const DIR: String = "res://prototype/pilots"
const RATIO: float = 1.3
const SEED: int = 20261016
## [file, pegs per board, disks per board, fewest moves, most moves]
const PILOTS: Array = [
	["mirror_1.json", 3, 3, 7, 11],
	["mirror_2.json", 4, 4, 9, 12],
	["mirror_3.json", 3, 4, 13, 17],
	["mirror_4.json", 3, 4, 18, 23],
	["mirror_5.json", 3, 5, 26, 33],
]
const FIRST_ID: int = 90001
## Tərəzi levels to look at the new balance scale (section 5) before its
## chapter: [file, pegs, disks, tolerance, fewest moves, most moves]; the
## tolerance in the range where the rule works (section 5.5).
const BALANCE: Array = [
	["balance_1.json", 4, 5, 6, 8, 13],
	["balance_2.json", 4, 6, 8, 14, 25],
	["balance_3.json", 6, 5, 4, 5, 8],
]
const BALANCE_FIRST_ID: int = 90101


func _initialize() -> void:
	var ok: bool = true
	for i: int in BALANCE.size():
		var spec: Array = BALANCE[i]
		var scale: Level = build_balance(spec[1], spec[2], spec[3], spec[4], spec[5], SEED + 100 + i, BALANCE_FIRST_ID + i)
		if scale == null:
			printerr("%s: no level found" % spec[0])
			ok = false
			continue
		scale.save_file("%s/%s" % [DIR, spec[0]])
		print("%s: %d pegs / %d disks, limit %d, %d moves" % [spec[0], spec[1], spec[2], spec[3], scale.min_moves])
	for i: int in PILOTS.size():
		var spec: Array = PILOTS[i]
		var level: Level = build(spec[1], spec[2], spec[3], spec[4], SEED + i, FIRST_ID + i)
		if level == null:
			printerr("%s: no pilot found" % spec[0])
			ok = false
			continue
		level.save_file("%s/%s" % [DIR, spec[0]])
		print("%s: %d pegs / %d disks per board, %d moves (top alone %d, x%.2f), %s" % [spec[0], spec[1], spec[2],
				level.min_moves, _top_alone(level), float(level.min_moves) / _top_alone(level), level.difficulty])
	quit(0 if ok else 1)


static func build(pegs: int, disks: int, low: int, high: int, seed_value: int, id: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rule_ids: Array[String] = ["classic_hanoi", "mirror"]
	var rules: RuleSet = RuleSet.from_ids(rule_ids)
	for attempt: int in 3000:
		var top: PuzzleState = LevelForge.random_state(rng, pegs, disks)
		var top_goal: PuzzleState = LevelForge.tower_state(pegs, disks, rng.randi_range(0, pegs - 1)) \
				if rng.randf() < 0.5 else LevelForge.random_state(rng, pegs, disks)
		if top.equals(top_goal):
			continue
		var bottom: Array = _shifted(MirrorRule.mirrored(top.pegs, disks), disks, rng.randi_range(1, 3), rng)
		if JSON.stringify(bottom) == JSON.stringify(MirrorRule.mirrored(top.pegs, disks)):
			continue
		var start: PuzzleState = PuzzleState.new(top.pegs + bottom)
		var goal: PuzzleState = PuzzleState.new(top_goal.pegs + MirrorRule.mirrored(top_goal.pegs, disks))
		var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
		var moves: int = result["min_moves"]
		if not result["solvable"] or moves < low or moves > high:
			continue
		var alone: int = Solver.solve(top, top_goal, RuleSet.classic())["min_moves"]
		if moves < RATIO * alone:
			continue
		return Level.create(id, Difficulty.tier_for_moves(moves), start, goal, rule_ids, result["path"])
	return null


## A Tərəzi level between two positions within `tolerance` (start and goal
## too, the user's decision), where the scales make it longer than plain Hanoi.
static func build_balance(pegs: int, disks: int, tolerance: int, low: int, high: int, seed_value: int, id: int) -> Level:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var rule_ids: Array[String] = ["classic_hanoi", "balance"]
	var params: Dictionary = {"balance": {"tolerance": tolerance}}
	var rules: RuleSet = RuleSet.from_ids(rule_ids, params)
	var balanced: Array[PuzzleState] = []
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
			balanced.append(state)
	for attempt: int in 3000:
		var start: PuzzleState = balanced[rng.randi_range(0, balanced.size() - 1)]
		var goal: PuzzleState = balanced[rng.randi_range(0, balanced.size() - 1)]
		if start.equals(goal):
			continue
		var result: Dictionary = Solver.solve(start, goal, rules, LevelValidator.SOLVER_MAX_STATES)
		var moves: int = result["min_moves"]
		if not result["solvable"] or moves < low or moves > high:
			continue
		if Solver.solve(start, goal, RuleSet.classic())["min_moves"] >= moves:
			continue
		return Level.create(id, Difficulty.tier_for_moves(moves), start, goal, rule_ids, result["path"], params)
	return null


## A bottom board (disks numbered from `offset` + 1) with `count` of its disks
## put on other random pegs, every peg kept sorted.
static func _shifted(bottom: Array, offset: int, count: int, rng: RandomNumberGenerator) -> Array:
	var peg_of: Dictionary = {}
	for peg_index: int in bottom.size():
		for disk: int in bottom[peg_index]:
			peg_of[disk] = peg_index
	var disks: Array = peg_of.keys()
	for i: int in count:
		peg_of[disks[rng.randi_range(0, disks.size() - 1)]] = rng.randi_range(0, bottom.size() - 1)
	var layout: Array = []
	for i: int in bottom.size():
		layout.append([])
	for disk: int in range(offset + disks.size(), offset, -1):
		layout[peg_of[disk]].append(disk)
	return layout


## The top board's own shortest solution.
static func _top_alone(level: Level) -> int:
	var half: int = level.get_peg_count() / 2
	var top: PuzzleState = PuzzleState.new(level.start.pegs.slice(0, half))
	var goal: PuzzleState = PuzzleState.new(level.goal.pegs.slice(0, half))
	return Solver.solve(top, goal, RuleSet.classic())["min_moves"]
