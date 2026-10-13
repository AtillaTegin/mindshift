class_name ColorGoal
extends RefCounted
## The goal of a "Birləşmə Tapmacası" (combination puzzle) level, read by
## colour: its disks are all of one size and only their colour counts, so two
## disks of one colour are interchangeable. The goal always covers every disk
## on the board (correction v2, error 1: the colours of the goal are exactly
## the colours of the disks, see check()).
## - SORT ("Sadə Yığım"): every colour gathered on a peg of its own (any peg);
##   each peg that holds disks holds one colour, and all of it.
## - PATTERN ("Konkret Kombinasiya"): every peg shows exactly its own colour
##   sequence (`targets[peg]`, bottom -> top; an empty list for a peg that ends
##   empty), user decision 2026-10-13: a full sequence for every peg.
## Positions are compared as one string of colour letters per peg (LETTERS), the
## same form CombinationSolver searches in.

const SORT: String = "sort"
const PATTERN: String = "pattern"
const KINDS: Array[String] = [SORT, PATTERN]
## Disk colours of the combination puzzle and their one-letter codes (each
## colour also has its own shape, DiskSymbols).
const LETTERS: Dictionary = {"red": "r", "blue": "b", "yellow": "y", "green": "g", "purple": "p", "orange": "o",
		"pink": "k"}

var kind: String = SORT
## PATTERN: the colours each peg must show, bottom -> top.
var targets: Array[Array] = []


static func sort() -> ColorGoal:
	return ColorGoal.new()


static func pattern(p_targets: Array) -> ColorGoal:
	var goal: ColorGoal = ColorGoal.new()
	goal.kind = PATTERN
	for target: Array in p_targets:
		goal.targets.append(target.duplicate())
	return goal


## Reads `{"kind": "sort"}` or `{"kind": "pattern", "pegs": [[...], [...], []]}`;
## null and a reason in `errors` if it does not fit.
static func from_dict(data: Variant, errors: Array[String]) -> ColorGoal:
	if typeof(data) != TYPE_DICTIONARY or not KINDS.has(data.get("kind")):
		errors.append("\"color_goal\" must be {\"kind\": \"sort\"} or {\"kind\": \"pattern\", \"pegs\": [[colours], ...]}")
		return null
	if data["kind"] == SORT:
		return sort() if data.size() == 1 else _fail("a sort goal takes no other keys", errors)
	var pegs: Variant = data.get("pegs")
	if typeof(pegs) != TYPE_ARRAY or data.size() != 2:
		return _fail("a pattern goal needs \"pegs\": one colour list per peg", errors)
	for target: Variant in pegs:
		if typeof(target) != TYPE_ARRAY or not target.all(func(c: Variant) -> bool: return typeof(c) == TYPE_STRING):
			return _fail("each pattern peg must be a list of colour names", errors)
	return pattern(pegs)


func to_dict() -> Dictionary:
	if kind == SORT:
		return {"kind": SORT}
	var pegs: Array = []
	for target: Array in targets:
		pegs.append(target.duplicate())
	return {"kind": PATTERN, "pegs": pegs}


## Each peg of `state` as a string of colour letters, bottom -> top.
static func letters_of(state: PuzzleState, disk_colors: Array[String]) -> PackedStringArray:
	var pegs: PackedStringArray = PackedStringArray()
	for stack: Array in state.pegs:
		var text: String = ""
		for disk: int in stack:
			text += LETTERS[disk_colors[disk - 1]]
		pegs.append(text)
	return pegs


static func letter_of(color_name: String) -> String:
	return LETTERS[color_name]


static func colour_of(letter: String) -> String:
	return LETTERS.find_key(letter)


func is_met(state: PuzzleState, disk_colors: Array[String]) -> bool:
	return matches(letters_of(state, disk_colors))


## Whether pegs given as colour letters (letters_of) meet the goal.
func matches(pegs: PackedStringArray) -> bool:
	if kind == PATTERN:
		return pegs == target_letters()
	var seen: String = ""
	for text: String in pegs:
		if text.is_empty():
			continue
		var letter: String = text[0]
		if seen.contains(letter) or text.count(letter) != text.length():
			return false
		seen += letter
	return true


## PATTERN: each peg's target as a string of colour letters.
func target_letters() -> PackedStringArray:
	var pegs: PackedStringArray = PackedStringArray()
	for target: Array in targets:
		var text: String = ""
		for color_name: String in target:
			text += LETTERS[color_name]
		pegs.append(text)
	return pegs


