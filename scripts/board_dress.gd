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
	if _has(level, RiverRule.ID):
		return BoardLayout.ROW  # the river runs between the two banks of one row
	if _has(level, HeavyRule.ID):
		return BoardLayout.ROW  # the distances are along one line
	if _has(level, LampRule.ID):
		return BoardLayout.CIRCLE if (_rule(level, LampRule.ID) as LampRule).circle else BoardLayout.ROW
	if _has(level, CyclicRule.ID):
		var dial: CyclicRule = _rule(level, CyclicRule.ID) as CyclicRule
		if not dial.eight.is_empty():
			return BoardLayout.EIGHT
		return BoardLayout.CIRCLE_CENTER if dial.center >= 0 else BoardLayout.CIRCLE
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
		# Two caravans, or three ("Üç karvan": white, black, red).
		var count: int = (_rule(level, ColorSwapRule.ID) as ColorSwapRule).colours
		var sizes: int = level.get_disk_count() / count
		for disk: int in range(1, level.get_disk_count() + 1):
			var hue: String = ["white", "black", "red"][ColorSwapRule.colour_of(disk, count)]
			var colors: Dictionary = ThemeManager.EXCHANGE_DISKS[hue].duplicate()
			colors["label"] = ColorSwapRule.size_of(disk, count)
			colors["size"] = ColorSwapRule.size_of(disk, count)
			colors["sizes"] = sizes
			palette[disk] = colors
	elif _has(level, StripesRule.ID):
		palette = stripe_palette(_rule(level, StripesRule.ID) as StripesRule, level.get_disk_count(), 0)
	elif _has(level, ElementsRule.ID):
		palette = element_palette(_rule(level, ElementsRule.ID) as ElementsRule, level.get_disk_count(), 0)
	elif _has(level, TurnsRule.ID):
		# Növbə: white, black, red and the grey disk.
		var turns: TurnsRule = _rule(level, TurnsRule.ID) as TurnsRule
		for disk: int in range(1, level.get_disk_count() + 1):
			var hue: String = {TurnsRule.WHITE: "white", TurnsRule.BLACK: "black", TurnsRule.RED: "red",
				TurnsRule.GREY: "grey"}[turns.colour_of(disk)]
			palette[disk] = ThemeManager.EXCHANGE_DISKS[hue].duplicate()
	elif _has(level, SolitaireRule.ID) and not (_rule(level, SolitaireRule.ID) as SolitaireRule).colours.is_empty():
		# "Qırmızı-qara": card colours.
		var solitaire: SolitaireRule = _rule(level, SolitaireRule.ID) as SolitaireRule
		for disk: int in range(1, level.get_disk_count() + 1):
			palette[disk] = ThemeManager.EXCHANGE_DISKS["red" if solitaire.colour_of(disk) == 1 else "black"].duplicate()
	elif _has(level, CarpetRule.ID) and not (_rule(level, CarpetRule.ID) as CarpetRule).colours.is_empty():
		# "Rəngli naxış": each disk in its carpet colour.
		var carpet: CarpetRule = _rule(level, CarpetRule.ID) as CarpetRule
		for disk: int in range(1, level.get_disk_count() + 1):
			palette[disk] = ThemeManager.CARPET_DISKS[carpet.colour_of(disk)].duplicate()
	elif _has(level, MirrorRule.ID):
		# Each board numbers its disks from 1; the bottom one, the echo, is paler
		# and bluish (Güzgü "Əks-səda").
		var first: int = first_board_disks(level)
		var second: int = level.get_disk_count() - first
		for disk: int in range(1, level.get_disk_count() + 1):
			var size: int = disk if disk <= first else disk - first
			var sizes: int = first if disk <= first else second
			var fill: Color = ThemeManager.disk_color(size, sizes)
			if disk > first:
				fill = fill.lerp(ThemeManager.mark_color("mirror_tint"), 0.45)
			palette[disk] = {"fill": fill, "text": ThemeManager.color("text_on_disk"), "label": size, "size": size,
					"sizes": sizes}
	return palette


## The striped tower's colours with `memory` (the paint peg's painted disks
## turned, the neutral disk grey).
static func stripe_palette(rule: StripesRule, disk_count: int, memory: int) -> Dictionary:
	var palette: Dictionary = {}
	for disk: int in range(1, disk_count + 1):
		var colour: int = rule.colour_of(disk, memory)
		var role: String = "neutral" if colour == StripesRule.NONE else "odd" if colour == StripesRule.ODD else "even"
		palette[disk] = ThemeManager.STRIPE_DISKS[role].duplicate()
	return palette


