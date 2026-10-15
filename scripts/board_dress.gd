class_name BoardDress
extends RefCounted
## How a level's mechanic looks on the board and in the goal preview: the peg
## layout, the disks' colours and numbers, how much a peg can hold, the words
## that explain the goal or the progress, and the marks drawn on the dress and
## over the disks. Presentation only: rules never read it, and the board and
## preview never name a mechanic themselves. Each part looks at the rules the
## level has, so a combination (chapter plan section 4) wears both dresses:
## unequal rods with padlocks, say.


## BoardLayout kind of `level`'s pegs.
static func layout_kind(level: Level) -> String:
	if _has(level, Difficulty.COLOR_SWAP):
		return BoardLayout.ROW  # one row even with 6 pegs: its two ends are the point
	if _has(level, CyclicRule.ID):
		return BoardLayout.CIRCLE
	if _has(level, BalanceRule.ID):
		return BoardLayout.PAIRS
	if _has(level, MirrorRule.ID):
		return BoardLayout.ROWS  # one board above the other
	return BoardLayout.ROWS if level.get_peg_count() > BoardLayout.ONE_ROW_PEGS else BoardLayout.ROW


## Disk id -> its looks where the id alone does not give them: {fill, text,
## outline} and optionally `label` (the number it shows), `size` and `sizes`
## (its width among that many sizes). Empty for levels whose disks keep one
## colour each and show their id.
## - Great exchange (ColorSwapRule): ids 2s - 1 and 2s are the white and black
##   disk of size s.
## - Striped tower: odd and even sizes in the two stripe colours.
## - Twin boards: each board numbers and colours its disks from 1 on its own.
static func disk_palette(level: Level) -> Dictionary:
	var palette: Dictionary = {}
	if _has(level, Difficulty.COLOR_SWAP):
		var sizes: int = level.get_disk_count() / 2
		for disk: int in range(1, level.get_disk_count() + 1):
			var colors: Dictionary = ThemeManager.EXCHANGE_DISKS["white" if ColorSwapRule.is_white(disk) else "black"].duplicate()
			colors["label"] = ColorSwapRule.size_of(disk)
			colors["size"] = ColorSwapRule.size_of(disk)
			colors["sizes"] = sizes
			palette[disk] = colors
	elif _has(level, StripesRule.ID):
		for disk: int in range(1, level.get_disk_count() + 1):
			palette[disk] = ThemeManager.STRIPE_DISKS["odd" if disk % 2 == 1 else "even"].duplicate()
	elif _has(level, MirrorRule.ID):
		var first: int = first_board_disks(level)
		var second: int = level.get_disk_count() - first
		for disk: int in range(1, level.get_disk_count() + 1):
			var size: int = disk if disk <= first else disk - first
			var sizes: int = first if disk <= first else second
			palette[disk] = {"fill": ThemeManager.disk_color(size, sizes), "text": ThemeManager.color("text_on_disk"),
					"label": size, "size": size, "sizes": sizes}
	return palette


## The disks of the first (upper) board of a twin level: its lowest ids.
static func first_board_disks(level: Level) -> int:
	var count: int = 0
	for peg_index: int in level.get_peg_count() / 2:
		count += level.start.pegs[peg_index].size()
	return count


## The most disks one peg can ever hold (the rods are drawn for it).
static func stack_room(level: Level) -> int:
	if _has(level, Difficulty.COLOR_SWAP):
		return maxi(level.get_disk_count() / 2, 1)  # one disk of each size
	if _has(level, PegCapacityRule.ID):
		return maxi((_rule(level, PegCapacityRule.ID) as PegCapacityRule).capacities.max(), 1)
	if _has(level, MirrorRule.ID):
		var first: int = first_board_disks(level)
		return maxi(maxi(first, level.get_disk_count() - first), 1)
	return maxi(level.get_disk_count(), 1)


## Per peg, how many disks its rod is drawn for; empty when every rod is
## stack_room() tall. Unequal capacity: each rod as tall as its capacity.
static func rod_rooms(level: Level) -> Array[int]:
	if _has(level, PegCapacityRule.ID):
		return (_rule(level, PegCapacityRule.ID) as PegCapacityRule).capacities.duplicate()
	return [] as Array[int]


## Whether a refused move says why in the status line (not just a flash): the
## great exchange (its v2: never a silent refusal) and every mechanic of the
## new mechanics specification v1 ("blocked, with a message").
static func says_why(level: Level) -> bool:
	for id: String in [Difficulty.COLOR_SWAP, PegCapacityRule.ID, FoundationRule.ID, BalanceRule.ID, CyclicRule.ID,
			StripesRule.ID, ChainRule.ID, MirrorRule.ID, TrailRule.ID, MagnetRule.ID, SealedBoxRule.ID]:
		if _has(level, id):
			return true
	return false


## A note in the status line before the first move (translated), or "": the
## foundation's keys in place. The mode's name and rule stand in the rule
## panel below (ModeTexts).
static func goal_text(level: Level) -> String:
	if _has(level, FoundationRule.ID):
		var rule: FoundationRule = _rule(level, FoundationRule.ID) as FoundationRule
		return Languages.text(_keys_text(level)) % [rule.keys_in_place(level.start), rule.keys_needed()]
	return ""


