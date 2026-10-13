class_name ColorGoal
extends RefCounted
## The goal of a "Birləşmə Tapmacası" (combination puzzle, level structure v4,
## section 4) level, read by colour: its disks are all of one size and only
## their colour counts, so two disks of one colour are interchangeable.
## - SORT ("Sadə Yığım"): every colour gathered on a peg of its own (any peg);
##   each peg that holds disks holds one colour, and all of it.
## - PATTERN ("Konkret Kombinasiya"): peg `peg` shows exactly `colors`, bottom
##   -> top; the other disks may be anywhere.
## Positions are compared as one string of colour letters per peg (LETTERS), the
## same form CombinationSolver searches in.

const SORT: String = "sort"
const PATTERN: String = "pattern"
const KINDS: Array[String] = [SORT, PATTERN]
## Disk colours of the combination puzzle and their one-letter codes.
const LETTERS: Dictionary = {"red": "r", "blue": "b", "yellow": "y", "green": "g"}

var kind: String = SORT
## PATTERN: the peg that must show the pattern.
var peg: int = -1
## PATTERN: colours bottom -> top.
var colors: Array[String] = []


static func sort() -> ColorGoal:
	return ColorGoal.new()


static func pattern(p_peg: int, p_colors: Array[String]) -> ColorGoal:
	var goal: ColorGoal = ColorGoal.new()
	goal.kind = PATTERN
	goal.peg = p_peg
	goal.colors = p_colors.duplicate()
	return goal


## Reads `{"kind": "sort"}` or `{"kind": "pattern", "peg": 2, "colors": [...]}`;
## null and a reason in `errors` if it does not fit.
static func from_dict(data: Variant, errors: Array[String]) -> ColorGoal:
	if typeof(data) != TYPE_DICTIONARY or not KINDS.has(data.get("kind")):
		errors.append("\"color_goal\" must be {\"kind\": \"sort\"} or {\"kind\": \"pattern\", \"peg\": int, \"colors\": [...]}")
		return null
	if data["kind"] == SORT:
		return sort() if data.size() == 1 else _fail("a sort goal takes no other keys", errors)
	var peg_value: Variant = data.get("peg")
	var color_list: Variant = data.get("colors")
	if typeof(peg_value) not in [TYPE_INT, TYPE_FLOAT] or peg_value != floorf(peg_value) or typeof(color_list) != TYPE_ARRAY \
			or not color_list.all(func(c: Variant) -> bool: return typeof(c) == TYPE_STRING) or data.size() != 3:
		return _fail("a pattern goal needs an integer \"peg\" and a \"colors\" list", errors)
	var p_colors: Array[String] = []
	p_colors.assign(color_list)
	return pattern(int(peg_value), p_colors)


func to_dict() -> Dictionary:
	if kind == SORT:
		return {"kind": SORT}
	return {"kind": PATTERN, "peg": peg, "colors": colors.duplicate()}


## Each peg of `state` as a string of colour letters, bottom -> top.
static func letters_of(state: PuzzleState, disk_colors: Array[String]) -> PackedStringArray:
	var pegs: PackedStringArray = PackedStringArray()
	for stack: Array in state.pegs:
		var text: String = ""
		for disk: int in stack:
			text += LETTERS[disk_colors[disk - 1]]
		pegs.append(text)
	return pegs


func is_met(state: PuzzleState, disk_colors: Array[String]) -> bool:
	return matches(letters_of(state, disk_colors))


## Whether pegs given as colour letters (letters_of) meet the goal.
func matches(pegs: PackedStringArray) -> bool:
	if kind == PATTERN:
		return pegs[peg] == pattern_letters()
	var seen: String = ""
	for text: String in pegs:
		if text.is_empty():
			continue
		var letter: String = text[0]
		if seen.contains(letter) or text.count(letter) != text.length():
			return false
		seen += letter
	return true


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
	var target: String = kind
	if kind == PATTERN:
		target += ":%d:" % peg
		for letter: String in pattern_letters():
			target += rename.get(letter, "?")
	return start + " => " + target


func pattern_letters() -> String:
	var text: String = ""
	for color_name: String in colors:
		text += LETTERS[color_name]
	return text


## Progress shown to the player. PATTERN: how many disks at the bottom of the
## pattern peg already match. SORT: how many pegs are finished (one colour,
## all of it).
func progress(state: PuzzleState, disk_colors: Array[String]) -> int:
	var pegs: PackedStringArray = letters_of(state, disk_colors)
	if kind == PATTERN:
		var target: String = pattern_letters()
		var count: int = 0
		while count < pegs[peg].length() and count < target.length() and pegs[peg][count] == target[count]:
			count += 1
		return count
	var finished: int = 0
	for peg_index: int in pegs.size():
		if is_peg_finished(pegs, peg_index):
			finished += 1
	return finished


## SORT: peg `peg_index` holds every disk of one colour and nothing else.
static func is_peg_finished(pegs: PackedStringArray, peg_index: int) -> bool:
	var text: String = pegs[peg_index]
	if text.is_empty() or text.count(text[0]) != text.length():
		return false
	return "".join(pegs).count(text[0]) == text.length()


## What progress() counts to when the goal is met.
func progress_total(disk_colors: Array[String]) -> int:
	if kind == PATTERN:
		return colors.size()
	var distinct: Array[String] = []
	for color_name: String in disk_colors:
		if not distinct.has(color_name):
			distinct.append(color_name)
	return distinct.size()


## Problems with this goal for a level of `peg_count` pegs holding pegs of
## `capacity` disks with these disk colours; appended to `errors`.
func check(peg_count: int, capacity: int, disk_colors: Array[String], errors: Array[String]) -> void:
	for color_name: String in disk_colors:
		if not LETTERS.has(color_name):
			errors.append("disk colour \"%s\" is not one of %s" % [color_name, str(LETTERS.keys())])
			return
	var counts: Dictionary = {}
	for color_name: String in disk_colors:
		counts[color_name] = counts.get(color_name, 0) + 1
	if kind == SORT:
		if counts.size() > peg_count:
			errors.append("a sort goal needs a peg for each of its %d colours" % counts.size())
		for color_name: String in counts:
			if counts[color_name] > capacity:
				errors.append("%d %s disks do not fit on one peg of %d" % [counts[color_name], color_name, capacity])
		return
	if peg < 0 or peg >= peg_count:
		errors.append("pattern peg %d is not a peg" % peg)
	if colors.size() < 2 or colors.size() > capacity:
		errors.append("a pattern needs 2 to %d colours (the peg's capacity)" % capacity)
	for color_name: String in colors:
		if not counts.has(color_name):
			errors.append("the pattern uses %s, which no disk has" % color_name)
			return
		counts[color_name] -= 1
		if counts[color_name] < 0:
			errors.append("the pattern needs more %s disks than the level has" % color_name)
			return


static func _fail(reason: String, errors: Array[String]) -> ColorGoal:
	errors.append(reason)
	return null