## The five elements' colours with `memory` (each disk's turns so far).
static func element_palette(rule: ElementsRule, disk_count: int, memory: int) -> Dictionary:
	var palette: Dictionary = {}
	for disk: int in range(1, disk_count + 1):
		palette[disk] = ThemeManager.ELEMENT_DISKS[rule.element_of(disk, memory)].duplicate()
	return palette


## The disk colours of the position now, where a move can change them (the
## paint peg, the element that turns); empty for every other level.
static func disk_palette_now(session: GameSession) -> Dictionary:
	if _has(session.level, ElementsRule.ID):
		var wuxing: ElementsRule = _rule(session.level, ElementsRule.ID) as ElementsRule
		if not wuxing.uses_memory():
			return {}
		return element_palette(wuxing, session.level.get_disk_count(), session.rules.memory_of(session.state))
	if not _has(session.level, StripesRule.ID):
		return {}
	var rule: StripesRule = _rule(session.level, StripesRule.ID) as StripesRule
	if rule.paint < 0:
		return {}
	return stripe_palette(rule, session.level.get_disk_count(), session.rules.memory_of(session.state))


## The disks of the first (upper) board of a twin level: its lowest ids.
static func first_board_disks(level: Level) -> int:
	var count: int = 0
	for peg_index: int in level.get_peg_count() / 2:
		count += level.start.pegs[peg_index].size()
	return count


## The most disks one peg can ever hold (the rods are drawn for it).
static func stack_room(level: Level) -> int:
	if _has(level, Difficulty.COLOR_SWAP):
		# One disk of each size.
		return maxi(level.get_disk_count() / (_rule(level, ColorSwapRule.ID) as ColorSwapRule).colours, 1)
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
	# An oasis and a dial's centre hold one disk: a short rod.
	var short: int = -1
	if _has(level, AdjacentPegsRule.ID):
		short = (_rule(level, AdjacentPegsRule.ID) as AdjacentPegsRule).oasis
	if _has(level, CyclicRule.ID):
		short = (_rule(level, CyclicRule.ID) as CyclicRule).center
	if _has(level, RiverRule.ID):
		short = (_rule(level, RiverRule.ID) as RiverRule).ferry()
	if _has(level, HeavyRule.ID):
		short = (_rule(level, HeavyRule.ID) as HeavyRule).cart
	if _has(level, SolitaireRule.ID):
		short = (_rule(level, SolitaireRule.ID) as SolitaireRule).cell
	if short < 0:
		return [] as Array[int]
	var rooms: Array[int] = []
	rooms.resize(level.get_peg_count())
	rooms.fill(stack_room(level))
	rooms[short] = 1
	return rooms


## Whether a refused move says why in the status line (not just a flash): the
## great exchange (its v2: never a silent refusal) and every mechanic of the
## new mechanics specification v1 ("blocked, with a message").
static func says_why(level: Level) -> bool:
	for id: String in [Difficulty.COLOR_SWAP, PegCapacityRule.ID, FoundationRule.ID, BalanceRule.ID, CyclicRule.ID,
			StripesRule.ID, ChainRule.ID, MirrorRule.ID, TrailRule.ID, MagnetRule.ID, SealedBoxRule.ID, AdjacentPegsRule.ID,
			KingRule.ID, RiverRule.ID, KoRule.ID, HeavyRule.ID, ElementsRule.ID, TurnsRule.ID, KintsugiRule.ID, LampRule.ID,
			SolitaireRule.ID]:
		if _has(level, id):
			return true
	return false


## What the goal preview shows: the goal position, or for a goal condition
## (ICRA section 2) only what it asks: the crowned disks on their gates, a
## carpet's empty pegs (its silhouette is drawn over them, goal_silhouette()).
static func goal_view(level: Level) -> PuzzleState:
	if _has(level, CarpetRule.ID) or _has(level, SumRule.ID):
		var empty: Array = []
		for i: int in level.get_peg_count():
			empty.append([])
		return PuzzleState.new(empty)
	if _has(level, KingRule.ID):
		var king: KingRule = _rule(level, KingRule.ID) as KingRule
		if king.defines_goal():
			var layout: Array = []
			for i: int in level.get_peg_count():
				layout.append([])
			var crowns: Array = king.crowns.duplicate()
			crowns.sort_custom(func(a: Array, b: Array) -> bool: return int(a[0]) > int(b[0]))
			for crown: Array in crowns:
				layout[crown[1]].append(crown[0])
			return PuzzleState.new(layout)
	return level.goal


