class_name BalanceScale
extends Control
## The balance scale of Tərəzi levels (Fəsil Sistemi v1.2, section 5): under
## every pair of pegs a Roberval scale. Its pans stay level and move straight
## up and down, the heavier side lower, so the pegs and disks on them only
## rise and sink (PegView.lift / DiskView.lift). A needle on the post swings
## with the beam, and an LCD under it shows "FƏRQ x · HƏDD T", green below the
## limit, yellow at it, flashing red when a move was refused. The pans settle
## on a damped spring (~0.4 s); a refused move shakes the beam with a short
## "tık", a solved level rings a soft bell. While a disk is picked up, every
## peg it could go to shows the new difference of its pair ("→ 6") or a red
## "✕" when the move would break the limit, so the player plans instead of
## adding up. Presentation only: the board feeds it, the rules decide; its
## colours come from ThemeManager (MARK_COLORS), so a new theme restyles it.

## Pixels a pan moves per unit of difference, and at most.
const PIXELS_PER_UNIT: float = 2.5
const MAX_DROP: float = 16.0
## The spring: angular frequency and damping (a small overshoot, settled in ~0.4 s).
const SPRING_OMEGA: float = 15.0
const SPRING_DAMPING: float = 0.35
## How far the needle turns at the largest drop (radians).
const NEEDLE_TURN: float = 0.6
const SHAKE_SECONDS: float = 0.3
const FLASH_SECONDS: float = 0.6
const ROLL_SECONDS: float = 0.15
## Room under the pegs: the beam, the post and the LCD.
const ROOM: float = 78.0
const LCD_HEIGHT: float = 30.0
const DIGIT_HEIGHT: float = 18.0
const LABEL_SIZE: int = 14
const PREVIEW_SIZE: int = 22

## The limit of the level (BalanceRule.tolerance).
var tolerance: int = 1
## Per pair: [left sum - right sum].
var differences: Array[int] = []
## Each peg's cell on the board, and the y (inside a cell) where its base ends
## and where its rod begins.
var cells: Array[Rect2] = []
var base_bottom: float = 0.0
var rod_tops: Array[float] = []
## The views the pans carry (set by the board).
var peg_views: Array[PegView] = []
var disk_views: Dictionary[int, DiskView] = {}
## Which disks stand on which peg now.
var pegs: Array = []
## While a disk is picked up: peg -> new difference of its pair, or -1 for "✕".
var preview: Dictionary = {}
var sound_on: bool = true

var _drop: Array[float] = []
var _speed: Array[float] = []
var _shake: Array[float] = []
var _flash: Array[float] = []
var _roll: Array[float] = []
var _shown: Array[int] = []
var _rolled_from: Array[int] = []
var _player: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player = AudioStreamPlayer.new()
	add_child(_player)


## The position after a move (or at the start): new differences to settle on.
## `settle_now` places the pans without a swing (a level just started).
func show_position(state: PuzzleState, p_tolerance: int, settle_now: bool = false) -> void:
	tolerance = maxi(p_tolerance, 1)
	pegs = state.pegs.duplicate(true)
	var pair_count: int = state.get_peg_count() / 2
	if differences.size() != pair_count:
		for list: Array in [_drop, _speed, _shake, _flash, _roll]:
			list.resize(pair_count)
			list.fill(0.0)
		_shown.resize(pair_count)
		_rolled_from.resize(pair_count)
		settle_now = true
	differences.clear()
	for pair: int in pair_count:
		differences.append(BalanceRule.sum_of(state.pegs[pair * 2]) - BalanceRule.sum_of(state.pegs[pair * 2 + 1]))
	for pair: int in pair_count:
		var shown: int = absi(differences[pair])
		if settle_now:
			_drop[pair] = _target(pair)
			_speed[pair] = 0.0
			_shown[pair] = shown
		elif shown != _shown[pair]:
			_rolled_from[pair] = _shown[pair]
			_shown[pair] = shown
			_roll[pair] = ROLL_SECONDS
	_apply_lifts()
	queue_redraw()


## While `disk` is picked up from `from_peg`: the new difference each target
## peg would give its pair, or "✕" where the limit breaks. Cleared with -1.
func show_preview(from_peg: int, disk: int) -> void:
	preview.clear()
	if from_peg >= 0 and disk > 0:
		for to_peg: int in pegs.size():
			var top: int = int(pegs[to_peg][-1]) if not (pegs[to_peg] as Array).is_empty() else -1
			if to_peg == from_peg or (top != -1 and top < disk):
				continue  # not a place the disk can go anyway
			var after: Array[int] = differences.duplicate()
			after[from_peg / 2] += -disk if from_peg % 2 == 0 else disk
			after[to_peg / 2] += disk if to_peg % 2 == 0 else -disk
			var broken: bool = absi(after[from_peg / 2]) > tolerance or absi(after[to_peg / 2]) > tolerance
			preview[to_peg] = -1 if broken else absi(after[to_peg / 2])
	queue_redraw()


