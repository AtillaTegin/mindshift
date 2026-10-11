class_name Level
extends RefCounted
## One puzzle level (format: spec 4.5). Classic levels are stored as
## data/levels/<difficulty>/<difficulty>_NNN.json; levels with a special
## mechanic as data/levels/mechanics/<name>.json, using the optional keys.
## Where a level sits on the level path is data/levels/path.json (LevelCatalog).

const TWO_STAR_FACTOR: float = 1.25
## mechanic() of a level with plain Hanoi rules and nothing covered.
const CLASSIC: String = "classic"
## Top-level keys, in the order they are written.
const KEYS: Array[String] = ["id", "difficulty", "pegs", "disks", "start", "goal", "rules",
		"min_moves", "solution_path", "star_thresholds", "time_limit_seconds"]
## Keys a level may leave out; written only when not empty, so files without
## them (all 200 main levels) keep exactly their old form.
const OPTIONAL_KEYS: Array[String] = ["rule_params", "covered_pegs"]

var id: int = 0
var difficulty: String = ""
var start: PuzzleState
var goal: PuzzleState
var rule_ids: Array[String] = []
## Rule id -> that rule's settings ("rule_params"); empty for most levels.
var rule_params: Dictionary = {}
## Pegs that start under fog ("covered_pegs", bonus mechanics addendum 2):
## only their top disk shows until a move uses the peg. Purely visual.
var covered_pegs: Array[int] = []
var min_moves: int = 0
var solution_path: Array[Move] = []
## Highest move count that still earns two stars (spec 4.6).
var two_star_moves: int = 0
## Seconds to solve the level, or null. Kept in the format for a later
## "against the clock" mode; v1 ships no timed levels (LevelValidator enforces it).
var time_limit_seconds: Variant = null


## Spec 4.6: two stars up to round(min_moves * 1.25) moves.
static func two_star_threshold(p_min_moves: int) -> int:
	return roundi(p_min_moves * TWO_STAR_FACTOR)


## Spec 4.6: 3 stars for an optimal solution, 2 up to the two-star threshold,
## otherwise 1 (solved, but not efficiently).
func stars_for_moves(moves: int) -> int:
	if moves <= min_moves:
		return 3
	if moves <= two_star_moves:
		return 2
	return 1


## A level whose min_moves and star thresholds come from `path`.
static func create(p_id: int, p_difficulty: String, p_start: PuzzleState, p_goal: PuzzleState,
		p_rule_ids: Array[String], path: Array[Move], p_rule_params: Dictionary = {}) -> Level:
	var level: Level = Level.new()
	level.id = p_id
	level.difficulty = p_difficulty
	level.start = p_start.duplicate_state()
	level.goal = p_goal.duplicate_state()
	level.rule_ids.assign(p_rule_ids)
	level.rule_params = p_rule_params.duplicate(true)
	level.solution_path.assign(path)
	level.min_moves = path.size()
	level.two_star_moves = two_star_threshold(level.min_moves)
	return level


func get_peg_count() -> int:
	return start.get_peg_count()


func get_disk_count() -> int:
	return start.get_disk_count()


## Null if a rule id is unknown or its rule_params do not fit (reason in errors).
func get_rule_set(errors: Array[String] = []) -> RuleSet:
	return RuleSet.from_ids(rule_ids, rule_params, errors)


## What makes the level special: the first rule beyond classic Hanoi (e.g.
## "frozen_disk"), "covered_pegs" for fog, or CLASSIC. It picks the level's
## visual dress; it is never shown as a category.
func mechanic() -> String:
	for rule_id: String in rule_ids:
		if rule_id != ClassicHanoiRule.ID:
			return rule_id
	if not covered_pegs.is_empty():
		return "covered_pegs"
	return CLASSIC


func to_dict() -> Dictionary:
	var path: Array = []
	for move: Move in solution_path:
		path.append(move.to_array())
	var data: Dictionary = {
		"id": id,
		"difficulty": difficulty,
		"pegs": get_peg_count(),
		"disks": get_disk_count(),
		"start": start.to_array(),
		"goal": goal.to_array(),
		"rules": rule_ids.duplicate(),
		"min_moves": min_moves,
		"solution_path": path,
		"star_thresholds": {"three": min_moves, "two": two_star_moves},
		"time_limit_seconds": time_limit_seconds,
	}
	# Optional keys only when used, so main levels keep the exact spec format.
	if not rule_params.is_empty():
		data["rule_params"] = rule_params.duplicate(true)
	if not covered_pegs.is_empty():
		data["covered_pegs"] = covered_pegs.duplicate()
	return data