## What the goal preview draws for a carpet (ICRA 3.4): {heights, tops (the
## colour each marked top must have, -1 none), navel [peg, disk]}; {} for any
## other level.
static func goal_silhouette(level: Level) -> Dictionary:
	if _has(level, SumRule.ID):
		# Cəm: the numbers under the pegs (or "=" for equal sums).
		var sum: SumRule = _rule(level, SumRule.ID) as SumRule
		return {"sums": sum.sums, "fair": sum.fair, "counts": sum.counts, "parity": sum.parity, "double": sum.double}
	if not _has(level, CarpetRule.ID):
		return {}
	var carpet: CarpetRule = _rule(level, CarpetRule.ID) as CarpetRule
	return {"heights": carpet.heights, "tops": carpet.tops, "navel": carpet.navel}


## The pegs the goal preview marks with a gate's flag (the king's gates).
static func goal_gates(level: Level) -> Array[int]:
	var gates: Array[int] = []
	if _has(level, KingRule.ID):
		for crown: Array in (_rule(level, KingRule.ID) as KingRule).crowns:
			gates.append(crown[1])
	return gates


## A note in the status line before the first move (translated), or "": the
## foundation's keys in place. The mode's name and rule stand in the rule
## panel below (ModeTexts).
static func goal_text(level: Level) -> String:
	if _has(level, MirrorRule.ID):
		return Languages.text("MIRROR_GOAL")
	if _has(level, KingRule.ID) and (_rule(level, KingRule.ID) as KingRule).defines_goal():
		return Languages.text("KING_GOAL")
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
## the sandy path's "visited", the pegs on the trail disk's trail (it may not
## go back there). The balance scales draw themselves (BalanceScale).
static func skin_marks(session: GameSession) -> Dictionary:
	var level: Level = session.level
	var marks: Dictionary = {}
	if _has(level, TrailRule.ID):
		var rule: TrailRule = _rule(level, TrailRule.ID) as TrailRule
		var memory: int = session.rules.memory_of(session.state)
		var visited: Array[int] = []
		for peg_index: int in session.state.get_peg_count():
			for index: int in rule.disks.size():
				if rule.remembers_of(memory, index, peg_index, session.state.get_peg_count()) and not visited.has(peg_index):
					visited.append(peg_index)
		marks["visited"] = visited
	# World 3-4: the caravan road's oasis, tunnels, bridges and arrows; the
	# dial's centre or figure eight.
	if _has(level, AdjacentPegsRule.ID):
		var road: AdjacentPegsRule = _rule(level, AdjacentPegsRule.ID) as AdjacentPegsRule
		marks["road"] = {"oasis": [road.oasis, road.oasis_stop], "tunnels": road.tunnels, "bridges": road.bridges,
				"one_way": road.one_way}
	if _has(level, CyclicRule.ID):
		var dial: CyclicRule = _rule(level, CyclicRule.ID) as CyclicRule
		marks["dial"] = {"center": dial.center, "eight": dial.eight}
	# World 5: the river between its banks, its bridges, fords and ferry, or the
	# bonfire in its place.
	if _has(level, RiverRule.ID):
		var river: RiverRule = _rule(level, RiverRule.ID) as RiverRule
		marks["river"] = {"banks": river.banks, "bridges": river.bridges, "crossings": river.crossings, "fire": river.fire,
				"reverse": river.reverse}
	# World 6: the carpet's silhouette and how far each peg has come.
	if _has(level, CarpetRule.ID):
		var counts: Array = []
		for peg: Array in session.state.pegs:
			counts.append(peg.size())
		marks["carpet"] = {"heights": (_rule(level, CarpetRule.ID) as CarpetRule).heights, "counts": counts}
	# World 7: the heavy disks' track, its slope and cart.
	if _has(level, HeavyRule.ID):
		var heavy: HeavyRule = _rule(level, HeavyRule.ID) as HeavyRule
		marks["quarry"] = {"uphill": heavy.uphill, "cart": heavy.cart}
	# World 8: each peg's sum now and the one it must reach (doubled where so).
	if _has(level, SumRule.ID):
		var sum: SumRule = _rule(level, SumRule.ID) as SumRule
		var facts: MoveFacts = MoveFacts.of(session.state, session.rules)
		var now: Array = []
		var counts: Array = []
		for peg: int in level.get_peg_count():
			now.append(sum.shown_sum(facts, peg))
			counts.append(facts.counts[peg])
		marks["sums"] = {"targets": sum.sums, "fair": sum.fair, "now": now, "counts": sum.counts, "count_now": counts,
				"parity": sum.parity, "double": sum.double}
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
		# Every chain that holds (a broken one is gone), bright when it can move.
		var chains: Array = []
		var chain: ChainRule = _rule(level, ChainRule.ID) as ChainRule
		var memory: int = session.rules.memory_of(session.state)
		for index: int in chain.groups.size():
			if chain.is_broken(memory, index):
				continue
			var group: Array = chain.groups[index]
			var free: bool = false
			for peg_index: int in session.state.get_peg_count():
				if session.state.get_top_disk(peg_index) == group[0]:
					free = session.rules.can_pick_up(session.state, peg_index)
			chains.append([group, free])
		marks["chains"] = chains
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
	# World 3-4: the rings' crowned leader, broken ring and hourglass, the reset
	# peg; the coloured bases and the paint peg; the dial's back step and
	# shortcut.
	if _has(level, AlternationRule.ID):
		var rings: AlternationRule = _rule(level, AlternationRule.ID) as AlternationRule
		var icons: Dictionary = {}
		if rings.leader != 1:
			icons[rings.leader] = "crown"
		if rings.free > 0:
			icons[rings.free] = "broken"
		if rings.waiting > 0:
			icons[rings.waiting] = "hourglass"
		if not icons.is_empty():
			marks["disk_icons"] = icons
		if rings.reset >= 0:
			marks["reset"] = rings.reset
	if _has(level, StripesRule.ID):
		var stripes: StripesRule = _rule(level, StripesRule.ID) as StripesRule
		var bases: Dictionary = {}
		for peg: int in stripes.bases.size():
			if stripes.bases[peg] != StripesRule.NONE:
				bases[peg] = "odd" if stripes.bases[peg] == StripesRule.ODD else "even"
		if not bases.is_empty():
			marks["bases"] = bases
		if stripes.paint >= 0:
			marks["paint"] = stripes.paint
	if _has(level, CyclicRule.ID):
		var dial: CyclicRule = _rule(level, CyclicRule.ID) as CyclicRule
		var peg_count: int = level.get_peg_count()
		if dial.back >= 0:
			marks["back"] = [dial.back, dial.previous_of(dial.back, peg_count)]
		if dial.skip >= 0:
			marks["skip"] = [dial.skip, dial.next_of(dial.next_of(dial.skip, peg_count), peg_count)]
	# World 5: crowns on the crowned disks, a flagged gate over each gate, the
	# narrow gate's arrow, the odd and even pegs; an elephant on each elephant;
	# the caravanserai's roof.
	if _has(level, KingRule.ID):
		var king: KingRule = _rule(level, KingRule.ID) as KingRule
		var icons: Dictionary = marks.get("disk_icons", {})
		var gates: Array = []
		for crown: Array in king.crowns:
			icons[crown[0]] = "crown"
			gates.append(crown[1])
		if not icons.is_empty():
			marks["disk_icons"] = icons
		if not gates.is_empty():
			marks["gates"] = gates
		if not king.narrow.is_empty():
			marks["narrow"] = king.narrow
		if not king.odd_even.is_empty():
			marks["odd_even"] = king.odd_even
	if _has(level, RiverRule.ID):
		var river: RiverRule = _rule(level, RiverRule.ID) as RiverRule
		var icons: Dictionary = marks.get("disk_icons", {})
		for disk: int in range(river.elephant, level.get_disk_count() + 1):
			icons[disk] = "elephant"
		marks["disk_icons"] = icons
	if _has(level, Difficulty.COLOR_SWAP):
		var inn: int = (_rule(level, ColorSwapRule.ID) as ColorSwapRule).caravanserai
		if inn >= 0:
			marks["inn"] = inn
	# World 6: Go stones on the breathing pegs and the free peg's ring; the
	# carpet's navel and its marked top colours.
	if _has(level, KoRule.ID):
		var ko: KoRule = _rule(level, KoRule.ID) as KoRule
		marks["ko"] = ko.breathing(session.rules.memory_of(session.state), level.get_peg_count())
		if ko.free >= 0:
			marks["ko_free"] = ko.free
	if _has(level, CarpetRule.ID):
		var carpet: CarpetRule = _rule(level, CarpetRule.ID) as CarpetRule
		if not carpet.navel.is_empty():
			var icons: Dictionary = marks.get("disk_icons", {})
			icons[carpet.navel[1]] = "navel"
			marks["disk_icons"] = icons
			marks["navel_peg"] = carpet.navel[0]
		var tops: Dictionary = {}
		for peg: int in carpet.tops.size():
			if carpet.tops[peg] >= 0:
				tops[peg] = carpet.tops[peg]
		if not tops.is_empty():
			marks["top_colours"] = tops
	# World 7: each heavy disk's reach in dots (∞ for any), a tired disk; each
	# disk's element glyph, the bases' and the turning peg's elements; the
	# clean peg and every trail disk.
	if _has(level, HeavyRule.ID):
		var heavy: HeavyRule = _rule(level, HeavyRule.ID) as HeavyRule
		var reach: Dictionary = {}
		for disk: int in range(1, level.get_disk_count() + 1):
			reach[disk] = heavy.reach_of(disk)
		marks["reach"] = reach
		var last: int = session.state.last_moved_disk
		if heavy.fatigue and last > 0 and heavy.reach_of(last) == 1:
			marks["tired"] = last
	if _has(level, ElementsRule.ID):
		var wuxing: ElementsRule = _rule(level, ElementsRule.ID) as ElementsRule
		var memory: int = session.rules.memory_of(session.state)
		var glyphs: Dictionary = {}
		for disk: int in range(1, level.get_disk_count() + 1):
			glyphs[disk] = wuxing.element_of(disk, memory)
		marks["elements"] = glyphs
		var bases: Dictionary = {}
		for peg: int in wuxing.bases.size():
			if wuxing.bases[peg] >= 0:
				bases[peg] = wuxing.bases[peg]
		if not bases.is_empty():
			marks["element_bases"] = bases
		if wuxing.turning >= 0:
			marks["turning"] = wuxing.turning
	if _has(level, TrailRule.ID):
		var trail: TrailRule = _rule(level, TrailRule.ID) as TrailRule
		marks["trail_disks"] = trail.disks
		if trail.clean >= 0:
			marks["clean_peg"] = trail.clean
	# World 8-9: whose turn it is; the cracks and the workshops; the dark and
	# the lamps; the patience cell and the kings' spot.
	var facts: MoveFacts = MoveFacts.of(session.state, session.rules)
	if _has(level, TurnsRule.ID):
		marks["turn"] = (_rule(level, TurnsRule.ID) as TurnsRule).turn_of(facts)
	if _has(level, KintsugiRule.ID):
		var kintsugi: KintsugiRule = _rule(level, KintsugiRule.ID) as KintsugiRule
		var cracks: Dictionary = {}
		for disk: int in kintsugi.cracked:
			cracks[disk] = kintsugi.is_mended(facts.memory, disk)
		marks["cracks"] = cracks
		marks["deep"] = kintsugi.deep
		var workshops: Dictionary = {}
		for peg: int in kintsugi.workshops:
			workshops[peg] = kintsugi.is_closed(facts.memory, peg)
		marks["workshops"] = workshops
	if _has(level, LampRule.ID):
		var lamp: LampRule = _rule(level, LampRule.ID) as LampRule
		var dark: Array = []
		for peg: int in level.get_peg_count():
			if not lamp.is_lit(peg, facts):
				dark.append(peg)
		marks["dark"] = dark
		marks["lamps"] = lamp.lamps(facts)
		if lamp.fixed >= 0:
			marks["lantern"] = lamp.fixed
	if _has(level, SolitaireRule.ID):
		var solitaire: SolitaireRule = _rule(level, SolitaireRule.ID) as SolitaireRule
		if solitaire.cell >= 0:
			marks["cell"] = solitaire.cell
		if solitaire.kings > 0:
			marks["kings"] = solitaire.kings
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