## The colours the goal names: every colour of a sort goal's level (it names
## them all), the colours of a pattern's targets.
func goal_colours(disk_colors: Array[String]) -> Array[String]:
	var colours: Array[String] = []
	var source: Array = disk_colors.duplicate() if kind == SORT else []
	for target: Array in targets:
		source.append_array(target)
	for color_name: String in source:
		if not colours.has(color_name):
			colours.append(color_name)
	colours.sort()
	return colours


## Disks already in place, peg by peg: PATTERN, how many at the bottom of each
## peg match its target; SORT, a finished peg (one colour, all of it) counts
## all its disks. At progress_total() the goal is met.
func progress(state: PuzzleState, disk_colors: Array[String]) -> int:
	var pegs: PackedStringArray = letters_of(state, disk_colors)
	var done: int = 0
	for peg_index: int in pegs.size():
		done += placed_on(pegs, peg_index)
	return done


## Disks in place on peg `peg_index` (see progress()).
func placed_on(pegs: PackedStringArray, peg_index: int) -> int:
	var text: String = pegs[peg_index]
	if kind == SORT:
		return text.length() if is_peg_finished(pegs, peg_index) else 0
	var target: String = target_letters()[peg_index]
	var count: int = 0
	while count < text.length() and count < target.length() and text[count] == target[count]:
		count += 1
	return count


func progress_total(disk_colors: Array[String]) -> int:
	return disk_colors.size()


## SORT: peg `peg_index` holds every disk of one colour and nothing else.
static func is_peg_finished(pegs: PackedStringArray, peg_index: int) -> bool:
	var text: String = pegs[peg_index]
	if text.is_empty() or text.count(text[0]) != text.length():
		return false
	return "".join(pegs).count(text[0]) == text.length()


## The puzzle up to the names of its colours: two levels with the same key
## differ only in which colour is which (e.g. green and blue swapped), so to a
## player they are the same puzzle. Colours are renamed in the order they first
## appear in `pegs` (the start).
func shape_key(pegs: PackedStringArray) -> String:
	var rename: Dictionary = {}
	var start: String = ""
	for text: String in pegs:
		for letter: String in text:
			if not rename.has(letter):
				rename[letter] = String.chr(97 + rename.size())
			start += rename[letter]
		start += "|"
	var goal: String = kind
	for text: String in (target_letters() if kind == PATTERN else PackedStringArray()):
		goal += ":"
		for letter: String in text:
			goal += rename.get(letter, "?")
	return start + " => " + goal


## Problems with this goal for a level of `peg_count` pegs of `capacity`
## disks with these disk colours; appended to `errors`. Correction v2 (error
## 1): the goal's colours are exactly the board's colours, and a pattern names
## every disk.
func check(peg_count: int, capacity: int, disk_colors: Array[String], errors: Array[String]) -> void:
	for color_name: String in disk_colors:
		if not LETTERS.has(color_name):
			errors.append("disk colour \"%s\" is not one of %s" % [color_name, str(LETTERS.keys())])
			return
	var board: Array[String] = disk_colors.duplicate()
	board.sort()
	var distinct: Array[String] = []
	for color_name: String in board:
		if not distinct.has(color_name):
			distinct.append(color_name)
	if goal_colours(disk_colors) != distinct:
		errors.append("the goal names %s but the board has %s" % [str(goal_colours(disk_colors)), str(distinct)])
		return
	if kind == SORT:
		if distinct.size() > peg_count:
			errors.append("a sort goal needs a peg for each of its %d colours" % distinct.size())
		for color_name: String in distinct:
			if disk_colors.count(color_name) > capacity:
				errors.append("%d %s disks do not fit on one peg of %d" % [disk_colors.count(color_name), color_name, capacity])
		return
	if targets.size() != peg_count:
		errors.append("a pattern needs a target for each of the %d pegs" % peg_count)
		return
	var named: Array[String] = []
	for target: Array in targets:
		if target.size() > capacity:
			errors.append("a pattern peg holds at most %d disks" % capacity)
		for color_name: String in target:
			named.append(color_name)
	named.sort()
	if named != board:
		errors.append("the pattern must place every disk exactly once")


static func _fail(reason: String, errors: Array[String]) -> ColorGoal:
	errors.append(reason)
	return null