## A refused move onto `peg`: its scale shakes, its LCD flashes red twice and
## a short "tık" sounds.
func refuse(peg: int) -> void:
	var pair: int = peg / 2
	if pair >= _shake.size():
		return
	_shake[pair] = SHAKE_SECONDS
	_flash[pair] = FLASH_SECONDS
	_play(SoundFx.tick())


## The level is solved: the scales come to rest and a soft bell rings.
func ring() -> void:
	for pair: int in _speed.size():
		_speed[pair] = 0.0
		_drop[pair] = _target(pair)
	_apply_lifts()
	_play(SoundFx.bell())


## Where a pair's left pan settles (down is positive): the heavier side lower.
func _target(pair: int) -> float:
	return clampf(differences[pair] * PIXELS_PER_UNIT, -MAX_DROP, MAX_DROP)


## How far pan `peg` is down right now.
func pan_drop(peg: int) -> float:
	var pair: int = peg / 2
	if pair >= _drop.size():
		return 0.0
	var shake: float = sin(_shake[pair] * 60.0) * 3.0 * (_shake[pair] / SHAKE_SECONDS)
	var drop: float = _drop[pair] + shake
	return drop if peg % 2 == 0 else -drop


func _process(delta: float) -> void:
	var moving: bool = false
	for pair: int in _drop.size():
		# A damped spring toward the pair's settling point.
		var pull: float = -SPRING_OMEGA * SPRING_OMEGA * (_drop[pair] - _target(pair)) - 2.0 * SPRING_DAMPING * SPRING_OMEGA * _speed[pair]
		_speed[pair] += pull * delta
		_drop[pair] += _speed[pair] * delta
		if absf(_drop[pair] - _target(pair)) < 0.05 and absf(_speed[pair]) < 0.05:
			_drop[pair] = _target(pair)
			_speed[pair] = 0.0
		else:
			moving = true
		for list: Array in [_shake, _flash, _roll]:
			if list[pair] > 0.0:
				list[pair] = maxf(list[pair] - delta, 0.0)
				moving = true
	if moving:
		_apply_lifts()
		queue_redraw()


## The pegs and the disks on them ride their pans.
func _apply_lifts() -> void:
	for peg: int in mini(peg_views.size(), pegs.size()):
		var drop: float = pan_drop(peg)
		peg_views[peg].lift = drop
		for disk: int in pegs[peg]:
			if disk_views.has(disk):
				disk_views[disk].lift = drop


func _play(stream: AudioStreamWAV) -> void:
	if sound_on and _player != null:
		_player.stream = stream
		_player.play()


func _draw() -> void:
	for pair: int in differences.size():
		if pair * 2 + 1 < cells.size():
			_draw_scale(pair)
	for peg: int in preview:
		if peg < cells.size():
			_draw_preview(peg, preview[peg])


## One Roberval scale: foot and post, the beam on its pivot with a strut up to
## each level pan, the needle on a small dial, and the LCD under it.
func _draw_scale(pair: int) -> void:
	var metal: Color = ThemeManager.mark_color("scale_metal")
	var brass: Color = ThemeManager.mark_color("scale_brass")
	var left: Rect2 = cells[pair * 2]
	var right: Rect2 = cells[pair * 2 + 1]
	var rest: float = left.position.y + base_bottom
	var mid_x: float = (left.get_center().x + right.get_center().x) * 0.5
	var pivot: Vector2 = Vector2(mid_x, rest + 18.0)
	var left_drop: float = pan_drop(pair * 2)
	var right_drop: float = pan_drop(pair * 2 + 1)
	var lx: float = left.get_center().x
	var rx: float = right.get_center().x
	# Pans: level platforms under each peg's base.
	for side: Array in [[lx, left_drop, left.size.x], [rx, right_drop, right.size.x]]:
		var pan: Rect2 = Rect2(side[0] - side[2] * 0.45, rest + side[1] - 2.0, side[2] * 0.9, 7.0)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = brass
		style.set_corner_radius_all(3)
		draw_style_box(style, pan)
		draw_line(Vector2(side[0], rest + side[1] + 5.0), Vector2(side[0], pivot.y + side[1] * 0.5), metal, 4.0, true)
	# The beam through the pivot, tipped with the pans.
	draw_line(Vector2(lx, pivot.y + left_drop * 0.5), Vector2(rx, pivot.y + right_drop * 0.5), metal, 6.0, true)
	# Post and foot.
	var foot_y: float = rest + ROOM - LCD_HEIGHT - 10.0
	draw_line(pivot, Vector2(mid_x, foot_y), metal, 7.0, true)
	draw_line(Vector2(mid_x - 26.0, foot_y), Vector2(mid_x + 26.0, foot_y), metal, 6.0, true)
	# Dial and needle: it points up when level and swings to the heavier side.
	draw_arc(pivot, 16.0, PI * 1.15, PI * 1.85, 16, brass, 2.0, true)
	var angle: float = -PI * 0.5 + clampf(left_drop / MAX_DROP, -1.0, 1.0) * -NEEDLE_TURN
	draw_line(pivot, pivot + Vector2(cos(angle), sin(angle)) * 20.0, ThemeManager.mark_color("scale_needle"), 3.0, true)
	draw_circle(pivot, 4.0, brass, true, -1.0, true)
	_draw_lcd(pair, Rect2(mid_x - 90.0, foot_y + 6.0, 180.0, LCD_HEIGHT))