## A note after a move (translated), or "": the foundation's keys in place
## while it is locked, the moment one of a chain's locks opens and the moment
## the last one does, and the moment a sealed box's seal breaks.
static func progress_text(session: GameSession) -> String:
	var before: PuzzleState = session.previous_state()
	if _has(session.level, SealedBoxRule.ID):
		if before != null and session.rules.memory_of(session.state) != session.rules.memory_of(before):
			return Languages.text("SEALED_OPEN")
		return ""
	if not _has(session.level, FoundationRule.ID):
		return ""
	var rule: FoundationRule = _rule(session.level, FoundationRule.ID) as FoundationRule
	var open: int = session.rules.memory_of(session.state)
	var was_open: int = session.rules.memory_of(before) if before != null else open
	if open > was_open:
		return Languages.text("FOUNDATION_OPEN" if open == rule.stages.size() else "LOCK_NEXT")
	if open < rule.stages.size():
		return Languages.text(_keys_text(session.level)) % [rule.keys_in_place(session.state, open), rule.keys_needed(open)]
	return ""


## "Təməl: 1/2 kiçik disk" for the base lock, "Açar: 0/1" for a key disk or a
## chain of locks.
static func _keys_text(level: Level) -> String:
	return "LOCK_KEYS" if level.variants.has("key_disk") or level.variants.has("chain_lock") else "FOUNDATION_PROGRESS"


## The translation key the board shows for a refusal `key`: a lock opened by
## a key disk says so rather than "the small disks first".
static func refusal_key(level: Level, key: String) -> String:
	if key == "RULE_FOUNDATION" and (level.variants.has("key_disk") or level.variants.has("chain_lock")):
		return "RULE_LOCK_KEY"
	return key


## What the dress draws under the pegs for this position (BoardSkin.marks):
## - scales: "beams", one [left sum - right sum, at the limit] per pair, and
##   "tolerance";
## - sandy path: "visited", the pegs on the trail disk's trail (it may not go
##   back there).
static func skin_marks(session: GameSession) -> Dictionary:
	var level: Level = session.level
	var marks: Dictionary = {}
	if _has(level, BalanceRule.ID):
		var tolerance: int = (_rule(level, BalanceRule.ID) as BalanceRule).tolerance
		var beams: Array = []
		for peg: int in range(0, session.state.get_peg_count(), 2):
			var difference: int = BalanceRule.sum_of(session.state.pegs[peg]) - BalanceRule.sum_of(session.state.pegs[peg + 1])
			beams.append([difference, absi(difference) >= tolerance])
		marks["beams"] = beams
		marks["tolerance"] = tolerance
	if _has(level, TrailRule.ID):
		var rule: TrailRule = _rule(level, TrailRule.ID) as TrailRule
		var memory: int = session.rules.memory_of(session.state)
		var visited: Array[int] = []
		for peg_index: int in session.state.get_peg_count():
			if rule.remembers(memory, peg_index, session.state.get_peg_count()):
				visited.append(peg_index)
		marks["visited"] = visited
	return marks


## What is drawn over the disks and pegs (BoardMarks): "chain" [disk, disk,
## can move now], "locked" [disks still locked], "trail_disk" (the disk that
## leaves the trail), and the chapter waves' marks: "keys" [[key disk, its key
## place peg]] of the locks still closed (a key disk or a chain of locks),
## "links" [[key disk, locked disk]] between a chain's locks, "arches" and
## "holes" {peg: size}.
static func overlay_marks(session: GameSession) -> Dictionary:
	var level: Level = session.level
	var marks: Dictionary = {}
	if _has(level, ChainRule.ID):
		var pair: Array[int] = (_rule(level, ChainRule.ID) as ChainRule).disks
		var free: bool = false
		for peg_index: int in session.state.get_peg_count():
			if session.state.get_top_disk(peg_index) == pair[0]:
				free = session.rules.can_pick_up(session.state, peg_index)
		marks["chain"] = [pair[0], pair[1], free]
	if _has(level, FoundationRule.ID):
		var lock: FoundationRule = _rule(level, FoundationRule.ID) as FoundationRule
		var open: int = session.rules.memory_of(session.state)
		if open < lock.stages.size():
			marks["locked"] = lock.locked_now(open)
		if level.variants.has("key_disk") or level.variants.has("chain_lock"):
			var keys: Array = []
			var links: Array = []
			for stage: int in range(open, lock.stages.size()):
				for i: int in (lock.stages[stage]["keys"] as Array).size():
					var key: int = lock.stages[stage]["keys"][i]
					keys.append([key, lock.stages[stage]["targets"][i]])
					if stage > 0 or level.variants.has("chain_lock"):
						for locked: int in lock.stages[stage]["locked"]:
							links.append([key, locked])
			marks["keys"] = keys
			marks["links"] = links
	if _has(level, PegCapacityRule.ID):
		var capacity: PegCapacityRule = _rule(level, PegCapacityRule.ID) as PegCapacityRule
		for list: String in ["arches", "holes"]:
			var sizes: Array[int] = capacity.arches if list == "arches" else capacity.holes
			var found: Dictionary = {}
			for peg_index: int in sizes.size():
				if sizes[peg_index] > 0:
					found[peg_index] = sizes[peg_index]
			if not found.is_empty():
				marks[list] = found
	if _has(level, TrailRule.ID):
		marks["trail_disk"] = (_rule(level, TrailRule.ID) as TrailRule).disk
	return marks


## Whether `level` plays under the rule `id`.
static func _has(level: Level, id: String) -> bool:
	return level.rule_ids.has(id)


## The active rule of `level` with id `id` (the level's rules are valid).
static func _rule(level: Level, id: String) -> RuleBase:
	for rule: RuleBase in level.get_rule_set().active_rules:
		if rule.get_id() == id:
			return rule
	return null
