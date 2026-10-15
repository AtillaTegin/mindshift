class_name BoardDress
extends RefCounted
## How a level's mechanic looks on the board and in the goal preview: the peg
## layout, the disks' colours and numbers, how much a peg can hold, the words
## that explain the goal or the progress, and the marks drawn on the dress and
## over the disks. Presentation only: rules never read it, and the board and
## preview never name a mechanic themselves.


## BoardLayout kind of `level`'s pegs.
static func layout_kind(level: Level) -> String:
	match level.mechanic():
		Difficulty.COLOR_SWAP:
			return BoardLayout.ROW  # one row even with 6 pegs: its two ends are the point
		CyclicRule.ID:
			return BoardLayout.CIRCLE
		BalanceRule.ID:
			return BoardLayout.PAIRS
		MirrorRule.ID:
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
	match level.mechanic():
		Difficulty.COLOR_SWAP:
			var sizes: int = level.get_disk_count() / 2
			for disk: int in range(1, level.get_disk_count() + 1):
				var colors: Dictionary = ThemeManager.EXCHANGE_DISKS["white" if ColorSwapRule.is_white(disk) else "black"].duplicate()
				colors["label"] = ColorSwapRule.size_of(disk)
				colors["size"] = ColorSwapRule.size_of(disk)
				colors["sizes"] = sizes
				palette[disk] = colors
		StripesRule.ID:
			for disk: int in range(1, level.get_disk_count() + 1):
				palette[disk] = ThemeManager.STRIPE_DISKS["odd" if disk % 2 == 1 else "even"].duplicate()
		MirrorRule.ID:
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
	match level.mechanic():
		Difficulty.COLOR_SWAP:
			return maxi(level.get_disk_count() / 2, 1)  # one disk of each size
		PegCapacityRule.ID:
			return maxi((_rule(level, PegCapacityRule.ID) as PegCapacityRule).capacities.max(), 1)
		MirrorRule.ID:
			var first: int = first_board_disks(level)
			return maxi(maxi(first, level.get_disk_count() - first), 1)
	return maxi(level.get_disk_count(), 1)


## Per peg, how many disks its rod is drawn for; empty when every rod is
## stack_room() tall. Unequal capacity: each rod as tall as its capacity.
static func rod_rooms(level: Level) -> Array[int]:
	if level.mechanic() == PegCapacityRule.ID:
		return (_rule(level, PegCapacityRule.ID) as PegCapacityRule).capacities.duplicate()
	return [] as Array[int]


## Whether a refused move says why in the status line (not just a flash): the
## great exchange (its v2: never a silent refusal) and every mechanic of the
## new mechanics specification v1 ("blocked, with a message").
static func says_why(level: Level) -> bool:
	return level.mechanic() in [Difficulty.COLOR_SWAP, PegCapacityRule.ID, FoundationRule.ID, BalanceRule.ID,
			CyclicRule.ID, StripesRule.ID, ChainRule.ID, MirrorRule.ID, TrailRule.ID, MagnetRule.ID]


## A note in the status line before the first move (translated), or "": the
## foundation's keys in place. The mode's name and rule stand in the rule
## panel below (ModeTexts).
static func goal_text(level: Level) -> String:
	if level.mechanic() == FoundationRule.ID:
		var rule: FoundationRule = _rule(level, FoundationRule.ID) as FoundationRule
		return Languages.text("FOUNDATION_PROGRESS") % [rule.keys_in_place(level.start), rule.keys.size()]
	return ""


## A note after a move (translated), or "": the foundation's keys in place
## while it is locked, and the moment it opens.
static func progress_text(session: GameSession) -> String:
	if session.level.mechanic() != FoundationRule.ID:
		return ""
	var rule: FoundationRule = _rule(session.level, FoundationRule.ID) as FoundationRule
	if session.rules.memory_of(session.state) == 0:
		return Languages.text("FOUNDATION_PROGRESS") % [rule.keys_in_place(session.state), rule.keys.size()]
	var before: PuzzleState = session.previous_state()
	if before != null and session.rules.memory_of(before) == 0:
		return Languages.text("FOUNDATION_OPEN")
	return ""


## What the dress draws under the pegs for this position (BoardSkin.marks):
## - scales: "beams", one [left sum - right sum, at the limit] per pair, and
##   "tolerance";
## - sandy path: "visited", the pegs on the trail disk's trail (it may not go
##   back there).
static func skin_marks(session: GameSession) -> Dictionary:
	var level: Level = session.level
	match level.mechanic():
		BalanceRule.ID:
			var tolerance: int = (_rule(level, BalanceRule.ID) as BalanceRule).tolerance
			var beams: Array = []
			for peg: int in range(0, session.state.get_peg_count(), 2):
				var difference: int = BalanceRule.sum_of(session.state.pegs[peg]) - BalanceRule.sum_of(session.state.pegs[peg + 1])
				beams.append([difference, absi(difference) >= tolerance])
			return {"beams": beams, "tolerance": tolerance}
		TrailRule.ID:
			var rule: TrailRule = _rule(level, TrailRule.ID) as TrailRule
			var memory: int = session.rules.memory_of(session.state)
			var visited: Array[int] = []
			for peg_index: int in session.state.get_peg_count():
				if rule.remembers(memory, peg_index, session.state.get_peg_count()):
					visited.append(peg_index)
			return {"visited": visited}
	return {}


## What is drawn over the disks (BoardMarks): "chain" [disk, disk, can move
## now], "locked" [disks still locked], "trail_disk" (the disk that leaves the
## trail).
static func overlay_marks(session: GameSession) -> Dictionary:
	var level: Level = session.level
	match level.mechanic():
		ChainRule.ID:
			var pair: Array[int] = (_rule(level, ChainRule.ID) as ChainRule).disks
			var free: bool = false
			for peg_index: int in session.state.get_peg_count():
				if session.state.get_top_disk(peg_index) == pair[0]:
					free = session.rules.can_pick_up(session.state, peg_index)
			return {"chain": [pair[0], pair[1], free]}
		FoundationRule.ID:
			if session.rules.memory_of(session.state) == 0:
				return {"locked": (_rule(level, FoundationRule.ID) as FoundationRule).locked.duplicate()}
		TrailRule.ID:
			return {"trail_disk": (_rule(level, TrailRule.ID) as TrailRule).disk}
	return {}


## The active rule of `level` with id `id` (the level's rules are valid).
static func _rule(level: Level, id: String) -> RuleBase:
	for rule: RuleBase in level.get_rule_set().active_rules:
		if rule.get_id() == id:
			return rule
	return null