## One key per line with compact values, so files stay short and diff well.
func to_json() -> String:
	var data: Dictionary = to_dict()
	var lines: PackedStringArray = PackedStringArray()
	for key: String in KEYS + OPTIONAL_KEYS:
		if data.has(key):
			lines.append("  %s: %s" % [JSON.stringify(key), JSON.stringify(data[key])])
	return "{\n%s\n}\n" % ",\n".join(lines)


func save_file(path: String) -> Error:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_json())
	file.close()
	return OK


## Reads a level file. Problems go to `errors`; returns null if the file cannot
## be read or parsed into a level.
static func load_file(path: String, errors: Array[String]) -> Level:
	if not FileAccess.file_exists(path):
		errors.append("file not found: %s" % path)
		return null
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		errors.append("invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return null
	return from_dict(json.data, errors)


## Builds a level from parsed JSON. Type problems go to `errors` and make the
## result null; consistency is checked separately by check().
static func from_dict(data: Variant, errors: Array[String]) -> Level:
	if typeof(data) != TYPE_DICTIONARY:
		errors.append("level must be a JSON object")
		return null
	var error_count: int = errors.size()
	for key: String in KEYS:
		if not data.has(key):
			errors.append("missing key \"%s\"" % key)
	for key: Variant in data:
		if not key in KEYS and not key in OPTIONAL_KEYS:
			errors.append("unknown key \"%s\"" % str(key))
	if errors.size() > error_count:
		return null

	var level: Level = Level.new()
	level.id = _read_int(data, "id", errors)
	if typeof(data["difficulty"]) == TYPE_STRING:
		level.difficulty = data["difficulty"]
	else:
		errors.append("\"difficulty\" must be a string")
	level.start = PuzzleState.from_array(data["start"])
	if level.start == null:
		errors.append("\"start\" must be an array of arrays of integers")
	level.goal = PuzzleState.from_array(data["goal"])
	if level.goal == null:
		errors.append("\"goal\" must be an array of arrays of integers")
	if typeof(data["rules"]) == TYPE_ARRAY and data["rules"].all(func(r: Variant) -> bool: return typeof(r) == TYPE_STRING):
		level.rule_ids.assign(data["rules"])
	else:
		errors.append("\"rules\" must be an array of strings")
	var params: Variant = data.get("rule_params", {})
	if typeof(params) == TYPE_DICTIONARY and params.values().all(func(v: Variant) -> bool: return typeof(v) == TYPE_DICTIONARY):
		level.rule_params = _whole_numbers_as_ints(params)
	else:
		errors.append("\"rule_params\" must be an object of objects")
	var covered: Variant = data.get("covered_pegs", [])
	if typeof(covered) == TYPE_ARRAY and covered.all(func(v: Variant) -> bool: return typeof(_whole_numbers_as_ints(v)) == TYPE_INT):
		level.covered_pegs.assign(_whole_numbers_as_ints(covered))
	else:
		errors.append("\"covered_pegs\" must be an array of peg indices")
	level.min_moves = _read_int(data, "min_moves", errors)
	if typeof(data["solution_path"]) == TYPE_ARRAY:
		for pair: Variant in data["solution_path"]:
			var move: Move = Move.from_array(pair)
			if move == null:
				errors.append("\"solution_path\" entries must be [from, to] integer pairs")
				break
			level.solution_path.append(move)
	else:
		errors.append("\"solution_path\" must be an array")
	var stars: Variant = data["star_thresholds"]
	if typeof(stars) == TYPE_DICTIONARY and stars.size() == 2 and stars.has("three") and stars.has("two"):
		if _read_int(stars, "three", errors) != level.min_moves:
			errors.append("star_thresholds.three must equal min_moves")
		level.two_star_moves = _read_int(stars, "two", errors)
	else:
		errors.append("\"star_thresholds\" must be {\"three\": int, \"two\": int}")
	var limit: Variant = data["time_limit_seconds"]
	if limit == null or (typeof(limit) in [TYPE_INT, TYPE_FLOAT] and limit > 0):
		level.time_limit_seconds = limit
	else:
		errors.append("\"time_limit_seconds\" must be null or a positive number")
	# pegs/disks are derived from start; they must agree with it.
	var pegs: int = _read_int(data, "pegs", errors)
	var disks: int = _read_int(data, "disks", errors)
	if level.start != null and (pegs != level.start.get_peg_count() or disks != level.start.get_disk_count()):
		errors.append("\"pegs\"/\"disks\" (%d/%d) do not match start (%d/%d)" % [
				pegs, disks, level.start.get_peg_count(), level.start.get_disk_count()])
	return level if errors.size() == error_count else null


## Consistency checks that need no search: tier ranges, disk sets, rule ids,
## state validity, solution_path replay and star thresholds. Appends problems
## to `errors`. Optimality of min_moves is checked by LevelValidator.
func check(errors: Array[String]) -> void:
	if not Difficulty.is_known(difficulty):
		errors.append("unknown difficulty \"%s\"" % difficulty)
		return
	if not Difficulty.accepts_moves(difficulty, min_moves):
		errors.append("min_moves %d is outside %s (%s)" % [min_moves, difficulty, Difficulty.describe_moves(difficulty)])
	if mechanic() == CLASSIC:
		if not Difficulty.accepts_id(difficulty, id):
			errors.append("id %d is outside the %s range" % [id, difficulty])
		if not Difficulty.accepts_size(difficulty, get_peg_count(), get_disk_count()):
			errors.append("%d pegs / %d disks is not a %s size" % [get_peg_count(), get_disk_count(), difficulty])
	else:
		# A mechanic may need another size than the classic tier (a frozen disk
		# only matters with 4 pegs and 6+ disks); it has its own id range.
		if not Difficulty.is_mechanic_id(id):
			errors.append("id %d is outside the mechanic range" % id)
		if not Difficulty.accepts_mechanic_size(get_peg_count(), get_disk_count()):
			errors.append("%d pegs / %d disks is not a mechanic level size" % [get_peg_count(), get_disk_count()])
	if two_star_moves != two_star_threshold(min_moves):
		errors.append("star_thresholds.two is %d, expected round(%d * 1.25) = %d" % [
				two_star_moves, min_moves, two_star_threshold(min_moves)])
	for peg_index: int in covered_pegs:
		if peg_index < 0 or peg_index >= get_peg_count() or covered_pegs.count(peg_index) > 1:
			errors.append("covered_pegs %s must be distinct peg indices" % str(covered_pegs))
			break
	if goal.get_peg_count() != get_peg_count():
		errors.append("goal has %d pegs, start has %d" % [goal.get_peg_count(), get_peg_count()])
		return
	var expected_disks: Array[int] = []
	for size: int in range(1, get_disk_count() + 1):
		expected_disks.append(size)
	if _sorted_disks(start) != expected_disks or _sorted_disks(goal) != expected_disks:
		errors.append("start and goal must both hold exactly the disks 1..%d" % get_disk_count())
		return
	var rule_errors: Array[String] = []
	var rules: RuleSet = get_rule_set(rule_errors)
	if rules == null or rule_ids.is_empty():
		errors.append("rules %s are empty or unknown%s" % [str(rule_ids),
				"" if rule_errors.is_empty() else ": " + "; ".join(rule_errors)])
		return
	if not rules.is_state_valid(start):
		errors.append("start is not a valid position")
	if not rules.is_state_valid(goal):
		errors.append("goal is not a valid position")
	if start.equals(goal):
		errors.append("start equals goal")
	if solution_path.size() != min_moves:
		errors.append("solution_path has %d moves, min_moves is %d" % [solution_path.size(), min_moves])
	var state: PuzzleState = start
	for i: int in solution_path.size():
		state = rules.apply_move(state, solution_path[i])
		if state == null:
			errors.append("solution_path move %d (%s) is illegal" % [i + 1, str(solution_path[i])])
			return
	if not state.equals(goal):
		errors.append("solution_path does not end at the goal")


## JSON numbers parse as floats; whole ones become ints again so a level writes
## back exactly as it was read ("disk_size": 2, not 2.0).
static func _whole_numbers_as_ints(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if is_finite(value) and value == floorf(value) else value
		TYPE_DICTIONARY:
			var copy: Dictionary = {}
			for key: Variant in value:
				copy[key] = _whole_numbers_as_ints(value[key])
			return copy
		TYPE_ARRAY:
			return (value as Array).map(_whole_numbers_as_ints)
	return value


static func _read_int(data: Dictionary, key: String, errors: Array[String]) -> int:
	var value: Variant = data[key]
	if typeof(value) == TYPE_INT or (typeof(value) == TYPE_FLOAT and is_finite(value) and value == floorf(value)):
		return int(value)
	errors.append("\"%s\" must be an integer" % key)
	return 0


static func _sorted_disks(state: PuzzleState) -> Array[int]:
	var disks: Array[int] = []
	for peg: Array in state.pegs:
		for disk: int in peg:
			disks.append(disk)
	disks.sort()
	return disks
