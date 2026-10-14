class_name BoardDress
extends RefCounted
## How a level's mechanic looks on the board and in the goal preview: the peg
## layout, the disks' colours and numbers, how much a peg can hold and the
## words that explain the goal. Presentation only: rules never read it, and
## the board and preview never name a mechanic themselves.


## BoardLayout kind of `level`'s pegs.
static func layout_kind(level: Level) -> String:
	var mechanic: String = level.mechanic()
	if mechanic == Difficulty.COLOR_SWAP:
		return BoardLayout.ROW  # one row even with 6 pegs: its two ends are the point
	return BoardLayout.ROWS if level.get_peg_count() > BoardLayout.ONE_ROW_PEGS else BoardLayout.ROW


## Disk id -> its looks where the id alone does not give them: {fill, text,
## outline} and optionally `label` (the number it shows), `size` and `sizes`
## (its width among that many sizes). Empty for levels whose disks keep one
## colour each and show their id.
## - Great exchange (ColorSwapRule): ids 2s - 1 and 2s are the white and black
##   disk of size s.
static func disk_palette(level: Level) -> Dictionary:
	var palette: Dictionary = {}
	if level.mechanic() == Difficulty.COLOR_SWAP:
		var sizes: int = level.get_disk_count() / 2
		for disk: int in range(1, level.get_disk_count() + 1):
			var colors: Dictionary = ThemeManager.EXCHANGE_DISKS["white" if ColorSwapRule.is_white(disk) else "black"].duplicate()
			colors["label"] = ColorSwapRule.size_of(disk)
			colors["size"] = ColorSwapRule.size_of(disk)
			colors["sizes"] = sizes
			palette[disk] = colors
	return palette


## The most disks one peg can ever hold (the rods are drawn for it): a great
## exchange's k (one disk of each size), else every disk.
static func stack_room(level: Level) -> int:
	if level.mechanic() == Difficulty.COLOR_SWAP:
		return maxi(level.get_disk_count() / 2, 1)
	return maxi(level.get_disk_count(), 1)


## Per peg, how many disks its rod is drawn for; empty when every rod is
## stack_room() tall.
static func rod_rooms(_level: Level) -> Array[int]:
	return [] as Array[int]


## Whether a refused move says why in the status line (not just a flash).
static func says_why(level: Level) -> bool:
	return level.mechanic() == Difficulty.COLOR_SWAP


## Translation key of the words that explain the goal before the first move,
## or "" when the preview says it all.
static func goal_words(level: Level) -> String:
	if level.mechanic() == Difficulty.COLOR_SWAP:
		return "COLOR_SWAP_MIXED_GOAL" if level.lesson() == Level.COLOR_SWAP_MIXED else "COLOR_SWAP_GOAL"
	return ""