## "FƏRQ x · HƏDD T" in seven-segment digits on a dark screen.
func _draw_lcd(pair: int, screen: Rect2) -> void:
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = ThemeManager.mark_color("lcd_back")
	back.set_corner_radius_all(6)
	draw_style_box(back, screen)
	var difference: int = absi(differences[pair])
	var ink: Color = ThemeManager.mark_color("lcd_green" if difference < tolerance else "lcd_yellow")
	if _flash[pair] > 0.0 and int(_flash[pair] / (FLASH_SECONDS / 4.0)) % 2 == 1:
		ink = ThemeManager.mark_color("lcd_red")
	var font: Font = get_theme_default_font()
	var baseline: float = screen.get_center().y + font.get_ascent(LABEL_SIZE) * 0.35
	var x: float = screen.position.x + 10.0
	draw_string(font, Vector2(x, baseline), Languages.text("SCALE_DIFFERENCE"), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, ink)
	x += font.get_string_size(Languages.text("SCALE_DIFFERENCE"), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + 6.0
	var top: float = screen.get_center().y - DIGIT_HEIGHT * 0.5
	# The difference rolls in when it changes.
	var roll: float = _roll[pair] / ROLL_SECONDS
	if roll > 0.0:
		var old_ink: Color = ink
		old_ink.a = roll
		var new_ink: Color = ink
		new_ink.a = 1.0 - roll
		_draw_number(_rolled_from[pair], Vector2(x, top - DIGIT_HEIGHT * (1.0 - roll)), old_ink)
		x = _draw_number(difference, Vector2(x, top + DIGIT_HEIGHT * roll), new_ink)
	else:
		x = _draw_number(difference, Vector2(x, top), ink)
	x += 8.0
	draw_circle(Vector2(x, screen.get_center().y), 2.0, ink, true, -1.0, true)
	x += 8.0
	draw_string(font, Vector2(x, baseline), Languages.text("SCALE_LIMIT"), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, ink)
	x += font.get_string_size(Languages.text("SCALE_LIMIT"), HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x + 6.0
	_draw_number(tolerance, Vector2(x, top), ink)


## A number in seven-segment digits from `at` (top left); returns the x after it.
func _draw_number(value: int, at: Vector2, ink: Color) -> float:
	var x: float = at.x
	for digit: String in str(value):
		_draw_digit(int(digit), Vector2(x, at.y), ink)
		x += DIGIT_HEIGHT * 0.62
	return x


func _number_width(value: int) -> float:
	return str(value).length() * DIGIT_HEIGHT * 0.62


## Segments a-g of each digit (a top, b top right, c bottom right, d bottom,
## e bottom left, f top left, g middle).
const SEGMENTS: Array[String] = ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"]


func _draw_digit(digit: int, at: Vector2, ink: Color) -> void:
	var w: float = DIGIT_HEIGHT * 0.45
	var h: float = DIGIT_HEIGHT * 0.5
	var lines: Dictionary = {
		"a": [Vector2(0, 0), Vector2(w, 0)], "b": [Vector2(w, 0), Vector2(w, h)], "c": [Vector2(w, h), Vector2(w, h * 2.0)],
		"d": [Vector2(0, h * 2.0), Vector2(w, h * 2.0)], "e": [Vector2(0, h), Vector2(0, h * 2.0)],
		"f": [Vector2(0, 0), Vector2(0, h)], "g": [Vector2(0, h), Vector2(w, h)]}
	for segment: String in SEGMENTS[digit]:
		draw_line(at + lines[segment][0], at + lines[segment][1], ink, 2.5, true)


## Above a target peg: the new difference in grey, or a red "✕".
func _draw_preview(peg: int, value: int) -> void:
	var cell: Rect2 = cells[peg]
	var top: float = cell.position.y + (rod_tops[peg] if peg < rod_tops.size() else 0.0) - 18.0 + pan_drop(peg)
	var center: Vector2 = Vector2(cell.get_center().x, top)
	if value < 0:
		var red: Color = ThemeManager.color("danger")
		draw_line(center + Vector2(-9, -9), center + Vector2(9, 9), red, 4.0, true)
		draw_line(center + Vector2(-9, 9), center + Vector2(9, -9), red, 4.0, true)
		return
	var font: Font = get_theme_default_font()
	var text: String = "→ %d" % value
	var size_of: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, PREVIEW_SIZE)
	draw_string(font, center + Vector2(-size_of.x * 0.5, font.get_ascent(PREVIEW_SIZE) * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, PREVIEW_SIZE, ThemeManager.color("text_secondary"))
